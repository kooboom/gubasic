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

## The playground does not run forms

- **What:** forms run in the IDE's run window (`apps/ide`) and in the parity tests, but the playground runs only programs without a form: there, controls and `Me` are still reported (A003).
- **Why deferred:** the playground is pure Dart without Flutter; imitating controls in HTML would create a second runtime (D24). The IDE's web build (E1e) runs forms in the browser instead.
- **Revisit:** when the IDE's web build is published; then decide whether the playground still needs its Run tab.

## The run window is inside the IDE's window

- **What:** a running program's form is shown in the middle of the IDE's window, not in a window of its own. Moving it or running two programs side by side is not possible.
- **Why deferred:** one window works the same on the desktop and on the web; separate windows need platform code for each desktop system.
- **Revisit:** with the form designer, when the IDE's windows are laid out.

## Korean typing is tested in Chrome only so far

- **What:** the TextBox tests replay what the Windows and the macOS (2-set) Korean input methods sent in Chrome (`packages/gubasic_runtime/test/ime_logs/`). Desktop apps have not been tried with a real input method yet: on macOS this comes with the IDE run window; on Windows, building them needs Visual Studio, which is not installed on the Windows PC (by decision).
- **What the two recordings showed:** both keep the promises of LANGUAGE §11.1. They differ in one place: on macOS a space goes into the composition and is committed together with the syllable before it, so after 닭 the text goes straight to `닭 ` and `Changed` never sees `닭` alone; on Windows `닭` is committed first. Both commit what is being composed when the field loses the focus, about 150 ms before a click on the web.
- **Known Flutter problems to check then:** on Windows desktop, syllables can be lost when typing fast ([flutter/flutter#189491](https://github.com/flutter/flutter/issues/189491), open). On the web, a composition dropped by the browser can leave a stale composing range ([flutter/flutter#193847](https://github.com/flutter/flutter/issues/193847)); it is fixed on Flutter's master branch but not in 3.47.7. Neither Chrome recording showed it: leaving the field committed the text cleanly.
- **Why deferred:** the recordings need a person typing on each system; Visual Studio is a large install that is not needed for the web.
- **Revisit:** when the IDE run window runs on macOS desktop (E1d), and when Visual Studio is installed on the Windows PC.

## Apps built later may cut off text drawn in the IDE

- **What:** the runtime does not choose fonts (DESIGN §2.3), so apps made later by the transpiler will use the device's default font, while the IDE uses its bundled Noto Sans KR (D30). Letters can then be wider in the released app than in the IDE, and text in a Label drawn to fit can be cut off.
- **Why deferred:** there is no transpiler yet.
- **Revisit:** in the transpiler stage. Options include putting the same font into generated apps (they grow by about 9 MB), or having the designer warn when text may be cut off.

## The web IDE's font loading is checked on macOS only

- **What:** with all outside hosts blocked (headless Chrome on macOS, `--host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"`, the web build served locally), the IDE shows its Korean words correctly and the page fetches nothing from outside: the engine, the fonts and the fallback font come from the local server. Missing syllables as □ ([flutter/flutter#188255](https://github.com/flutter/flutter/issues/188255)) did not appear. Text first drawn in the wrong font and corrected once the font arrives ([flutter/flutter#77023](https://github.com/flutter/flutter/issues/77023)) should not happen, because the font comes with the app and is loaded while the engine starts; a screenshot of the finished page cannot show such a brief change, so this was not observed directly.
- **Why deferred:** the earlier measurements (a blank page with the default build, □ without a bundled font) were made on the Windows PC; repeating them with this build needs that PC.
- **Revisit:** on the Windows PC with the same blocked-hosts check, and after the Pages deploy (E1e), in a normal browser.

## On the web, the code view is not monospace

- **What:** the IDE's code view and output ask for the `monospace` font, which the web build does not have, so code is shown in a proportional font there (Hangul in it uses Noto Sans KR).
- **Why deferred:** a monospace font would add to the download (D30), and the code view is read-only until the code editor arrives.
- **Revisit:** with the code editor (ROADMAP), which chooses the font for code.
