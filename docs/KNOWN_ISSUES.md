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

## The IDE does not reopen the last project

- **What:** the desktop IDE always starts with the `hello` example. A project has to be opened again with File → Open… each time.
- **Why deferred:** remembering projects (the last one, or a list of recent ones) is a feature of its own: where to keep the list, and what to do when a project was moved or deleted. Opening a project takes one dialog.
- **Revisit:** with a list of recent projects, or when students find reopening a burden.

## Projects kept in the web IDE's browser can be lost

- **What:** on the web, projects are kept in the browser's `localStorage` (D33). Clearing the browser's data removes them, shared PCs may do that at every logout, and Safari removes them after seven days without a visit. Two tabs with the same project keep whichever saved last.
- **Why deferred:** a web page cannot keep files on disk by itself. The IDE makes the `.zip` download one click away, asks for it while there are changes that were not downloaded, and says so when a project is first saved.
- **Revisit:** if students lose work in practice; then consider saving into a folder where browsers allow it (the File System Access API, Chrome and Edge only).

## Browser storage is too small for pictures

- **What:** `localStorage` holds about 5 MB per site. Projects today are a few kilobytes of text, but once forms can hold pictures (the `Image` control, stage 1) a few projects would fill it.
- **Why deferred:** nothing stores pictures yet, and `localStorage` is synchronous, so a project is kept even while the page closes.
- **Revisit:** with the `Image` control: move projects in the browser to IndexedDB (or another larger storage), with a converter for what is kept already.

## The run window is inside the IDE's window

- **What:** a running program's form is shown in the middle of the IDE's window, not in a window of its own. Moving it or running two programs side by side is not possible.
- **Why deferred:** one window works the same on the desktop and on the web; separate windows need platform code for each desktop system.
- **Revisit:** with the form designer, when the IDE's windows are laid out.

## Korean typing is tested in Chrome only so far

