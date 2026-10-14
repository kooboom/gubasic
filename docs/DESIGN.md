# GuBASIC Design

[한국어](DESIGN.ko.md)

This document records the architecture of GuBASIC and every decision made so far, **with the reason for each one**. When a decision changes, change it here first.

---

## 1. Goals

In priority order:

1. **Event-driven programming.** Code lives in event handlers attached to controls.
2. **Drawing the UI.** Interfaces are drawn on a canvas, not written as code.
3. **A BASIC language.** Simplified, VB.NET-flavored BASIC.
4. **Develop on macOS first, Windows second.**
5. **Release to macOS, Windows, iOS and Android** (web as a bonus).

### Audience

GuBASIC is built first for its author's own enjoyment, **but it must stay usable by beginners**. When a choice trades power for simplicity, simplicity wins unless there is a strong reason.

---

## 2. Architecture

### 2.1 Two layers of language

| Layer | Language | Why |
|---|---|---|
| The IDE itself | **Dart / Flutter** | One codebase gives macOS and Windows desktop apps; the output apps are Flutter too, so the whole project lives in one ecosystem. |
| What users write | **GuBASIC** (BASIC) | This is the identity of the project. A visual Flutter builder where you write Dart already exists in many forms; a Visual Basic–style tool on top of Flutter does not. |

C was considered for the IDE and rejected: building a GUI in C costs far more effort than it returns.

### 2.2 Two ways to run the same code

```
source (.gbas) + forms (.form.yaml)
            │
     lexer → parser → AST → analyzer
            │
     ┌──────┴───────┐
 Interpreter     Transpiler
 (F5, in IDE)    (Build, → Dart → Flutter → native app)
```

- **Interpreter** — runs the program inside the IDE instantly. This keeps the classic "press F5 and it runs" feel and means beginners never need Flutter installed to make and run apps.
- **Transpiler** — converts BASIC to Dart, generates a Flutter project and calls `flutter build`. The released app is AOT-compiled native code, so it runs as fast as a hand-written Flutter app.

Both share the same lexer, parser, AST and analyzer. The original Visual Basic used the same split (interpreted in the IDE, compiled for release).

**Biggest risk:** the two modes behaving differently. See §9 (parity tests).

### 2.3 Runtime layer

Generated code and the interpreter never call Flutter widgets directly. They use a thin package, **`gubasic_runtime`**, which provides `GbButton`, `GbLabel`, `GbForm`, `MsgBox`, etc.

Why:
- When Flutter changes, only `gubasic_runtime` needs updating.
- The interpreter and the generated app render through **the same runtime**, which makes their behavior match by construction.
- It plays the role the VB runtime DLL used to play.

Each GuBASIC release is pinned to a Flutter version it has been verified against. Upgrading Flutter is a deliberate step, not something forced on every update. The runtime uses only basic, stable Flutter widgets.

### 2.4 Repository layout (planned)

```
gubasic/
├── apps/
│   ├── ide/                 Flutter desktop IDE (macOS, Windows)
│   └── player/              GuBASIC Player for phones (stage 3)
├── packages/
│   ├── gubasic_lang/        Pure Dart: lexer, parser, AST, analyzer,
│   │                        interpreter, transpiler. No Flutter dependency.
│   └── gubasic_runtime/     Runtime controls and functions (Flutter)
├── components/              One folder per component (component.yaml + adapter)
├── examples/                Sample GuBASIC projects
├── test/parity/             Interpreter-vs-transpiler parity tests
└── docs/
```

`gubasic_lang` has no Flutter dependency so it can be tested quickly with plain `dart test`.

---

## 3. Execution model

### 3.1 Hidden asynchrony

In classic VB, `MsgBox` stops the code until the user clicks OK. In Flutter, dialogs, files and network calls are asynchronous (`await`). GuBASIC **hides this**:

- **Every user-defined `Sub` and `Function` is compiled as `async`, and every call to one is `await`ed.** This avoids having to track which procedures "become" asynchronous. The cost is a small overhead that is not noticeable at this scale.
- Built-in calls that must wait (`MsgBox`, `InputBox`, file, database, HTTP) are awaited automatically.
- Users write straight top-to-bottom code, exactly as in VB.

Consequences and how they are handled:

