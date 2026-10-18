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
- **`GbFormModel`** holds the form and its controls' current properties (`GbControlState`, named and typed as in `component.yaml`). **`GbFormView`** shows them: each control at `Left`, `Top` in a `Stack` (§6). A Button keeps 8 pixels between its edges and its text, so that a Button of the default width shows its own name (`Button1`); Material's default, 24, left only 48 of its 96 pixels for text. What the user does comes back as events: `Click`, and `Changed` when the user changes a TextBox's committed text, a CheckBox, or the item chosen in a ListBox.
- **`GbDialogs`** shows `MsgBox` and `InputBox`, modal (D28), and closes them all when a program ends.
- **`gubasic_runtime` does not depend on `gubasic_lang`.** The IDE connects the two (the interpreter's `FormHost`), so that generated apps never carry the interpreter.
- **The IDE's run window** (`apps/ide`): `RunHost` implements `FormHost` on a `GbFormModel` and `GbDialogs`. Properties live only in the model, which the program sets and the user changes; clicks and typing go to the interpreter as events. The run window fills the middle of the IDE and has its own navigator: a MsgBox or InputBox covers the form and its close button (D28), but not the IDE's toolbar, so Stop (Shift+F5) always works. The form appears when `Form_Load` has finished.
  - **Dialogs are program-modal.** A MsgBox or InputBox blocks the running program's form only. The IDE stays usable, above all its Stop button: if dialogs blocked the IDE too, a program waiting in one could not be stopped.
  - **Looking at a file during a run.** While a program runs, the file list starts with a "Run window" entry. Choosing a file shows the file; choosing the entry brings back the run window exactly as it was, an open dialog included, still waiting for its answer. The run window is never rebuilt while hidden, so a dialog cannot be lost.
  - **Stop with a dialog open** closes the dialog and ends the program, wherever the user is looking.
  - **Files are read-only while a program runs.** The program runs the code it started with; to change it, the user stops it first. The playground instead stops a program when its code is edited (I5 in `apps/playground/lib/src/dom/app.dart`); the IDE does not, because a stray keystroke in a file would end a program that may be waiting in a dialog, without the user asking. The code editor (D36) and the form designer keep this rule.
  - Tests: `apps/ide/test/ide_shell_test.dart`.
- **Projects on disk** (D32): on macOS and Windows the File menu at the IDE's top left opens a project's `.gbproj` file, saves the project's changed files (Save) and copies the whole project into a new folder (Save As…). The built-in examples are never overwritten: they can be changed, and Save on one saves a copy. Unsaved changes are marked with "— Edited" after the project's name, and the IDE asks before they would be lost: when another project is opened, or the IDE quits. Nothing is opened or saved while a program runs. Tests: `apps/ide/test/folders_test.dart`, `folders_io_test.dart`, `project_menu_test.dart`.
- **Projects in the browser** (D33): on the web the same File menu keeps projects in the browser and adds Download .zip and Upload .zip…; a .zip button stays in the top bar and a status line below it says where the project is. Tests: `apps/ide/test/browser_test.dart`, `project_zip_test.dart`, `web_menu_test.dart`, and `test/web/` in Chrome.
- **The form designer** (D34): choosing a `.form.yaml` file shows the form as the run window will, drawn by the same runtime widgets (`formModelOf` and `FormWindowFrame` in `apps/ide/lib/src/form_window.dart`), with a toolbox at its left; only in the designer, a Label, which draws no edge of its own, has a dotted one, so that an empty Label can be found. A control is drawn by choosing its type and dragging a rectangle on the form in any direction (a click, or a drag of a few pixels, places it at its default size), or placed in the middle of the form by double-clicking its type. Dragging the selected control moves it, its eight handles resize it, and the handles on the form's right and bottom edges resize the form; ⌘ and an arrow key (Ctrl on Windows) move the selected control, Shift and an arrow key resize it. The mouse cursor shows what a drag would do. Delete or Backspace removes the selected control, Undo and Redo (⌘Z / ⇧⌘Z; Ctrl+Z / Ctrl+Y) step through the changes, Esc goes back to the pointer, and an 8-pixel grid can be turned on and off. "View form file" shows the file's text. The Properties window at the right (D35) chooses the form or a control from a list and changes its properties: text as it is typed, numbers on Enter or when the field is left. The designer only shows the form while a program runs, and when the form file has errors. Tests: `apps/ide/test/designer_test.dart`, `form_edit_test.dart`.
- **The runtime does not choose fonts.** The app around it does, through its theme, so that desktop and phone apps keep using the system's fonts. The IDE brings its own font, Pretendard, and uses it on every platform (D30). The controls on a form have their own sizes and colours (`gbFormTheme`, D49), and take only the font from the app around them.
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

Every control — including the built-in Button, Label, TextBox, CheckBox and ListBox — is a **component** described by a `component.yaml`:

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

The same metadata powers the toolbox, the Properties window, autocompletion and the transpiler. `layer: graphic` (Label) draws a control under the others, `layer: control` (the default) in front of them (D41).

The built-in components live in `components/` (`Form`, `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`; see [LANGUAGE.md](LANGUAGE.md) §11.1). The analyzer needs their properties and events on every platform, the web included, where it cannot read files, so `tool/embed_components.dart` copies each `component.yaml` into `gubasic_lang`, and CI checks that the copy is up to date (D27).

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
chkShow.Click         ' a click on a CheckBox: Checked changes, Changed runs
lstCity.Select 2      ' the user picks item 2 of a ListBox; Changed runs
OK                    ' closes the open MsgBox
Answer "Kim"          ' answers the open InputBox (Cancel gives "")
Close                 ' closes the form
```

A step runs only when the program waits for the user: no handler runs, the running ones wait in `DoEvents`, or a dialog is open. So the output is the same on every platform. `NAME.out` echoes each step as `> step`, then lists what the program showed (`Debug.Print`, `MsgBox`, `InputBox`), every property it set (`Set lblMessage.Caption: Hello`) and what happened to events (`Ignored: …`, `Blocked: …`). Its last line says how the run ended: `Closed`, `Ended`, `Stopped` or `Error R0xx @ line`. The runner is `package:gubasic_lang/testing.dart`, shared by the VM tests, the Chrome tests and the IDE's widget tests (`apps/ide/test/widget_parity_test.dart`). The widget tests do each step on the real run window: they tap the button, type into the TextBox, press the dialog's buttons and the window's close button. A step whose widget is covered by an open dialog, or not on the screen yet (during `Form_Load`), does not reach the program and is `Blocked`, as it would be for the user. So the controls of a parity form must not overlap.

---

## 10. Data

| Feature | Stage | Notes |
|---|---|---|
| `Settings` (key-value; VB's `SaveSetting` / `GetSetting`) | 1 | `shared_preferences`, one text per project (D48) |
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
| D30 | **The IDE brings its own font and engine.** It bundles Pretendard 1.3.9 (Regular and Bold, OFL, `apps/ide/fonts/pretendard/`; D49) and uses it on every platform: web, macOS and Windows. The web build is made with `--no-web-resources-cdn`, so the engine (CanvasKit) and the fallback fonts come from the same server as the app, not from Google's CDN. The first visit shows "Loading…" ("불러오는 중…") with how much has come (D43) until the first frame. Bold is an asset loaded after the first frame (`BoldFont`): only the handlers that exist in the code editor's Event list use it (D38), drawn from Regular until it has come. **Before the first frame a first visit fetches 4.2 MB** (gzip, as GitHub Pages sends it; the files a first visit fetched from a local build, compressed with `gzip -9`, which matched Pages for every file before): Regular 1.05 MB, CanvasKit 2.1 MB, the app's code 0.95 MB, everything else 0.1 MB; Bold's 1.07 MB follows. With Noto Sans KR 2.004 it was 6.9 MB, measured on https://kooboom.github.io/gubasic/ide/ (Regular 3.7 MB, Bold 3.9 MB after). Every file comes from the IDE's own host; D2Coding is not fetched (D36). **A second visit** within ten minutes fetches nothing: Pages sends `Cache-Control: max-age=600`, and the browser uses its copies. After that the browser asks again, and Pages answers `304 Not Modified` (by `ETag`) without the files: under 0.01 MB, the first frame after 1.6 s instead of 0.4 s (measured from home). | GuBASIC draws forms to the pixel. If the Korean font differs between platforms (macOS's and Windows' default fonts), the width of each letter differs, and a Label drawn to fit on one platform is cut off on the other. With the same font everywhere, the IDE keeps the designer's promise: a form looks the way it was drawn. Serving the engine and fonts ourselves also makes the web IDE work where Google's servers are blocked, and avoids missing Hangul syllables seen with fonts fetched from the CDN ([flutter/flutter#188255](https://github.com/flutter/flutter/issues/188255)). Cost: the desktop IDE grows by about 3 MB as well; for a development tool this is accepted. Apps built later do not get the font: see KNOWN_ISSUES |
| D31 | **The IDE writes form files in one layout** (`writeFormFile` in `gubasic_lang`): properties in `component.yaml` order, only values that differ from the defaults, quotes only where YAML would read the text differently, and `\uXXXX` escapes for invisible characters and line separators. Comments and the layout of a hand-written file are not kept | The same form always gives the same bytes, so saving creates no Git change and an edit shows as the lines it touched (D13). Keeping comments would need a YAML editor that keeps the original text; with the designer, hand-written form files are the exception. Writing in `gubasic_lang` keeps it testable with plain `dart test` against the reader (CLAUDE.md rule 1): the examples are written back byte for byte, and any text reads back as itself |
| D32 | **A project is a `.gbproj` file** and, for each form it lists, `FORM.form.yaml` and `FORM.gbas` next to it; other files in its folder are left alone. The desktop IDE opens a project by its `.gbproj` file, as Visual Basic 6 opens a `.vbp`, through the system's dialogs (`file_selector`). **Save** (⌘S / Ctrl+S) saves the project: every file of it that changed, `.gbproj`, `.form.yaml` and `.gbas` alike. Each is written to a temporary file that then replaces it, and the IDE asks first if a file was changed on disk by another program since it was opened. **Save As** copies the whole project into a new folder: the user chooses a place and a name in the system's save dialog, and the IDE makes the folder `NAME` with `NAME.gbproj` (its `name:` set to `NAME`, written as D31 does) and the forms' files; it never writes into a folder that is already there, and it does not ask file by file as Visual Basic 6 did. The save dialog is told it saves a `.gbproj` file, a type the macOS app declares in its `Info.plist` (`io.github.kooboom.gubasic.project`; an undeclared one made macOS add another extension, `.band`), so macOS adds the extension ([Apple](https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes)) and does not ask to replace a folder of the project's name; if that folder is there, the IDE says it does not overwrite an existing project. A project's name cannot contain a dot, since macOS may show a folder named like `MyQuiz.band` as another program's document. **A form's `.form.yaml` and `.gbas` are one pair with one name:** they are always saved together, and renamed together. Saving one form on its own (Visual Basic 6's "Save Form1 As") is decided with multiple forms in stage 2. **The built-in examples are never overwritten**: they can be changed (D34), and Save on one works as Save As. While a project has unsaved changes, "— Edited" follows its name in the title. **The macOS IDE is not sandboxed.** So the first time a project in the Documents, Desktop or Downloads folder is opened, macOS asks once whether the IDE may use that folder; it must be allowed, or the forms next to the `.gbproj` cannot be read. A new app identifier asks again. On the web, projects are kept in the browser instead (D33) | Opening the project file is what Visual Basic users know. In the macOS App Sandbox an app may use only the items the user chose ([Apple](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)): with a chosen `.gbproj` file it could not read or save the forms next to it, so the IDE runs without the sandbox, with the user's own rights, as an app distributed outside the App Store may. A folder per project is what the files already are (§7, D13), so a project can be copied, zipped or put in Git as it is. Replacing a file in one step means a crash or a full disk leaves the old file or the new one, never half of it; asking before overwriting keeps another program's changes from being lost silently. Keeping the examples unchanged means every student starts from the same project, and a copy makes clear where their own work is. The title's mark shows what is unsaved even when the message after saving was missed. `file_selector` is the Flutter team's package ([pub.dev](https://pub.dev/packages/file_selector)); on the web it can only open files, so the web gets its own way to save |
| D33 | **The web IDE keeps projects in the browser, and the `.zip` is what keeps them safe.** A project saved on the web is kept in the browser's `localStorage`, one key per project, every key starting with `gubasic.ide.` and holding JSON with its layout's version; it is kept again a moment after each change and when the page is hidden. Examples are never overwritten: Save asks for a name and keeps a copy. **Download .zip** (also a button always in the top bar) gives `NAME.zip` with the folder `NAME/` and the project's files, which the desktop IDE opens as it is; the button stands out, and the browser asks before the page is left, while there are changes that were not downloaded. A status line says the project is kept in this browser and when it was last downloaded, and the first save tells, once per browser, that a shared PC may clear it and Safari removes it after 7 days without a visit. **Upload .zip…** takes a project back: a `.zip` of at most 1 MB, 100 GuBASIC files and 2 MB unpacked; an entry with an absolute path or `..` refuses the whole file; only `.gbproj`, `.form.yaml` and `.gbas` are taken, at the top or in one folder, others left out and named; every refusal says why (en/ko) | A browser cannot write files on disk (D32), but students must not lose work to a reload or a closed tab, so projects are kept automatically. Browser storage does not last: users and shared PCs clear it, and Safari deletes a site's script-writable storage, `localStorage` included, after seven days of use without a visit ([WebKit](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/)); so the `.zip` stays one click away and is asked for while it matters. The prefix keeps the IDE's keys apart from other pages on the same site (`kooboom.github.io` also serves the playground). `localStorage` is synchronous, so a project is kept even as the page closes, and projects are a few kilobytes of text. An uploaded file comes from outside, so it is checked before anything is kept. `.zip` files are read and written with the `archive` package ([pub.dev](https://pub.dev/packages/archive)), since `.zip` files made by systems are compressed |
| D34 | **The form designer changes the form file, one action at a time.** Each finished action (placing, moving, resizing or deleting a control, resizing the form, or one arrow key) writes the whole form file again with `writeFormFile` (D31) into the open project, as a change to that file; while the mouse is dragged, only the screen changes: the runtime's widget follows the mouse at once. The selected control is moved with the mouse, or with ⌘ and an arrow key on macOS (Ctrl and an arrow key elsewhere), and resized with its eight handles or with Shift and an arrow key, which moves its right or bottom edge; the form is resized with the handles on its right and bottom edges, never below 64 pixels. A control stays inside the form and is never smaller than 8 pixels. So "— Edited", Save (only the changed form file), the web's automatic keeping and F5 work as for any change of a file, with nothing of their own. Undo and Redo go through the texts the file had, up to 100 steps for each form file; the history ends with the project, and undoing back to the saved text clears "— Edited". A new control is named after its type with the smallest number no control uses, in any case (`Button1`, `Label1`, `TextBox1`), and is selected at once; a Button's or Label's `Caption` starts as its name, a TextBox's `Text` empty. With the grid on (8 pixels; on at first, for every form) controls are placed and sized in its steps and an arrow key goes to the next grid line; with it off, to the pixel. The examples can be changed as well; they are never overwritten (D32). A form file with errors is only shown, with its errors | One way of changing a form keeps the designer and the file in step: the file is always what the designer shows, written the same way every time, so a change shows in Git as the lines it touched (D13). Texts make undo exact for any action, and it cannot drift from what the file holds. A name made of the type and a number says what the control is and is a valid name (LANGUAGE.md §1); a Label that shows its name can be seen on the form at once, and a TextBox usually starts empty. Writing a form file with errors again would drop the entries that could not be read. Moving the widget itself, not an outline, shows at once how the form will look. On macOS, Control and the left or right arrow switch between desktops (Spaces) and do not reach the app ([Apple](https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac)), so ⌘ moves controls there |
| D35 | **The Properties window applies text as it is typed, and numbers on Enter.** At the designer's right, a list chooses the form or any control, and the chosen one's (Name) and properties follow in its component.yaml's order. Text (Caption, Text) goes into the form file as it is typed, the way the designer's other actions do (D34), so the canvas shows it at once; a number goes in on Enter or when the field is left, and is only checked while it is typed. As in a TextBox (LANGUAGE.md §11.1), only the characters the input method has committed go into the file: a syllable being composed shows in the field and, as typed, on the canvas, but not in the file or the undo history (the author found the form following every keystroke more natural); leaving the field or Enter commits it, and Esc while composing drops only it (a second Esc puts the value back). The changes made in one field are one step of undo, which ends when the field loses the focus, on Enter, or in another field. A value that is not valid (not a number, or outside the component.yaml's range) is not applied: the field says why, in English or Korean, and shows the last valid value again when it is left; Esc puts back the value the field had and returns to the form. The ranges are the component.yaml's only: a typed Left may be negative, while the mouse and the arrow keys keep controls inside the form. **The designer's keys (Delete, Backspace, Undo, Redo, the arrows, Esc) work only while the form has the focus**; in a field they edit its text, and ⌘Z / Ctrl+Z undoes the field's text. The toolbar's Undo always undoes the form. The form's (Name) is its file's name and is not changed here (stage 2). **A control's (Name) is renamed in the form's code with it (D39).** A new name applies on Enter or when the field is left, and only if it is usable (`isUsableName`), no other control has it, and the code does not use it already: no name in the code, in any case, is it or starts with it and `_` (a handler); comments and strings do not count (`linesUsingName` in `gubasic_lang`). `Caption` stays as it is | Seeing text on the form while typing it is what makes the window useful, and one step per field keeps undo usable. A number being typed passes through values nobody meant: retyping a Width of 120 with real keys in Chrome gave 12, then 1, and the control shrank to 1 pixel on the way, so numbers wait for Enter. In a text field, keys edit the text; Backspace in an empty field deleting a control would lose work without a word. Refusing a value instead of correcting it keeps what the user wrote from being changed silently. A typed value is exact, so it follows the language's rules, not the mouse's. A syllable being composed is not yet what the user typed: replaying the recorded Korean input methods into the field (`apps/ide/test/properties_ime_test.dart`) wrote ㄱ, 가, 갉 into the form on the way to 갈가 until only committed text was written. A click on the form while composing takes the focus before the input method commits, so the field commits as it is left, or the last syllable would be lost. Renaming only the control would leave the code pointing at a control that is gone, or a handler that no longer runs, without a word (VB6's orphaned handlers, §4). A new name already in the code would silently change what that code means |
| D36 | **The code editor is Flutter's `TextField`, coloured by the lexer, in D2Coding loaded on first use.** Choosing a `.gbas` file opens it in the code editor: line numbers, keywords, strings, comments, numbers and the form's controls coloured from the same tokens the interpreter reads (`lex`), Tab and Shift+Tab indenting to stops of 4 spaces, Enter keeping the line's indentation, ⌘Z / Ctrl+Z undoing the typing. As in the Properties window (D35) and the TextBox (LANGUAGE.md §11.1), only the characters the input method has committed reach the file, so a syllable being composed is never saved or run; leaving the editor commits what is being composed. Lines do not wrap. The font is **D2Coding 1.3.2 Regular** ([naver/d2codingfont](https://github.com/naver/d2codingfont/releases/tag/VER1.3.2), OFL), whose Hangul is exactly twice as wide as its Latin letters; it is an asset, not a declared font, loaded when the code editor first opens, and code shows in the IDE's font until it arrives (about 2.1 MB gzipped on the web, 4.2 MB in the desktop app). The IDE opens a project on its first form, in the designer, so the first visit does not fetch it. A change to the code file made elsewhere (by the designer, later) shows in the editor and starts its undo history again | The text field Flutter gives is the one the TextBox and the Properties window already use, so the recorded Korean input methods replay into it (`apps/ide/test/code_ime_test.dart`); code editor packages were compared first, and neither one that does its own input handling ([re_editor](https://pub.dev/packages/re_editor)) nor one with open input method reports ([flutter_code_editor #126](https://github.com/akvelon/flutter-code-editor/issues/126)) was taken. Colours from the lexer can never disagree with the language. A font with Hangul at exactly two columns keeps code aligned with Korean comments and strings; D30's reasons apply, but the school network's first visit already takes long, so the font waits until code is opened. 1.3.2 is the release the author chose; the later ones change only metadata, ligatures, a dotted-zero option, hinting and control-character mappings that draw nothing in the editor |
| D37 | **Where the platform leaves out the composing range, the runtime guesses it.** In the macOS desktop app (Flutter 3.47.7, macOS 27, the 2-set Korean input method), every jamo arrives as committed text, the syllable before the caret replaced in place, with no composing range (`test/ime_logs/macos-app.json`, recorded with `tool/ime_probe` as a macOS app; semantics off); Chrome on the same Mac gets the range. So on the macOS desktop, while the platform has never sent a range for a field, `ComposingTracker` in `gubasic_runtime` takes a Hangul letter typed or changed just before the caret as being composed, until a new syllable starts, a key that is not Hangul comes, the caret moves, or the field commits it (Enter, a click, losing the focus). The TextBox, the Properties window and the code editor all use it. A range the platform sends is trusted from then on | LANGUAGE §11.1 promises the same events everywhere; without this, a TextBox in the macOS app ran `Changed` at every jamo and the designer showed 갈ㄱ. Replayed through the guess, the macOS app's recording makes exactly the events pinned for Chrome on the same Mac (`text_box_test.dart`). It is the input method's behaviour, not Flutter's: in TextEdit, a native macOS app, the syllable being composed is not underlined either, while Chrome's address bar on the same Mac underlines it (checked by the author, macOS 27.0.1, `com.apple.inputmethod.Korean.2SetKorean`). So no Flutter issue was filed; the closest one, [flutter/flutter#194199](https://github.com/flutter/flutter/issues/194199), needs semantics on. If Flutter starts sending the range, the guess is no longer used. The cost: the last syllable reaches the program when the input method moves on or the field commits, as on the web |
| D38 | **A double-click in the designer opens the default event's handler; the code editor has Object and Event lists.** Double-clicking a control opens the code file on the handler of its component.yaml `defaultEvent` (`Button`, `Label`: Click; `TextBox`: Changed), double-clicking the empty form on `Form_Load`. If the handler is there (any case, read by the lexer, so comments and strings never count) the caret goes to the end of its first body line; if not, `Sub NAME_EVENT(…)` with an empty indented line and `End Sub` is added at the end of the code, after an empty line, with the caret on that line, the signature from the component's event (`EventSpec.handlerSignature`). While a program runs only a handler that is there opens; otherwise the IDE says why. Above the code, an Object list ((General), `Form`, the controls) and an Event list (the object's events, those with a handler in bold; under (General), (Declarations) and the procedures that handle nothing) go to a handler or add it the same way, and follow the caret. A handler just added is undone with one ⌘Z / Ctrl+Z. The two presses of a double-click must be on the same control, at most 8 pixels apart | Double-click → handler stub is what stage 1 promises (ROADMAP); the lists are the VBA code window's Object and Procedure boxes ([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/code-window)); they also reach events no double-click opens, such as the form's other events. Adding at the end keeps the code where the user put it. The field's own history keeps a step only every half second, so a handler added as the editor opens would otherwise be part of the first step. Flutter's double tap allows 100 pixels between presses, which suits a finger, not a mouse |
| D39 | **Renaming a control renames it in the form's code, in one step.** A new (Name) from the Properties window (D35) goes into the form's `.gbas` too: every name in the code that is the old name, in any case, or starts with it and `_` (its handlers: `btnHello_Click` → `btnOk_Click`) gets the new name in place of that part. The code is read by the lexer (`renameInCode` in `gubasic_lang`), so comments, strings and other names such as `btnHelloWorld` stay as they are. After `.` a name is renamed only in `Me.`: elsewhere it is a member (`lblMessage.Caption`). Before the rename, the Properties window says on which lines the code uses the name. One undo takes the form and its code back together, one redo forward; if the code was changed after the rename, undo renames the names in it back instead of putting back the old text. The code editor shows the new code and starts its undo history again (D36). Only the form's own code is renamed, where its controls are used (LANGUAGE.md §11) | Renaming the handlers with the control is what keeps them attached (VB6's orphaned handlers, §4), the ones a double-click opens (D38) included. The lexer's tokens are the ones the interpreter reads, so the program means what it meant. A new name the code already uses is refused (D35), so every renamed name was the control's, and renaming back gives the same code, the old name spelled one way (`names_test.dart`). Putting back the old text after the code was changed would lose that change |
| D40 | **An error in the output goes to its line; the line a run stopped on is marked.** An error in the output that has a line in a code file (a run-time error, or an error that keeps the project from starting) is underlined; a click opens that file in the code editor with the caret on that line, after its indentation. The line where the last run stopped with a run-time error has a band behind it, the width of the editor, while the code file is exactly as it was run: a change to the code, or a new run, takes it away, since the line may no longer be the one that failed. Errors that keep the project from starting are not marked in the code, only listed | It is what the playground already does for run-time errors (ROADMAP), and what a beginner needs most: the message says which line, the click shows it. Marking only while the code is unchanged never points at a line the error was not on. The band is drawn behind the field, not in its text, so the text field and its input method are untouched (D36) |
| D41 | **Controls are drawn in two layers: graphic (Label) under control (Button, TextBox).** A component.yaml's `layer` puts a control in the graphic layer or, by default, the control layer. The graphic layer is drawn first, whatever the order of the form file; within a layer, a control later in the form file's `controls` list is drawn on top. The control on top takes the click where controls overlap, in the run window and in the designer alike, and hides what is under it: a Button is filled with the theme's `surfaceContainerHigh`, a shade darker than the form (`gbButtonFace`). The order is `GbFormModel.drawingOrder` in `gubasic_runtime`, which the run window draws by, the designer draws and picks by, and the apps the transpiler makes will draw by, since they use the same runtime (§2.3). **What changed:** before, the file's order alone decided, so a Label written after a Button covered it and took its clicks; such a form now shows the Button on top. The form file's format does not change (`formatVersion: 1`): stage 1 has not been released, and no migration could keep the old look, which is what this fixes. The examples have no controls that overlap, so they look as before (`designer_test.dart`) | A Label laid over a Button made the Button impossible to click, at run time and in the designer. In Visual Basic 6 a form has three layers, graphical controls and Labels in the middle one and other controls in front, and ZOrder arranges controls only within their layer ([ZOrder Method](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa267180(v=vs.60))); GuBASIC has no drawing layer yet, so two remain. One function decides for every place a form is shown, so the designer cannot show one thing and the program do another |
| D42 | **In the designer, Tab and Option-click choose controls; ⌘J / ⌘K order them; a right click opens the designer's menu.** While the form has the focus, Tab and Shift+Tab choose the next and the previous control in the form file, round again at the end; in the Properties window and the code editor Tab stays theirs. A click chooses the control on top (D41); Option-click (Alt-click) chooses the one under the chosen control there, round again from the top, and opens no code. ⌘J / Ctrl+J (Bring to Front) moves the chosen control to the end of the form file's list, on top of its layer, and ⌘K / Ctrl+K (Send to Back) to its start, under it; the toolbar has both, each change one step of undo. The two shortcuts go by where the key is, not by its letter: with a Korean input method on, Chrome on a Mac reports Ctrl+K as ㅏ. A right click, a two-finger click, or Control and a click on Apple systems opens the designer's context menu, a control there chosen first: on a control View Code (as a double-click, D38), Bring to Front, Send to Back, Delete and Properties (the Properties window's first field takes the focus); on the empty form View Code (Form_Load) and Grid. While a program runs only View Code works. On the web the browser's own menu is turned off while the mouse is over the form. The menu is opened by one function from a place on the form, so a long press on a touch screen can open it later | Overlapping controls (D41) need a way to the one underneath. In Visual Studio's Visual Basic 6.0 shortcut scheme, Tab selects the next control on the design surface and Ctrl+J brings it to the front ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/ms172689(v=vs.90))); Ctrl+K is Send to Back in the VBA UserForm window ([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/userform-windowc-visual-basic-user-interface)). A plain click that went round the controls would clash with a double-click (D38) and with dragging. Moving within the list keeps the form file's format (D41). The context menu gathers what the designer can do with what is under the mouse, where a beginner looks for it |
| D43 | **On the web, the loading text shows how much has come: "Loading… 37%".** A build step (`apps/ide/tool/web_load_sizes.dart`, run by CI and by the Pages workflow) writes `load_sizes.json`: the size of the app's code (`main.dart.js`), of each CanvasKit build and of each font in the font manifest. `web/flutter_bootstrap.js` wraps `fetch` before Flutter's loader starts and counts the bytes of the engine and the fonts as they arrive, whether or not Flutter has read them yet; `main.dart.js`, loaded by a `<script>` tag, counts when it has arrived (Resource Timing). The percentage is what has come of the files the page needs: only the CanvasKit build the loader chose counts. It stops at 99% and goes away with the first frame. Without `load_sizes.json` the text stays "Loading…". Every file is still fetched once, by Flutter itself: checked in Chrome and in WebKit (the engine of Safari), on a throttled network | On a slow network (D30: about 100 seconds on a slow 4G profile) a text that never changes looks like a page that has stopped, and a student reloads it, starting again. A percentage of the bytes that have come moves with the network. Fetching the files ahead of Flutter, to count them, would rely on the browser's cache to hand them over, and fetch them twice where it does not; counting Flutter's own fetches does not. Naming only the step ("engine", "fonts") was the fallback, but it stays still for a minute on the biggest step |
| D44 | **CheckBox: `Caption`, `Checked` As Boolean, and one event, `Changed`.** A click on the box or on its `Caption` changes `Checked` and runs `Changed`; the program setting `Checked` runs it too, right away, as for `TextBox.Changed` (LANGUAGE §11.1). Two states only. While its own `Changed` runs, a click on the CheckBox is ignored and does not change it: the widget asks first (`Interpreter.refusal`, through the runtime's `GbEventFilter`). A click commits the text being composed first, as before a `Click`. In an event script, `chkShow.Click` is the user's click. Default size 120 × 32 | Visual Basic 6's `Value` (0, 1, or 2 for grayed) became `Checked` (Boolean) and `CheckState` in Visual Basic .NET, and VB6's `Click` is raised also when the program changes the state, so .NET code uses `CheckStateChanged` instead ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/kk8bb7ac(v=vs.90))); the default event of a Windows Forms CheckBox is `CheckedChanged` ([dotnet/winforms](https://github.com/dotnet/winforms/blob/main/src/System.Windows.Forms/System/Windows/Forms/Controls/Buttons/CheckBox.cs)). `If chkShow.Checked Then` reads as what it means, with no constants to learn, and a grayed third state has no use on a beginner's form. `Caption` matches Button and Label. An event called `Click` that also ran on the program's changes would not say what it does; `Changed` follows the TextBox. A box that changed under a running handler would show a state the handler never saw |
| D45 | **Controls can have methods, read-only properties, and properties set only while a program runs.** A component.yaml lists `methods:` (`AddItem(item As String)`, `List(index As Integer) As String`) and marks a property `readOnly: true` (the program reads it; the component's code works it out instead of keeping it: ListBox's `ListCount`), `designTime: false` (not in the form file, F013, nor in the Properties window: `ListIndex`), or `internal: true` (state the runtime keeps, which programs reach only through methods: a ListBox's items). Giving a read-only property a value is A034, for `List.Count` too. A method is called like any procedure, its arguments in parentheses (LANGUAGE §7); one that changes a property with a change event runs that event as part of the call (D46). Through an `Object`, whether `o.Name(x)` is a call or an item is decided when it runs, for lists and text as well | A ListBox has to be filled and read from code, and LANGUAGE §4 already writes `lstNames.AddItem(n)`. Visual Basic .NET's `Items` collection would hand the program an object tied to the screen, which a variable can keep and change behind the control's back; methods keep every change going through the control. `methods:` was in the component.yaml design from the start (§5). A value that is worked out cannot go stale, and keeping run-time state out of the form file keeps the file what the designer draws |
| D46 | **ListBox: `AddItem`, `RemoveItem`, `Clear` and `List(index)`; `ListCount`, `ListIndex` and `Text`; one event, `Changed`.** Visual Basic 6's names. Items are numbered from 0; `ListIndex` is −1 when nothing is chosen and only the program sets it, while it runs; `Text` is the chosen item, or `""`. `Changed` runs whenever `ListIndex` changes: the user picks another item, the program sets `ListIndex` (right away, as part of the assignment), or `RemoveItem` / `Clear` moves or removes the chosen item, as part of the call. Removing an item above the chosen one moves the choice up by one, so the same item stays chosen; removing the chosen one, or `Clear`, leaves nothing chosen. A pick while its own `Changed` runs is ignored and changes nothing (as in D44). An item number that does not exist is R003. `AddItem` takes no position and there is no `Sorted`. Items are added only in code for now (KNOWN_ISSUES). In the designer an empty ListBox shows its name. In an event script, `lstCity.Select 2` is the user picking item 2. Default size 160 × 120 | Visual Basic 6 has `AddItem`, `RemoveItem`, `Clear`, `List`, `ListCount`, `ListIndex` (run time only, −1 for none, and setting it raises `Click`) and `Text` ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa242144(v=vs.60))); Visual Basic .NET renamed them `Items.Add`, `Items.Count` and `SelectedIndex` ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/2yc9d57t(v=vs.90))), and the default event of its ListBox is `SelectedIndexChanged` ([dotnet/winforms](https://github.com/dotnet/winforms/blob/main/src/System.Windows.Forms/System/Windows/Forms/Controls/ListBoxes/ListBox.cs)). One rule, "`Changed` runs when `ListIndex` changes", whatever the cause, says what VB6's `Click`, which also runs on the program's changes, does not. The VB6 documentation warns that `AddItem` with a position in a sorted list gives unpredictable results; a quiz needs neither |
| D47 | **CI hands out the Windows IDE and the IME probe ready to run.** The Windows job builds both and uploads each `Release` folder as an artifact of the run (`gubasic-ide-windows`, `ime-probe-windows`, kept 30 days), with the Visual C++ runtime (`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, copied from the runner's `System32`) next to the `.exe`. A Windows PC unzips the folder and runs the `.exe`: no Flutter, no Visual Studio, no redistributable to install on Windows 10 or later (x64): apart from those three DLLs, the `.exe` and `.dll` files import only Windows' own DLLs and the Universal CRT (`api-ms-win-crt-*`), which is part of Windows 10 and later ([Microsoft](https://learn.microsoft.com/en-us/cpp/windows/universal-crt-deployment)); checked with `objdump -p` on the first artifacts. The apps are not signed, so Windows may warn before the first start | Visual Studio is needed to build a Windows app, not to run it. A Flutter Windows app needs the `.exe`, the `.dll` files and the `data` folder next to it, and the Visual C++ runtime, which may be installed or placed next to the app ("application-local") ([Flutter](https://docs.flutter.dev/platform-integration/windows/building)). Placing it next to the app works on a school PC where nothing can be installed. This lets the Windows app be tried, and its input method recorded, on the school PC |
| D48 | **`SaveSetting` / `GetSetting` keep text for each project, by its name.** Two arguments, a key and a value; the project's name (`.gbproj` `name`) takes the place of Visual Basic's application name, and there are no sections. Keys do not tell case apart; values are text. A project's settings are one JSON text, which the interpreter reads the first time the program asks and writes whole at each `SaveSetting`, at most 65536 characters (R011); a failure to keep it is R012. `gubasic_runtime`'s `GbSettingsStore` keeps them, in `shared_preferences` under the key `gubasic.settings.<project>`: on macOS in the IDE's user defaults (`~/Library/Preferences/io.github.kooboom.gubasic.ide.plist`, checked with `defaults read`), on Windows in `%APPDATA%\Jungmo Gu\GuBASIC IDE\shared_preferences.json` (the app support folder, [path_provider_windows](https://github.com/flutter/packages/blob/main/packages/path_provider/path_provider_windows/lib/src/path_provider_windows_real.dart), and the file name, [shared_preferences_windows](https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences_windows/lib/shared_preferences_windows.dart)), on the web in the browser's `localStorage` under that key, apart from the IDE's own keys (`gubasic.ide.`, D33). The playground keeps one set for all its programs under `gubasic.playground.settings`. Settings are not part of a project's files or `.zip`. File → Clear Saved Settings forgets the open project's. `DeleteSetting` is left for later | Visual Basic keeps settings by application, section and key, under `HKEY_CURRENT_USER\Software\VB and VBA Program Settings` ([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/savesetting-statement)); a beginner's program needs one name for itself and keys, and the project already has a name. Settings are the user's data, as the registry's are, so they stay out of the project's files. The limit keeps a runaway loop from filling the browser storage the web IDE keeps its projects in. One store in the runtime is what generated apps will use too (D11) |
| D49 | **The IDE looks like a calm, dense desktop development tool; the controls on a form are square and calm.** The IDE's theme (`ideTheme`): Pretendard (D30) with its character variant `cv05`, the lowercase l with a tail, everywhere, so that `lblName` and `lstCity` do not read as `IblName` and `IstCity`; 13 px text, 12 px in lists and the Properties window, all of normal weight; compact density (list rows of 26 px); corners of 4 px at most; greys with a blue accent (`ColorScheme.fromSeed` with the neutral variant); D2Coding at 13 px in the code editor. The controls on a form have a theme of their own in `gubasic_runtime` (`gbFormTheme`), apart from the IDE's, so that the run window, the designer and later generated apps draw them alike whatever the IDE looks like: 13 px text of normal weight; a grey Button with dark text and corners of 3 px; a TextBox, ListBox and CheckBox with corners of 2 px; ListBox rows of 22 px. Only the font, its family and features, comes from the app around them (§2.3). A Button that cannot be clicked keeps Material's grey text, ready for an `Enabled` property. Chosen from looks compared side by side on the Mac and in Chrome: the IDE as it was, a compact one in Noto Sans KR, and the same in Pretendard; the forms as they were and square | The IDE looked like a toy: large, heavy text, round corners and pill-shaped buttons; the author wanted the quiet density of a desktop development tool. Pretendard holds all 11,172 Hangul syllables and the 51 compatibility jamo (counted in the font's character map) and is a third of Noto Sans KR's size, so a first visit fetches 2.7 MB less (D30). Its l and I look alike; `cv05` is in the font (its GSUB table maps l to the tailed l). Keeping the forms' look apart from the IDE's means that a change of the IDE's look never changes the controls a student drew |