- **What:** the TextBox tests replay what the Windows and the macOS (2-set) Korean input methods sent in Chrome (`packages/gubasic_runtime/test/ime_logs/`). Desktop apps have not been tried with a real input method yet: on macOS this comes with the IDE run window; on Windows, building them needs Visual Studio, which is not installed on the Windows PC (by decision).
- **What the two recordings showed:** both keep the promises of LANGUAGE §11.1. They made the same events in all five scenarios: a space is committed together with the syllable before it, so after 닭 `Changed` sees `닭 ` but never `닭` alone. Only the signals on the way differ (macOS first puts the space into the composition). Both commit what is being composed when the field loses the focus, about 150 to 180 ms before a click on the web.
- **Known Flutter problems to check then:** on Windows desktop, syllables can be lost when typing fast ([flutter/flutter#189491](https://github.com/flutter/flutter/issues/189491), open). On the web, a composition dropped by the browser can leave a stale composing range ([flutter/flutter#193847](https://github.com/flutter/flutter/issues/193847)); it is fixed on Flutter's master branch but not in 3.47.7. Neither Chrome recording showed it: leaving the field committed the text cleanly.
- **Why deferred:** the recordings need a person typing on each system; Visual Studio is a large install that is not needed for the web.
- **Revisit:** when the IDE run window runs on macOS desktop (E1d), and when Visual Studio is installed on the Windows PC.

## Apps built later may cut off text drawn in the IDE

- **What:** the runtime does not choose fonts (DESIGN §2.3), so apps made later by the transpiler will use the device's default font, while the IDE uses its bundled Noto Sans KR (D30). Letters can then be wider in the released app than in the IDE, and text in a Label drawn to fit can be cut off.
- **Why deferred:** there is no transpiler yet.
- **Revisit:** in the transpiler stage. Options include putting the same font into generated apps (they grow by about 9 MB), or having the designer warn when text may be cut off.

## The web IDE's font loading is checked from a local server only

- **What:** with all outside hosts blocked (headless Chrome, `--host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"`, the web build served locally), the IDE shows its Korean words correctly and the page fetches nothing from outside: the engine, the fonts and the fallback font come from the local server. Checked on macOS and on Windows (Chrome 155; the only outside requests in the net log were Chrome's own, such as updates and spelling dictionaries). Missing syllables as □ ([flutter/flutter#188255](https://github.com/flutter/flutter/issues/188255)) did not appear.
- **First visit on a slow network** (Windows, headless Chrome, cache off, DevTools' Slow 4G preset: 562.5 ms latency, 180 kB/s, served from 127.0.0.1): "불러오는 중…" showed from 1.1 s until the first frame at about 102 s. The two Noto Sans KR files arrived at 100.3 s and 101.3 s, and the first frame came right after them. A screencast of every frame went from the loading text straight to the finished IDE in Noto Sans KR: no frame in another font, so text first drawn in the wrong font and corrected later ([flutter/flutter#77023](https://github.com/flutter/flutter/issues/77023)) did not appear. Running `typing` and putting 동해물과 백두산이 닭 값 into its TextBox showed it in the TextBox and the Label without □.
- **Why deferred:** all of this was served from 127.0.0.1, so no real network (such as a school network) was in between. That needs the Pages deploy (E1e).
- **Revisit:** after the Pages deploy (E1e): open the real address in a normal browser on the school PC, check that it loads on the school network, and measure how long the first visit takes.

## No copy and paste in the form designer

- **What:** the form designer cannot copy, cut or paste controls (⌘C / ⌘X / ⌘V, Ctrl+C / Ctrl+X / Ctrl+V).
- **Why deferred:** a pasted control needs a new name and a place, and what it copies depends on the properties the Properties window (E2d) will set; drawing a new control already takes one drag.
- **Revisit:** after E2d (the Properties window).

## The form designer selects one control at a time and keeps the drawing order

- **What:** only one control can be selected, so several cannot be moved or deleted together; a new control is always drawn above the others, and the order cannot be changed (no "bring to front" or "send to back").
- **Why deferred:** forms in stage 1 have a few controls that do not overlap; a group selection needs its own rules for moving and resizing.
- **Revisit:** when forms with many controls (ListBox, Image, stage 1) make it a burden, or with `Anchor`.

## The form designer needs a mouse

- **What:** controls are placed with the mouse (or a touchpad); the keyboard moves, resizes and deletes the selected control, and the Properties window chooses controls and takes typed values. On the web with Flutter's accessibility layer on (as a screen reader turns it on), a double-click in the toolbox did not place a control when tried in Chrome; choosing a tool and clicking on the form still works. The cause was not looked into.
- **Why deferred:** drawing a form is what the designer is for; keyboard ways in come step by step.
- **Revisit:** when the designer is checked with a screen reader (after E2d); placing a control from the keyboard would need the toolbox to take the focus.

## Undoing a rename after the code changed renames every use of the new name

- **What:** renaming a control renames it in the code (D39). If the code is changed after that and the rename is undone, every use of the new name in the code goes back to the old name, those written after the rename too; if the old name was meanwhile given to something else in the code (a variable, say), the two then share it, which the analyzer reports.
- **Why deferred:** the code after the rename is the user's; putting back the text from before it would lose their changes, and which of the new uses were meant for the control cannot be told. Undo right after a rename, the usual case, puts back the code exactly.
- **Revisit:** with refactoring in the code editor (rename from the code), when a rename can show what it changes before it does.

## Typing in a long code file can drop a frame

- **What:** each key re-lays out the whole code file in the code editor (D36). Measured in the macOS Release app, building a frame after a key takes up to 10 ms for 30 lines, 4–18 ms for 100 lines and 8–29 ms for 300 lines (the first keys the slowest), against 16.7 ms per frame at 60 Hz; typing a line into a 300-line file dropped 2 of 27 frames. In Chrome, one of 80 frames took longer than 20 ms there.
- **Why deferred:** Flutter's text field lays out its whole text, about 1,000 coloured pieces at 300 lines; the IDE no longer compiles the project or measures every line at each key, which halved it. Programs written in stage 1 are a few dozen lines.
- **Revisit:** when students write programs of more than about 150 lines, or with the code editor's autocompletion: then lay out only the lines on screen.

## In the macOS app, the syllable being composed is not underlined

- **What:** in the macOS desktop app, Korean typed in a TextBox, the Properties window or the code editor shows no underline under the syllable being composed, and the last syllable reaches the program (or the form file) only when the next one starts, a non-Hangul key comes, or the field commits it (Enter, a click, losing the focus).
- **Why deferred:** macOS 27's Korean input method sends no composing range to native text views: TextEdit shows no underline either, while Chrome on the same Mac does (DESIGN D37). The runtime guesses the composition so that the events match the web's; the underline would need the range the input method does not send.
- **Revisit:** when a macOS update or Flutter sends the composing range in desktop apps; then the guess stops by itself (it is used only while no range has come), and `test/ime_logs/macos-app.json` should be recorded again.
