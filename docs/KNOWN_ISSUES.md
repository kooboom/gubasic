# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## Settings are not available yet

- **What:** `SaveSetting` and `GetSetting` are reported before running (A029) and cannot be used.
- **Why deferred:** where settings are stored differs between platforms (shared_preferences in apps, the browser's storage in the playground). It belongs with `gubasic_runtime`, so that the interpreter and generated apps store them the same way (D11).
- **Revisit:** when `gubasic_runtime` arrives.

## Controls and the form cannot be used yet

- **What:** names of controls (`lblMessage`, `btnSave`) and `Me` are reported as not declared (A003), with a note that controls become available once the form designer exists. Control types (`Button`) are unknown types (A004). The README example therefore shows one diagnostic.
- **Why deferred:** controls come from form files and `gubasic_runtime`, which do not exist yet. Imitating them in the playground would create a second runtime (D24).
- **Revisit:** when the form designer and `gubasic_runtime` arrive.
