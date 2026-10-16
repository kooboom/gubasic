# GuBASIC Design

[한국어](DESIGN.ko.md)

This document records the architecture of GuBASIC and every decision made so far, **with the reason for each one**. When a decision changes, change it here first.

---

## 1. Goals

**GuBASIC is VB.NET's syntax with VB6's workflow on top — with the awkward parts of both taken out.**
When the two disagree, take VB.NET's cleaner rule wherever VB6 is confusing or risky, and VB6's convenience wherever it is what hands already know.

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

Each GuBASIC release is pinned to a Flutter version it has been verified against (D29). Upgrading Flutter is a deliberate step, not something forced on every update. The runtime uses only basic, stable Flutter widgets.

How it is built:
- **`GbFormModel`** holds the form and its controls' current properties (`GbControlState`, named and typed as in `component.yaml`). **`GbFormView`** shows them: each control at `Left`, `Top` in a `Stack` (§6). What the user does comes back as events: `Click`, and `Changed` when the user changes a TextBox's committed text.
- **`GbDialogs`** shows `MsgBox` and `InputBox`, modal (D28), and closes them all when a program ends.
- **`gubasic_runtime` does not depend on `gubasic_lang`.** The IDE connects the two (the interpreter's `FormHost`), so that generated apps never carry the interpreter.
- **The IDE's run window** (`apps/ide`): `RunHost` implements `FormHost` on a `GbFormModel` and `GbDialogs`. Properties live only in the model, which the program sets and the user changes; clicks and typing go to the interpreter as events. The run window fills the middle of the IDE and has its own navigator: a MsgBox or InputBox covers the form and its close button (D28), but not the IDE's toolbar, so Stop (Shift+F5) always works. The form appears when `Form_Load` has finished.
  - **Dialogs are program-modal.** A MsgBox or InputBox blocks the running program's form only. The IDE stays usable, above all its Stop button: if dialogs blocked the IDE too, a program waiting in one could not be stopped.
  - **Looking at a file during a run.** While a program runs, the file list starts with a "Run window" entry. Choosing a file shows the file; choosing the entry brings back the run window exactly as it was, an open dialog included, still waiting for its answer. The run window is never rebuilt while hidden, so a dialog cannot be lost.
  - **Stop with a dialog open** closes the dialog and ends the program, wherever the user is looking.
  - **Files are read-only while a program runs.** The program runs the code it started with; to change it, the user stops it first. The playground instead stops a program when its code is edited (I5 in `apps/playground/lib/src/dom/app.dart`); the IDE does not, because a stray keystroke in a file would end a program that may be waiting in a dialog, without the user asking. The code view is read-only in any case until the code editor arrives (ROADMAP); the editor keeps this rule.
  - Tests: `apps/ide/test/ide_shell_test.dart`.
- **Projects on disk** (D32): on macOS and Windows the IDE's File menu opens a project folder and saves into it (Open…, Save, Save As…). The built-in examples are read-only; Save on one asks for a folder and saves a copy. Unsaved changes are marked with • after the project's name, and the IDE asks before they would be lost: when another project is opened, or the IDE quits. Nothing is opened or saved while a program runs. Tests: `apps/ide/test/folders_test.dart`, `folders_io_test.dart`, `project_menu_test.dart`.
- **The runtime does not choose fonts.** The app around it does, through its theme, so that desktop and phone apps keep using the system's fonts. The IDE brings its own font, Noto Sans KR, and uses it on every platform (D30).
- `packages/gubasic_runtime/example` draws a form by hand; CI builds it for the web and Windows on every change, and for macOS on pull requests.

### 2.4 Repository layout (planned)

```
gubasic/
├── apps/
│   ├── ide/                 Flutter IDE (macOS, Windows, web)
│   ├── player/              GuBASIC Player for phones (stage 3)
│   └── playground/          Web playground for development (pure Dart, no Flutter)
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
| A user clicks the same button again while its handler is still waiting (double execution) | **The same event handler cannot re-enter while it is running.** A second click is ignored. |
| Two handlers would interleave at every `await` and see each other's half-done work | **One handler runs at a time** (D28). Another one starts when it finishes, or while it waits in `DoEvents`. `MsgBox` and `InputBox` are modal: events while they are open are blocked. |
| A long `Do While` loop freezes the UI (Flutter's UI runs on one thread) | **`DoEvents`** is provided, exactly as in VB. It compiles to a short yield (`await Future.delayed(Duration.zero)`) and lets other handlers run. |
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

The built-in components live in `components/` (`Form`, `Button`, `Label`, `TextBox`; see [LANGUAGE.md](LANGUAGE.md) §11.1). The analyzer needs their properties and events on every platform, the web included, where it cannot read files, so `tool/embed_components.dart` copies each `component.yaml` into `gubasic_lang`, and CI checks that the copy is up to date (D27).

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
| `App.gbproj` | YAML | Project settings: name, startup form, forms (later also the Flutter version and the components used) |
| `Form1.form.yaml` | YAML | The form's properties, its controls and their properties |
| `Form1.gbas` | GuBASIC | Code behind `Form1` |
| `Module1.gbas` | GuBASIC | Module code (globals, shared procedures) |

Every file carries a `formatVersion`. The layouts of form and project files are in [LANGUAGE.md](LANGUAGE.md) §11.2–§11.3; [examples/hello](../examples/hello) is a complete project.

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

- `gubasic_lang` is tested with plain `dart test`; `gubasic_runtime` with `flutter test`.
- **Typing with real input methods.** `packages/gubasic_runtime/tool/ime_probe` records what a real input method sends to a text field (every value, with the part still being composed). The recordings are kept in `packages/gubasic_runtime/test/ime_logs/`, and the TextBox tests replay them, so Korean typing is tested with real signals, not invented ones. Each replay is checked in two layers: the rules of LANGUAGE §11.1, the same for every input method, and the exact events that recording made, so a Flutter upgrade that changes what one input method does is noticed. How to record: [its README](../packages/gubasic_runtime/tool/ime_probe/README.md).
- **Parity tests (mandatory from the start):** each sample program in `test/parity/` is run once through the interpreter and once through the transpiled Dart; recorded output must be identical. A change that breaks parity does not merge.
- The same parity programs also run in Chrome (`apps/playground`), so the interpreter gives the same output on the VM and on the web.

### 9.1 Event scripts

A parity program with a form (`NAME.gbas` + `NAME.form.yaml`) is driven by an **event script**, `NAME.events`: one user action per line.

```
btnHello.Click        ' a click
txtName.Type "Kim"    ' the user changes a TextBox's text; Changed runs
OK                    ' closes the open MsgBox
Answer "Kim"          ' answers the open InputBox (Cancel gives "")
Close                 ' closes the form
```

A step runs only when the program waits for the user: no handler runs, the running ones wait in `DoEvents`, or a dialog is open. So the output is the same on every platform. `NAME.out` echoes each step as `> step`, then lists what the program showed (`Debug.Print`, `MsgBox`, `InputBox`), every property it set (`Set lblMessage.Caption: Hello`) and what happened to events (`Ignored: …`, `Blocked: …`). Its last line says how the run ended: `Closed`, `Ended`, `Stopped` or `Error R0xx @ line`. The runner is `package:gubasic_lang/testing.dart`, shared by the VM tests, the Chrome tests and the IDE's widget tests (`apps/ide/test/widget_parity_test.dart`). The widget tests do each step on the real run window: they tap the button, type into the TextBox, press the dialog's buttons and the window's close button. A step whose widget is covered by an open dialog, or not on the screen yet (during `Form_Load`), does not reach the program and is `Blocked`, as it would be for the user. So the controls of a parity form must not overlap.

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
| D21 | Web playground for development (`apps/playground`): pure Dart compiled to JavaScript, no Flutter; published to GitHub Pages from `main` | Shows each language stage (tokens, later AST and output) in a browser with no install; keeps `gubasic_lang` honest on the web platform. It is a development tool, not the IDE |
| D22 | A property passed `ByRef` is **not** written back when the procedure ends with an error | A failed operation must not leave a half-changed value behind. See [LANGUAGE.md](LANGUAGE.md) §7.2 |
| D23 | Diagnostics have a severity (error or warning). Warnings never stop a program from running or being built. The code prefix (L, P, …) names the reporter, not the severity | Some things work but deserve a look (a variable that is never used); users should hear about them without being blocked. See [LANGUAGE.md](LANGUAGE.md) §1.2 |
| D24 | Until `gubasic_runtime` and the form designer exist, the playground runs **the language only** (variables, expressions, conditions, loops, procedures, `Try`). Output goes through `Debug.Print` (VB6's Immediate window), `MsgBox` and `InputBox`. Controls and forms are **not** imitated in HTML; they arrive with `gubasic_runtime`, and moving the playground to Flutter web will be considered then | A second, HTML-based runtime would break D11 (one runtime for interpreter and generated apps) and would have to be thrown away later |
| D25 | The interpreter follows the analyzer's results exactly. Every call to a user procedure is awaited; expressions without such calls are evaluated synchronously. Each call starts in a fresh microtask and an error travels up one call per microtask, so recursion depth uses the heap, never the platform stack; R009 stops calls nested deeper than 10,000. A `Dim` runs again every time it is reached (LANGUAGE §3.2). Run-time errors can be caught with `Try` | Same names and conversions as the analyzer, and therefore as the transpiler later. Synchronous expressions: about 3 s instead of 9 s for a million loop rounds in an optimized web build, with the same results. Measured: without the per-call microtask an error raised about 1,000 calls deep overflowed the VM stack; with it, a million calls deep is safe on the VM and in Chrome, so 10,000 is a limit for endless recursion, not for safety |
| D26 | **`Integer` is an exact 64-bit integer on every platform** — the interpreter on the web included, and generated web apps later. The VM uses Dart's `int`; the web uses `Int64` from package:fixnum; both sit behind one API with the overflow checks (`checked_math.dart`). The same parity programs run on the VM and in Chrome | A program must compute the same numbers wherever it runs. Cost on the web: in a micro-benchmark, 5 million `Int64` additions took 97 ms against 3 ms for plain numbers in Chrome (about 30×). In the interpreter the difference does not show (a million loop rounds take the same time with `Integer` or `Double`), because interpreting dominates; integer-heavy code in generated web apps will pay it. Lexer warning L007 (integers the web could not store exactly) became unnecessary and was retired |
| D27 | Form files (`.form.yaml`) and project files (`.gbproj`) are YAML with `formatVersion: 1`, read by `gubasic_lang`. The built-in components' `component.yaml` files are copied into `gubasic_lang` by a generator. Problems in these files are F diagnostics, reported where they are, and the rest of the file is still read. Code is analyzed together with its form, so controls, `Me` and event handlers are checked before running | The analyzer must know the controls on every platform, the web included, and `gubasic_lang` must keep running with plain `dart test` (CLAUDE.md rule 1). Reading on after a problem, as the parser does (D14), keeps one mistake from hiding the others. A handler written differently from its event is an error (A032), not an ordinary procedure that silently never runs |
| D28 | **A program with a form runs one event handler at a time.** Another handler starts when the running one finishes or waits in `DoEvents`; events in between wait in order. The same handler is not restarted (D5). `MsgBox` and `InputBox` are modal: they keep the turn, and events while one is open are dropped. The automatic screen updates during long loops do not let other handlers run. When the program sets a property that has a change event (`TextBox.Text`), the handler runs right away as part of the assignment; only such assignments can wait, so all other property assignments keep D25's synchronous path | Handlers see each other's work only at places the code shows (`DoEvents`), so a run is deterministic and the same on every platform. Dialogs behave as on desktops and phones, and as Visual Basic .NET's `MsgBox`, which is application-modal by default ([Interaction.MsgBox](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.interaction.msgbox)). Measured on the VM: 1,000,000 assignments to `Label.Left` take 0.29 s, to `TextBox.Text` 0.66 s, and loops without properties are as fast as before |
| D29 | **One Flutter version for the whole repository, written in one place:** `environment: flutter: 3.47.7` in `packages/gubasic_runtime/pubspec.yaml`. CI installs exactly that version with `subosito/flutter-action` (`flutter-version-file`), for every job, the pure-Dart ones included (they use its Dart). On developer machines, `dart tool/check_flutter.dart` (in `packages/gubasic_runtime`) compares the installed Flutter with it | The Mac and the Windows PC must build and test with the same Flutter. pub checks that line only as a lower bound: "The Flutter SDK only enforces the lower bound of the flutter constraint" ([pubspec](https://dart.dev/tools/pub/pubspec)), so an exact check is needed. flutter-action reads the exact version from the pubspec ([flutter-action](https://github.com/subosito/flutter-action)). Upgrading Flutter means changing that line, then checking the IME recordings and the parity tests again |
| D30 | **The IDE brings its own font and engine.** It bundles Noto Sans KR 2.004 (Regular and Bold, OFL, `apps/ide/fonts/`) and uses it on every platform: web, macOS and Windows. The web build is made with `--no-web-resources-cdn`, so the engine (CanvasKit) and the fallback fonts come from the same server as the app, not from Google's CDN. The first visit shows "Loading…" ("불러오는 중…") until the first frame. **First-visit transfer size: about 10.6 MB** (17.9 MB uncompressed; of the compressed size, about 7.6 MB is the two font files, 2.1 MB CanvasKit, 0.8 MB the app's code). **This is a local gzip estimate** (`gzip -9` of the files Chrome fetched from a local server); **it is replaced with the value measured after the Pages deploy in E1e** | GuBASIC draws forms to the pixel. If the Korean font differs between platforms (macOS's and Windows' default fonts), the width of each letter differs, and a Label drawn to fit on one platform is cut off on the other. With the same font everywhere, the IDE keeps the designer's promise: a form looks the way it was drawn. Serving the engine and fonts ourselves also makes the web IDE work where Google's servers are blocked, and avoids missing Hangul syllables seen with fonts fetched from the CDN ([flutter/flutter#188255](https://github.com/flutter/flutter/issues/188255)). Cost: the desktop IDE grows by about 9 MB as well; for a development tool this is accepted. Apps built later do not get the font: see KNOWN_ISSUES |
| D31 | **The IDE writes form files in one layout** (`writeFormFile` in `gubasic_lang`): properties in `component.yaml` order, only values that differ from the defaults, quotes only where YAML would read the text differently, and `\uXXXX` escapes for invisible characters and line separators. Comments and the layout of a hand-written file are not kept | The same form always gives the same bytes, so saving creates no Git change and an edit shows as the lines it touched (D13). Keeping comments would need a YAML editor that keeps the original text; with the designer, hand-written form files are the exception. Writing in `gubasic_lang` keeps it testable with plain `dart test` against the reader (CLAUDE.md rule 1): the examples are written back byte for byte, and any text reads back as itself |
| D32 | **A project is a folder with one `.gbproj` file** and, for each form it lists, `FORM.form.yaml` and `FORM.gbas`; other files in the folder are left alone. The desktop IDE opens and saves such folders (`file_selector`, `dart:io`). **Save** writes only the files that changed, each to a temporary file that then replaces it, and asks first if a file was changed on disk by another program since it was opened. **Save As** makes a new folder `NAME` with `NAME.gbproj` (its `name:` set to `NAME`, written as D31 does) and never writes into a folder that is already there. **The built-in examples are read-only**: Save on one works as Save As. The web IDE does not open or save folders yet (E2b-2) | A folder per project is what the files already are (§7, D13), so a project can be copied, zipped or put in Git as it is. Replacing a file in one step means a crash or a full disk leaves the old file or the new one, never half of it; asking before overwriting keeps another program's changes from being lost silently. Keeping the examples unchanged means every student starts from the same project, and a copy makes clear where their own work is. `file_selector` is the Flutter team's package ([pub.dev](https://pub.dev/packages/file_selector)); on the web it can only open files, not choose a folder, so the web gets its own way to save |
