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

## Stage 2 — Build real apps (done, v0.2.0)

Done when one project shipped to the web, macOS and Windows (v0.2.0). The items it left open moved to stage 3 (D96).

The plan, its steps and decisions: [STAGE2_PLAN.md](STAGE2_PLAN.md) (D79–D91).

- [x] The run window in a package shared by the IDE and the player (2-1)
- [x] **The player**: one project as an app of its own, built by CI for the web, macOS and Windows; sizes and speed measured (2-2)
- [x] The project bundle, with a format version and room for several forms, and the app ID (2-3, D83)
- [x] File → Export as app: web `.zip` (2-4, D84), Windows `.zip` (2-5, D86), macOS `.zip` from the macOS IDE (2-6, D87)
- [x] Several forms: `Form2.Show`, `ShowDialog`, `Hide`, `Close`, shown one over another in one window on every platform (2-7, D88–D90); adding, renaming and deleting forms in the IDE (2-8, D91). One form is not saved on its own: Save saves the whole project (D90)

**Done when:** one project ships to the web, macOS and Windows.

## Stage 3 — Like Visual Basic, for work, a real tool, then the ecosystem

Three releases, then the rest (D94–D96). The order follows who GuBASIC is for (D92): Visual Basic's own ways of working first, then work with files and data, then the tools of a real development environment.

### v0.3 — Like Visual Basic

- [x] What replaces control arrays, as Visual Basic .NET does it (D95, D98): `Handles` for several controls, the handler told which control raised the event, a loop over a form's controls, controls created at run time
- [ ] Diagnostics for a control array or `On Error`, saying which of these to write instead (D95)
- [ ] `Timer` control and `KeyDown` / `KeyUp` (D82)
- [ ] Module files (`Module1.gbas`) and starting at `Sub Main` (D90)
- [x] Choosing several controls in the designer; copying and pasting them (D97)
- [ ] Menus in the apps made with GuBASIC, with a menu editor: a menu bar and right-click menus (Visual Basic 6's [Menu Editor](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/62aawczc(v=vs.90)) and [PopupMenu](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa716251(v=vs.60)); Visual Basic .NET's `ContextMenuStrip`, same source)
- [ ] `DialogResult`
- [ ] `OptionButton`: radio buttons, of which one in a group is chosen, with a way to form groups (in Visual Basic 6 the option buttons on a form are one group and those in each frame another: [Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa241737(v=vs.60))); `Frame`; `ComboBox`
- [x] The project explorer: forms, or the files on disk (D94)

### v0.4 — For work

- [ ] Open and save dialogs; reading and writing text files
- [ ] CSV files
- [ ] Date and format functions (`DateAdd`, `DateDiff`, `Format`)
- [ ] A grid control (DataGrid)
- [ ] PDF export
- [ ] An example of work automation: reading a CSV file and adding it up (D95)

### v0.5 — A real development tool

- [ ] Debugger: breakpoints, then stepping, then watching variables, then an Immediate window
- [ ] `Database` (SQLite) and `Http` + JSON

### After v0.5

- [ ] Transpiler: GuBASIC → Dart → Flutter project, with the parity suite running the transpiled Dart in CI. After the debugger; earlier when a component from pub.dev is needed, or a program goes past the criteria of STAGE2_PLAN §7 (D79, D96)
- [ ] Flutter SDK download and a GitHub Actions template for native builds, with the transpiler, for those who choose them (D95)
- [ ] Excel files as data (D92)
- [ ] Printing
- [ ] Sound; animation with several pictures
- [ ] Layout: `LayoutMode` (Vertical / Horizontal / Grid), `Dock`; per-size layout overrides
- [ ] `ByRef`
- [ ] Parity programs run through the player too
- [ ] Android builds, with the phone Player (D80)
- [ ] iOS builds
- [ ] **GuBASIC Player** for phones
- [ ] Extra components from pub.dev via `component.yaml` adapters
- [ ] `Supabase` and `Firebase` components; secret-key warning
- [ ] Publish menu: Vercel, Firebase Hosting, GitHub Pages, personal server
- [ ] Type-aware autocompletion
- [ ] Embedded-Dart escape hatch

## Beyond 1.0 (ideas)

More ideas, not yet planned, are kept in [IDEAS.md](IDEAS.md): among them [adventure game controls](IDEAS.md#adventure-game-controls).

- Data binding (VB's Data control)
- Automatic component adapters generated from a package's API
- User-defined classes
- **Self-hosting:** redraw parts of the GuBASIC IDE with GuBASIC itself

---

## What 1.0 will *not* do

Writing this down is what keeps a side project finishable.

- No class inheritance or user-defined classes
- No data binding / Data control
- No `On Error`, no `GoTo`
- No control arrays
- No `Variant`
- No Korean (non-ASCII) identifiers
- No plugin marketplace
