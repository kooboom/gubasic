# GuBASIC Roadmap

[한국어](ROADMAP.ko.md)

Each stage ends with something that runs. Small, finished stages beat a big unfinished one.

---

## Stage 0 — Design

- [x] Design decisions ([DESIGN.md](DESIGN.md))
- [x] Language draft ([LANGUAGE.md](LANGUAGE.md))
- [x] Repository setup: license, CI that runs `dart test`

## Stage 1 — Draw, double-click, run (done, v0.1.0)

The core Visual Basic experience, entirely inside the IDE.

- [x] IDE shell on macOS (Windows build kept working; also runs on the web)
- [x] Form designer: toolbox, canvas, drag / resize, Properties window
- [x] Built-in components: `Form`, `Button`, `Label`, `TextBox`
- [x] Built-in components: `CheckBox`, `ListBox` (example: [quiz](../examples/quiz))
- [x] Built-in component: `Image` (D51–D55; example: [quiz](../examples/quiz))
- [x] Absolute layout (`Left`, `Top`, `Width`, `Height`)
- [x] `Anchor`, `Form_Resize`; form size presets (Phone / Tablet / Desktop) (D57–D60)
- [x] Project files in plain text (`.gbproj`, `.form.yaml`, `.gbas`)
- [x] Lexer and **error-tolerant** parser
- [x] Analyzer: names, scopes and types, with plain-language diagnostics (English / Korean)
- [x] Web playground for development ([try it](https://kooboom.github.io/gubasic))
- [x] Code editor: syntax highlighting, double-click → handler stub, rename-safe handlers
- [x] Light autocompletion (keywords, controls, members, "did you mean")
- [x] **Async interpreter**, running programs in the playground's Run tab
- [x] F5 runs the app inside the IDE
- [x] `MsgBox`, `InputBox`, `DoEvents`, `Try…Catch`
- [x] `Settings` (`SaveSetting`, `GetSetting`), each project's own (D48)
- [x] Run-time errors with plain-language messages (English / Korean), click to jump to the line (playground)
- [x] Run-time errors highlighted in the IDE's code editor

**Done when:** a beginner can build a small quiz app and run it without installing Flutter.

## Stage 2 — Build real apps (next)

The plan, its steps and decisions: [STAGE2_PLAN.md](STAGE2_PLAN.md) (D79–D86).

- [x] The run window in a package shared by the IDE and the player (2-1)
- [x] **The player**: one project as an app of its own, built by CI for the web, macOS and Windows; sizes and speed measured (2-2)
- [x] The project bundle, with a format version and room for several forms, and the app ID (2-3, D83)
- [ ] File → Export as app: web `.zip` (2-4, done, D84), Windows `.zip` (2-5, done, D86), macOS from the macOS IDE (2-6)
- [ ] Parity programs run through the player too
- [ ] Layout: `LayoutMode` (Vertical / Horizontal / Grid), `Dock`
- [ ] `Handles` clause; run-time control creation
- [ ] `OptionButton`: radio buttons, of which one in a group is chosen, with a way to form groups (in Visual Basic 6 the option buttons on a form are one group and those in each frame another: [Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa241737(v=vs.60))). A natural control for a quiz's choices; the stage 1 quiz uses a ListBox
- [ ] Menus in students' apps: a menu bar and right-click menus (Visual Basic 6's [Menu Editor](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/62aawczc(v=vs.90)) and [PopupMenu](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa716251(v=vs.60)); Visual Basic .NET's `ContextMenuStrip`, same source)
- [ ] `Database` (SQLite) and `Http` + JSON
- [ ] Multiple forms and `Form2.Show` platform behavior (2-7, 2-8); decide then whether one form can be saved on its own (Visual Basic 6's "Save Form1 As"; until then Save saves the whole project, D32)
- [ ] `Timer` control (2-9) and `KeyDown` / `KeyUp` (2-10) (D82)
- [ ] `ByRef`

**Done when:** one project ships to the web, macOS and Windows.

## Stage 3 — Ecosystem

- [ ] Transpiler: GuBASIC → Dart → Flutter project, with the parity suite running the transpiled Dart in CI; earlier if the criteria of STAGE2_PLAN §7 call for it (D79)
- [ ] Flutter SDK download and a GitHub Actions template for native builds, with the transpiler
- [ ] Android builds, with the phone Player (D80)
- [ ] iOS builds
- [ ] **GuBASIC Player** for phones
- [ ] Extra components from pub.dev via `component.yaml` adapters
- [ ] `Supabase` and `Firebase` components; secret-key warning
- [ ] Publish menu: Vercel, Firebase Hosting, GitHub Pages, personal server
- [ ] Per-size layout overrides
- [ ] Type-aware autocompletion
- [ ] Embedded-Dart escape hatch

## Beyond 1.0 (ideas)

More ideas, not yet planned, are kept in [IDEAS.md](IDEAS.md): among them [adventure game controls](IDEAS.md#adventure-game-controls).

- Debugger (breakpoints, step, watch)
- Data binding (VB's Data control)
- Automatic component adapters generated from a package's API
- User-defined classes
- **Self-hosting:** redraw parts of the GuBASIC IDE with GuBASIC itself

---

## What 1.0 will *not* do

Writing this down is what keeps a side project finishable.

- No class inheritance or user-defined classes
- No data binding / Data control
- No debugger beyond error highlighting
- No `On Error`, no `GoTo`
- No control arrays
- No `Variant`
- No Korean (non-ASCII) identifiers
- No plugin marketplace
