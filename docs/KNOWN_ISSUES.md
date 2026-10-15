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

## Programs with a form cannot run yet

- **What:** code is checked together with its form file (D27): controls, `Me` and event handlers are known, and the README example ([examples/hello](../examples/hello)) has no diagnostics. But nothing runs a program with a form yet: the interpreter does not deliver events, and nothing shows a form. The playground has no forms, so there controls and `Me` are still reported (A003).
- **Why deferred:** running a form needs events in the interpreter and `gubasic_runtime` to show the controls. They come next, one change each. The playground will not imitate controls in HTML, which would create a second runtime (D24).
- **Revisit:** when the IDE's run window exists.