| Problem | Handling |
|---|---|
| A user clicks the same button again while its handler is still waiting (double execution) | **The same event handler cannot re-enter while it is running.** A second click is ignored. Other events still run. |
| A long `Do While` loop freezes the UI (Flutter's UI runs on one thread) | **`DoEvents`** is provided, exactly as in VB. It compiles to a short yield (`await Future.delayed(Duration.zero)`). |
| The interpreter must be able to pause in the middle of a statement | **The interpreter is async from day one.** This is the hardest thing to change later, so it is fixed now. |

### 3.2 Startup

- Project setting **Startup object**: a form (default) or `Sub Main`.
- Most apps use a startup form and initialise in `Form_Load`.
- `Sub Main` is for choosing the first form conditionally (e.g. show a login form only if not signed in).
- The transpiler generates Dart's `main()` from this setting.

### 3.3 Forms and navigation

`Form2.Show` keeps VB syntax but adapts to the platform:

| Platform | `Form2.Show` |
|---|---|
| macOS / Windows | Opens a new window |
| iOS / Android / Web | Navigates to a new screen |

---

## 4. Events

- **Name-based binding (VB6 style):** a handler named `btnSave_Click` handles the `Click` event of `btnSave`. Double-clicking a control creates the stub.
- **Renaming is safe:** when a control is renamed in the designer, the IDE renames all of its handlers. (This fixes VB6's well-known orphaned-handler problem.)
- **`Handles` clause (stage 2, optional):** for sharing one handler among several controls.

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

- **No control arrays.** `Handles` and runtime-created controls cover their use cases.

---

## 5. Components

Every control — including the built-in Button, Label and TextBox — is a **component** described by a `component.yaml`:

```yaml
name: QRScanner
version: 1
package: "mobile_scanner: ^5.0.0"   # omitted for built-ins
visual: true
properties:
  - { name: Enabled, type: Boolean, default: true }
  - { name: Torch,   type: Boolean, default: false }
events:
  - Detected(code As String)
methods:
  - Start()
  - Stop()
permissions:
  android: [CAMERA]
  ios: { NSCameraUsageDescription: "Scan QR codes" }
```

Why build the basic controls this way from the start: extending GuBASIC later becomes "add one more component", not a redesign. The cost in stage 1 is close to zero.

The same metadata powers the toolbox, the Properties window, autocompletion and the transpiler.

### 5.1 Built-in vs extra components

| | Interpreter (F5) | Build |
|---|---|---|
| **Built-in components** (compiled into the IDE and Player) | ✅ runs | ✅ |
| **Extra components** (any pub.dev package wrapped by an adapter) | Shown as a placeholder box in the designer; not executed | ✅ added to the generated `pubspec.yaml` |

Reason: Dart cannot load new packages at run time, and Flutter disables reflection. This is the same limitation as Expo Go or the App Inventor Companion.

### 5.2 Escape hatch

Advanced users may embed Dart directly for packages that have no adapter yet (syntax to be fixed in stage 3). Such code runs only in Build mode.

### 5.3 Future

Generate adapters automatically by reading a package's public API with the Dart `analyzer` package.

---

## 6. Layout

**Principle: later stages only add properties. They never change the meaning of existing ones.** Projects from earlier stages therefore open and behave identically without conversion.

| Stage | Adds | Flutter mapping |
|---|---|---|
| 1 | Absolute position + `Anchor` (Left/Top/Right/Bottom) and form size presets (Phone / Tablet / Desktop) | `Stack` + `Positioned` |
| 2 | Container `LayoutMode` (Absolute / Vertical / Horizontal / Grid) and `Dock` | `Column`, `Row`, `Wrap`, grid |
| 3 | Per-size overrides (Phone / Tablet / Desktop values for any property) | `LayoutBuilder` |

Defaults guarantee compatibility: `LayoutMode = Absolute`, no per-size overrides.

Every project file carries a `formatVersion`. If a breaking change is ever needed, a migrator upgrades old files automatically.

A later helper may convert an absolute layout to a vertical one by reading controls' top-to-bottom order.

---

## 7. Project files

All project files are **plain text**, so that Git diffs are readable (like VB6's `.frm`). Extensions are provisional.

| File | Format | Contents |
|---|---|---|
| `App.gbproj` | YAML | Project settings: name, startup object, Flutter version, components used |
| `Form1.form.yaml` | YAML | Controls and their properties |
| `Form1.gbas` | GuBASIC | Code behind `Form1` |
| `Module1.gbas` | GuBASIC | Module code (globals, shared procedures) |

---

## 8. Editor

### 8.1 Autocompletion in stage 1

Because component metadata is declared up front, light autocompletion is cheap and ships in stage 1:

- Keywords, with block completion (`If` → `End If`)
- Control names on the current form
- Members after a dot (`Label1.` → properties, methods, events)
- **"Did you mean" hints for VB-isms and near-misses**, e.g. using a property that exists in VB but has a different name in GuBASIC

Later: type inference for local variables and function results.

### 8.2 Error-tolerant parser

Code being typed is almost always syntactically broken. **The parser must recover from errors and keep going** so that highlighting, autocompletion and diagnostics keep working. This is a stage-1 requirement, not an optimisation.

### 8.3 Runtime errors

An unhandled error stops the program, highlights the line in the editor and explains the error in plain language (English or Korean). Beginners do not need `Try` to get a useful error.

### 8.4 Messages

IDE messages and error explanations are available in **English and Korean**.

---

## 9. Testing

- `gubasic_lang` is tested with plain `dart test`.
- **Parity tests (mandatory from the start):** each sample program in `test/parity/` is run once through the interpreter and once through the transpiled Dart; recorded output must be identical. A change that breaks parity does not merge.

---

## 10. Data

| Feature | Stage | Notes |
|---|---|---|
| `Settings` (key-value; VB's `SaveSetting` / `GetSetting`) | 1 | `shared_preferences` |
| `Database` component (SQLite) | 2 | `sqlite3` package: macOS, Windows, iOS, Android, and web via WebAssembly. Bundled in the IDE so it works in the interpreter. |
| Data binding (VB's Data control) | after 1.0 | Excluded from 1.0 |

```vb
Dim db = Database.Open("score.db")
db.Execute("INSERT INTO score(name, point) VALUES(?, ?)", txtName.Text, 90)
For Each row In db.Query("SELECT * FROM score")
    lstScores.AddItem(row("name"))
Next
```

---

## 11. External services

### 11.1 Services an app calls at run time

| Feature | Stage |
|---|---|
| `Http` (`Get`, `Post`) + JSON — reaches any REST API, including Supabase's | 2 |
| `Supabase` component (URL + public key) | 3 |
| `Firebase` component (needs per-platform config files, added at build time via `component.yaml`) | 3 |

**Security rule:** anything embedded in an app can be extracted. Only public keys (e.g. Supabase anon key) protected by server-side rules may be used. **The IDE warns when something that looks like a secret/service key is placed in a project.**

### 11.2 Where a web build is published

A **Publish** menu sends `build/web` to: Vercel, Firebase Hosting, GitHub Pages, or a personal server (SFTP/rsync). Implemented through each service's CLI or a GitHub Actions workflow.

---

## 12. Distribution and setup

| Step | What the user needs | For |
|---|---|---|
| Draw, code, run | GuBASIC only | Beginners |
| Test on a phone | **GuBASIC Player** app (like the App Inventor Companion) | Beginners |
| Release Android / Web / desktop | Flutter SDK, **downloaded automatically** on the first Build, or a **GitHub Actions** cloud build | Intermediate |
| Release iOS / macOS | A Mac, Xcode, an Apple Developer account | Intermediate+ |

The iOS/macOS requirement comes from Apple's policy, not from GuBASIC.

---

## 13. Naming

- Product name **GuBASIC** (repository `gubasic`). "BASIC" is the generic name of a language family dating from 1964.
- Neither "Flutter" nor "Visual Basic" appears in the product name, following both owners' trademark guidelines. Descriptive phrases ("Visual Basic–style", "built with Flutter") are used instead, together with a non-affiliation notice in the README.

---

## 14. Decision log

| # | Decision | Why |
|---|---|---|
| D1 | IDE written in Flutter | One codebase for macOS + Windows; same ecosystem as output |
| D2 | User language is BASIC | Project identity; nothing like it exists on Flutter |
| D3 | Interpreter + transpiler sharing one AST | Instant F5; native release builds |
| D4 | Hidden async; all user procedures async | VB-style straight-line code |
| D5 | Same handler cannot re-enter | Prevents the most confusing beginner bug |
| D6 | `DoEvents` kept | Familiar fix for long loops |
| D7 | Name-based events + auto-rename; optional `Handles` (stage 2) | VB6 simplicity without VB6's rename problem |
| D8 | `Try…Catch…Finally` only; no `On Error` | Visible scope; maps 1:1 to Dart; `GoTo` cannot be transpiled into async Dart cleanly |
| D9 | Startup form (default) or `Sub Main` | Same model as VB6 / VB.NET / Xojo |
| D10 | Everything is a component (`component.yaml`) | Extension becomes "add a component" |
| D11 | `gubasic_runtime` layer; pinned Flutter version | Contains Flutter churn in one place |
| D12 | Layout grows by adding properties only | Old projects never break |
| D13 | Plain-text project files | Readable Git diffs |
| D14 | Light autocompletion in stage 1; error-tolerant parser | Helps beginners and VB users meet GuBASIC's differences |
| D15 | Parity tests mandatory | Interpreter/transpiler divergence is the top risk |
| D16 | `Settings` stage 1, `Database` stage 2, data binding after 1.0 | Useful data access early, complex binding later |
| D17 | `Http` stage 2, Supabase/Firebase stage 3, Publish menu with web release | Generic channel first, specific integrations later |
| D18 | Language details (types, scope, arrays, operators) | See [LANGUAGE.md](LANGUAGE.md) |
| D19 | Name GuBASIC; no third-party marks in the name | Trademark guidelines of Google and Microsoft |
| D20 | Built for the author, usable by beginners | Simplicity wins ties |
