# GuBASIC Roadmap

[한국어](ROADMAP.ko.md)

Each stage ends with something that runs. Small, finished stages beat a big unfinished one.

---

## Stage 0 — Design (current)

- [x] Design decisions ([DESIGN.md](DESIGN.md))
- [x] Language draft ([LANGUAGE.md](LANGUAGE.md))
- [x] Repository setup: license, CI that runs `dart test`

## Stage 1 — Draw, double-click, run

The core Visual Basic experience, entirely inside the IDE.

- [ ] IDE shell on macOS (Windows build kept working)
- [ ] Form designer: toolbox, canvas, drag / resize, Properties window
- [ ] Built-in components: `Form`, `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`, `Image`
- [ ] Absolute layout with `Anchor`; form size presets (Phone / Tablet / Desktop)
- [ ] Project files in plain text (`.gbproj`, `.form.yaml`, `.gbas`)
- [ ] Lexer and **error-tolerant** parser (lexer done)
- [ ] Code editor: syntax highlighting, double-click → handler stub, rename-safe handlers
- [ ] Light autocompletion (keywords, controls, members, "did you mean")
- [ ] **Async interpreter**; F5 runs the app inside the IDE
- [ ] `MsgBox`, `InputBox`, `DoEvents`, `Settings`, `Try…Catch`
- [ ] Runtime errors highlighted with plain-language messages (English / Korean)

**Done when:** a beginner can build a small quiz app and run it without installing Flutter.

## Stage 2 — Build real apps

- [ ] Transpiler: GuBASIC → Dart → Flutter project
- [ ] Build for macOS, Windows, Android, Web
- [ ] **Parity test suite** (interpreter vs transpiler) running in CI
- [ ] Flutter SDK auto-download on first Build
- [ ] GitHub Actions template for cloud builds
- [ ] Layout: `LayoutMode` (Vertical / Horizontal / Grid), `Dock`
- [ ] `Handles` clause; run-time control creation
- [ ] `Database` (SQLite) and `Http` + JSON
- [ ] Multiple forms and `Form2.Show` platform behavior
- [ ] `ByRef`

**Done when:** one project ships to four platforms.

## Stage 3 — Ecosystem

- [ ] iOS builds
- [ ] **GuBASIC Player** for phones
- [ ] Extra components from pub.dev via `component.yaml` adapters
- [ ] `Supabase` and `Firebase` components; secret-key warning
- [ ] Publish menu: Vercel, Firebase Hosting, GitHub Pages, personal server
- [ ] Per-size layout overrides
- [ ] Type-aware autocompletion
- [ ] Embedded-Dart escape hatch

## Beyond 1.0 (ideas)

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
