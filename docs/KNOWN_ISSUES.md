# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## A missing closing parenthesis is not reported on its own

- **What:** in `total = (1 +`, the parser reports only the missing value after `+` (P001). The missing `)` (P003) is not reported separately.
- **Why deferred:** the parser reports one syntax error per statement, so that one mistake does not produce a cascade of follow-up errors. Fixing the reported problem and re-checking reveals the next one.
- **Revisit:** in the analyzer stage, when we see how often this happens in real code and whether a combined message ("missing value and `)`") is worth it.

## Integers above 2⁵³ are approximate on the web

- **What:** when `gubasic_lang` runs as JavaScript (the playground, later the web IDE), an integer literal between 2⁵³ and 2⁶³−1 gets an approximate value: `9223372036854775807` becomes `9223372036854776000`. The literal's text is kept exactly, and the lexer's diagnostics are the same on every platform.
- **Why deferred:** reporting it needs a *warning* severity, which diagnostics do not have yet. It belongs in its own small change.
- **Revisit:** the next pull request (a warning for integer literals above 2⁵³, reported identically on every platform).

## Undeclared loop variables

- **What:** `For i = 1 To 10` parses, but whether `i` must be declared first is not decided. Declaration is otherwise always required ([LANGUAGE.md](LANGUAGE.md) §3.1).
- **Why deferred:** it is a rule about names and scopes, which the analyzer checks, not the parser. Recommended answer: an undeclared `For` / `For Each` variable is declared automatically, visible only inside that loop (as VB.NET's `Option Infer`). See [LANGUAGE.md](LANGUAGE.md) §12.
- **Revisit:** the analyzer stage.
