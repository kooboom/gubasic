# Plan template

[한국어](PLAN_TEMPLATE.ko.md)

Every plan for a feature or a change is written in this shape and shown to the author before work starts. Leave a section out only by saying why.

## 1. What and why

- What the user will be able to do, in one or two sentences, with the smallest example program.
- Which stage of the [ROADMAP](ROADMAP.md) it belongs to, and the decisions it rests on (D numbers).

## 2. How it is used

- The syntax or the controls, as a user would write them, and what other versions of BASIC call the same thing (for the diagnostics that point to GuBASIC's name, D50).
- Messages: new diagnostics, in English and Korean.

## 3. Design

- Where it goes: `gubasic_lang`, `gubasic_runtime`, `gubasic_player`, the apps; new files.
- What it keeps open: the transpiler (one AST), the project format (`formatVersion`), the hard rules of CLAUDE.md.

## 4. No detours (D121)

Answer each:

- **Is there anywhere users would still have to go around?** Something they would have to imitate with low-level code, a workaround they would have to learn from a forum, or a limit that makes the usual way impossible. If so: what is built in instead, or why it is left for later (and then it goes into KNOWN_ISSUES).
- **Does it talk to the outside in a standard** (HTTP, JSON, WebSocket, CSV, SQLite, UTF-8), with a source for the standard?
- **Is there a way in for what it does not do itself** (the component channel, [COMPONENT_CHANNEL.md](COMPONENT_CHANNEL.md))?
- **Documents and examples:** which pages of LANGUAGE change, which example shows it, and what goes into the reference for AI assistants (`llms.txt`).

## 5. Tests

- Parity programs (`test/parity/`): VM, Chrome, the run window.
- Widget and integration tests, and what is checked by hand (on the web with Playwright; on the Mac only in ways that do not use the author's mouse and keyboard).

## 6. Questions for the author

Each with a recommendation.
