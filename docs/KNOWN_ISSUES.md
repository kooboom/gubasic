# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## The smallest Integer cannot be written as a literal

- **What:** `-9223372036854775808` (the smallest `Integer`) is reported as too large (L006). The minus sign is an operator, so the literal itself is `9223372036854775808`, one more than the largest `Integer`.
- **Why deferred:** the lexer cannot know whether a minus sign belongs to the number (`-5`) or is a subtraction (`x -5`). Rarely needed; `Integer.MinValue`-style constants can cover it later.
- **Revisit:** in the analyzer stage, consider treating an integer literal with a leading minus sign as a single value.

## Controls and the form cannot be used yet

- **What:** names of controls (`lblMessage`, `btnSave`) and `Me` are reported as not declared (A003), with a note that controls become available once the form designer exists. Control types (`Button`) are unknown types (A004). The README example therefore shows one diagnostic.
- **Why deferred:** controls come from form files and `gubasic_runtime`, which do not exist yet. Imitating them in the playground would create a second runtime (D24).
- **Revisit:** when the form designer and `gubasic_runtime` arrive.
