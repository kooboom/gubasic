# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## A missing closing parenthesis is not reported on its own

- **What:** in `total = (1 +`, the parser reports only the missing value after `+` (P001). The missing `)` (P003) is not reported separately.
- **Why deferred:** the parser reports one syntax error per statement, so that one mistake does not produce a cascade of follow-up errors. Fixing the reported problem and re-checking reveals the next one.
- **Revisit:** in the analyzer stage, when we see how often this happens in real code and whether a combined message ("missing value and `)`") is worth it.

## The smallest Integer cannot be written as a literal

- **What:** `-9223372036854775808` (the smallest `Integer`) is reported as too large (L006). The minus sign is an operator, so the literal itself is `9223372036854775808`, one more than the largest `Integer`. VB.NET behaves the same way.
- **Why deferred:** the lexer cannot know whether a minus sign belongs to the number (`-5`) or is a subtraction (`x -5`). Rarely needed; `Integer.MinValue`-style constants can cover it later.
- **Revisit:** in the analyzer stage, consider treating an integer literal with a leading minus sign as a single value.

## Undeclared loop variables

- **What:** `For i = 1 To 10` parses, but whether `i` must be declared first is not decided. Declaration is otherwise always required ([LANGUAGE.md](LANGUAGE.md) §3.1).
- **Why deferred:** it is a rule about names and scopes, which the analyzer checks, not the parser. Recommended answer: an undeclared `For` / `For Each` variable is declared automatically, visible only inside that loop (as VB.NET's `Option Infer`). See [LANGUAGE.md](LANGUAGE.md) §12.
- **Revisit:** the analyzer stage.
