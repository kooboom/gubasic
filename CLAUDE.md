# CLAUDE.md — rules for AI coding assistants

Read this before changing anything in this repository.

## What this project is

GuBASIC: a Visual Basic–style RAD tool built with Flutter. Users draw forms, double-click controls and write event handlers in a BASIC dialect. The same code runs instantly in an interpreter inside the IDE and is transpiled to Dart for native release builds.

Source of truth, in this order:
1. `docs/DESIGN.md` — architecture and decisions (D1–D20)
2. `docs/LANGUAGE.md` — language rules
3. `docs/ROADMAP.md` — what belongs to which stage

If a request conflicts with these documents, **stop and say so** instead of silently diverging. If a decision changes, update the document in the same change.

## Layout

```
apps/ide/                Flutter IDE, desktop and web
apps/player/             Phone player (stage 3)
apps/playground/         Web playground for development (pure Dart, no Flutter)
packages/gubasic_lang/   Pure Dart: lexer, parser, AST, analyzer, interpreter, transpiler
packages/gubasic_runtime/ Flutter runtime used by BOTH interpreter and generated apps
components/<Name>/       component.yaml + adapter
examples/                Sample projects
test/parity/             Interpreter-vs-transpiler parity tests
```

## Hard rules

1. **`gubasic_lang` must not depend on Flutter.** It must run with plain `dart test`.
2. **Interpreter and transpiler share one AST.** Never add a language feature to only one of them.
3. **Every language feature gets a parity test** in `test/parity/`: same program, same output, both modes. Do not merge if parity fails.
4. **The interpreter is async.** Every user procedure is async; every call to one is awaited. Do not introduce synchronous fast paths that change behavior.
5. **A running event handler must not re-enter.**
6. **Generated code and the interpreter use `gubasic_runtime` only** — never Flutter widgets directly.
7. **Every control is a component** described by `component.yaml`. Built-ins included.
8. **Layout changes add properties; they never change the meaning of existing ones.** Bump `formatVersion` and write a migrator for any breaking file change.
9. **The parser must recover from errors.** Never throw on the first syntax error; collect diagnostics and continue.
10. **Identifiers are ASCII; the language is case-insensitive.** Arrays are zero-based with upper-bound declarations. Classic string functions (`Mid`, `InStr`) are one-based. `And`/`Or` short-circuit.
11. **No `On Error`, no `GoTo`, no `Variant`, no control arrays.**
12. **Never put secrets in generated apps.** Warn on anything that looks like a service key.
13. **Do not use "Flutter" or "Visual Basic" in product, package or file names.** Descriptive use in documentation only.

## Conventions

- Dart: `dart format`, `flutter analyze` clean, null-safe.
- User-facing messages exist in English and Korean (`en`, `ko`).
- Documentation: English file first (`X.md`), Korean translation next to it (`X.ko.md`). Keep them in sync.
- Text files are LF everywhere (`.gitattributes`), so golden files and byte-for-byte test comparisons match on Windows and macOS alike.
- Small, focused changes. One feature per change, with its tests.
- Commit messages in English, imperative mood.
- Diagnostic messages say what is wrong and how to fix it, in one or two sentences; Korean ones use the documents' "~합니다" style.
- In Korean messages, never put a particle right after a placeholder (`{0}가`): attach it to a fixed word instead (`{0} 키워드가`, `{0} 블록이`).
- After a fixed English word, choose the Korean particle by how the word is read (Sub [섭] → 이나/과/을). If it reads awkwardly, join with "또는" instead ("Sub 또는 Function").
- Messages never suggest a fix that silently changes the program's meaning; if a fix has a trade-off, say so.
- English and Korean are both first-class: change and review both in the same commit.
- Claims about other languages or tools in docs need a source link; if none can be found, leave the claim out.
- Anything deliberately left unfixed goes into `docs/KNOWN_ISSUES.md` (what, why deferred, when to revisit).
- Merge only when the author says so: fast-forward locally (rebase onto `main` first if needed), push `main`, then delete the branch locally and remotely. Never merge on GitHub: fast-forward keeps the history linear, with every commit authored exactly as configured.
- After merging, verify that local and remote `main` point to the same commit, and that CI and the Pages deploy on `main` succeeded, before reporting done. If a command reports failure, check the actual repository state before retrying.

## Before you finish a task

- `dart tool/check_flutter.dart` in `packages/gubasic_runtime` passes (the pinned Flutter, D29)
- `dart test` in `packages/gubasic_lang` passes
- `flutter test` in `packages/gubasic_runtime` passes
- Parity tests pass
- Docs updated if behavior or a decision changed
