# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## Very long loops are slow

- **What:** a loop of a million rounds (`total = total + i * 2 - 1`) takes about 3 seconds in the playground's optimized web build and about 0.8 seconds on the VM.
- **Why deferred:** it is not a correctness problem, and programs of the size beginners write do not notice it.
- **Revisit:** when someone finds the playground or the IDE noticeably slow in practice, or in the transpiler stage.

## Settings are not available yet

- **What:** `SaveSetting` and `GetSetting` are reported before running (A029) and cannot be used.
- **Why deferred:** where settings are stored differs between platforms (shared_preferences in apps, the browser's storage in the playground). It belongs with `gubasic_runtime`, so that the interpreter and generated apps store them the same way (D11).
- **Revisit:** when `gubasic_runtime` arrives.

## Forms run only in tests so far

- **What:** the interpreter runs programs with a form (D28), and the parity tests drive them with event scripts on the VM and in Chrome. But nothing shows a form on screen yet. The playground has no forms, so there controls and `Me` are still reported (A003).
- **Why deferred:** showing the controls needs `gubasic_runtime` and the IDE's run window, which come in the next change. The playground will not imitate controls in HTML, which would create a second runtime (D24).
- **Revisit:** when the IDE's run window exists.
