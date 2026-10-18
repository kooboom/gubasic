# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## Very long loops are slow

- **What:** a loop of a million rounds (`total = total + i * 2 - 1`) takes about 3 seconds in the playground's optimized web build and about 0.8 seconds on the VM.
- **Why deferred:** it is not a correctness problem, and programs of the size beginners write do not notice it.
- **Revisit:** when someone finds the playground or the IDE noticeably slow in practice, or in the transpiler stage.

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

- **What:** `localStorage` holds about 5 MB per site, and the web IDE shares its site with the playground (`kooboom.github.io`; their keys are apart, D33). Projects today are a few kilobytes of text, but once forms can hold pictures (the `Image` control, stage 1) a few projects would fill it.
- **Why deferred:** nothing stores pictures yet, and `localStorage` is synchronous, so a project is kept even while the page closes.
- **Revisit:** with the `Image` control: move projects in the browser to IndexedDB (or another larger storage), with a converter for what is kept already.

## The run window is inside the IDE's window

- **What:** a running program's form is shown in the middle of the IDE's window, not in a window of its own. Moving it or running two programs side by side is not possible.
- **Why deferred:** one window works the same on the desktop and on the web; separate windows need platform code for each desktop system.
- **Revisit:** with the form designer, when the IDE's windows are laid out.

## Korean typing is tested in Chrome only so far

- **What:** the TextBox tests replay what the Windows and the macOS (2-set) Korean input methods sent in Chrome (`packages/gubasic_runtime/test/ime_logs/`). Desktop apps have not been tried with a real input method yet: on macOS this comes with the IDE run window; on Windows, the app is built by CI and can be downloaded and run without installing anything (D47), so it can be recorded on the school PC.
- **What the two recordings showed:** both keep the promises of LANGUAGE §11.1. They made the same events in all five scenarios: a space is committed together with the syllable before it, so after 닭 `Changed` sees `닭 ` but never `닭` alone. Only the signals on the way differ (macOS first puts the space into the composition). Both commit what is being composed when the field loses the focus, about 150 to 180 ms before a click on the web.
- **Known Flutter problems to check then:** on Windows desktop, syllables can be lost when typing fast ([flutter/flutter#189491](https://github.com/flutter/flutter/issues/189491), open). On the web, a composition dropped by the browser can leave a stale composing range ([flutter/flutter#193847](https://github.com/flutter/flutter/issues/193847)); it is fixed on Flutter's master branch but not in 3.47.7. Neither Chrome recording showed it: leaving the field committed the text cleanly.
- **Why deferred:** the recordings need a person typing on each system.
- **Revisit:** on the school PC, with the Windows IDE and IME probe from CI (D47; the steps are in issue #14).

## Apps built later may cut off text drawn in the IDE

- **What:** the runtime does not choose fonts (DESIGN §2.3), so apps made later by the transpiler will use the device's default font, while the IDE uses its bundled Pretendard (D30). Letters can then be wider in the released app than in the IDE, and text in a Label drawn to fit can be cut off.
- **Why deferred:** there is no transpiler yet.
- **Revisit:** in the transpiler stage. Options include putting the same font into generated apps (they grow by about 3 MB), or having the designer warn when text may be cut off.

## The web IDE's font loading is not checked on the school network

- **What:** with all outside hosts blocked (headless Chrome, `--host-resolver-rules="MAP * ~NOTFOUND, EXCLUDE 127.0.0.1"`, the web build served locally), the IDE shows its Korean words correctly and the page fetches nothing from outside: the engine, the fonts and the fallback font come from the local server. Checked on macOS and on Windows (Chrome 155; the only outside requests in the net log were Chrome's own, such as updates and spelling dictionaries). Missing syllables as □ ([flutter/flutter#188255](https://github.com/flutter/flutter/issues/188255)) did not appear.
- **First visit on a slow network** (Windows, headless Chrome, cache off, DevTools' Slow 4G preset: 562.5 ms latency, 180 kB/s, served from 127.0.0.1): "불러오는 중…" showed from 1.1 s until the first frame at about 102 s. The two Noto Sans KR files arrived at 100.3 s and 101.3 s, and the first frame came right after them. A screencast of every frame went from the loading text straight to the finished IDE in Noto Sans KR: no frame in another font, so text first drawn in the wrong font and corrected later ([flutter/flutter#77023](https://github.com/flutter/flutter/issues/77023)) did not appear. Running `typing` and putting 동해물과 백두산이 닭 값 into its TextBox showed it in the TextBox and the Label without □.
- **On the Pages address** (E1e, https://kooboom.github.io/gubasic/ide/, headless Chrome on macOS with every other host blocked): the IDE opened, and every file came from kooboom.github.io; D30 has the sizes.
- **Why deferred:** no school network was in between. That needs a school PC.
- **Revisit:** on the school PC, following the steps in issue #14: open the address in a normal browser on the school network and measure how long the first visit takes.

## The loading percentage is not checked in Firefox

- **What:** the web IDE's "Loading… 37%" (D43) was checked in Chrome and in WebKit, the engine of Safari (Playwright 1.56, a local server, a throttled network): the percentage rose to 94–99%, went away with the first frame, and every file was fetched once. Firefox was not checked: Playwright's Firefox (142) does not start on this macOS, and Firefox is not installed. Firefox runs on its own engine, Gecko ([MDN](https://developer.mozilla.org/en-US/docs/Glossary/Gecko)), so the Chrome and WebKit results do not stand for it. The only part it shares with Safari is the build Flutter's loader picks: without Chrome's `Intl.v8BreakIterator` it gets the full CanvasKit build, not the Chromium one.
- **Why deferred:** checking it needs a Firefox that runs; nothing in the code is specific to one browser.
- **Revisit:** when Firefox is at hand (a school PC, or a Playwright release that starts here): open the IDE with the cache off and check that the percentage rises and each file is fetched once.

## The web IDE's fonts are sent as OTF, not WOFF2

- **What:** Pretendard goes to the browser as an OTF file that GitHub Pages compresses with gzip (Regular 1.6 MB, 1.05 MB on the wire). WOFF2 compresses fonts better, but Flutter's documentation lists only `.ttc`, `.ttf` and `.otf`, says WOFF and WOFF2 are not supported on desktop platforms, and says nothing of the web ([Flutter](https://docs.flutter.dev/cookbook/design/fonts)).
- **Why deferred:** the IDE uses one font list on every platform (D30), and the web's support is not documented; it was not tried.
- **Revisit:** if Flutter documents WOFF2 for the web, or if the first visit is still too slow on the school network.

## A ListBox's items are added only in code

- **What:** the designer cannot enter a ListBox's items, as Visual Basic 6's List property in the Properties window does; a program adds them with `AddItem`, usually in `Form_Load` (D46).
- **Why deferred:** it needs a property that holds a list of texts in the form file and a Properties window field with one item per line. The quiz of stage 1 fills its lists from code, question by question.
- **Revisit:** when a program needs fixed items (a list of choices that never changes), or with the next form file change.

## A ListBox is used with the mouse only

- **What:** a ListBox's item is chosen by clicking it. The arrow keys and typing a letter do not move the choice.
- **Why deferred:** the controls of a running form do not take the keyboard focus in turn yet (Tab), and a quiz is answered with the mouse.
- **Revisit:** when the run window gets keyboard focus for its controls (Tab between them).

## No copy and paste in the form designer

- **What:** the form designer cannot copy, cut or paste controls (⌘C / ⌘X / ⌘V, Ctrl+C / Ctrl+X / Ctrl+V).
- **Why deferred:** a pasted control needs a new name and a place, and what it copies depends on the properties the Properties window (E2d) will set; drawing a new control already takes one drag.
- **Revisit:** after E2d (the Properties window). When they come, Cut, Copy and Paste go into the designer's context menu too (D42).

## The form designer selects one control at a time

- **What:** only one control can be selected, so several cannot be moved, deleted or brought to the front together.
- **Why deferred:** forms in stage 1 have a few controls; a group selection needs its own rules for moving and resizing. The drawing order can be changed one control at a time (D42).
- **Revisit:** when forms with many controls (ListBox, Image, stage 1) make it a burden, or with `Anchor`.

## The form designer needs a mouse

- **What:** controls are placed with the mouse (or a touchpad); the keyboard chooses a control (Tab, Shift+Tab), moves, resizes, deletes and orders it, and the Properties window chooses controls and takes typed values. On the web with Flutter's accessibility layer on (as a screen reader turns it on), a double-click in the toolbox did not place a control when tried in Chrome; choosing a tool and clicking on the form still works. The cause was not looked into.
- **Why deferred:** drawing a form is what the designer is for; keyboard ways in come step by step.
- **Revisit:** when the designer is checked with a screen reader (after E2d); placing a control from the keyboard would need the toolbox to take the focus.

## Undoing a rename after the code changed renames every use of the new name

- **What:** renaming a control renames it in the code (D39). If the code is changed after that and the rename is undone, every use of the new name in the code goes back to the old name, those written after the rename too; if the old name was meanwhile given to something else in the code (a variable, say), the two then share it, which the analyzer reports.
- **Why deferred:** the code after the rename is the user's; putting back the text from before it would lose their changes, and which of the new uses were meant for the control cannot be told. Undo right after a rename, the usual case, puts back the code exactly.
- **Revisit:** with refactoring in the code editor (rename from the code), when a rename can show what it changes before it does.

## Typing in a long code file can drop a frame

- **What:** each key re-lays out the whole code file in the code editor (D36). Measured in the macOS Release app, building a frame after a key takes up to 10 ms for 30 lines, 4–18 ms for 100 lines and 8–29 ms for 300 lines (the first keys the slowest), against 16.7 ms per frame at 60 Hz; typing a line into a 300-line file dropped 2 of 27 frames. In Chrome, one of 80 frames took longer than 20 ms there.
- **With the completion list (D50):** measured inside the app (integration_test, no keyboard events from the OS) in the macOS Profile build, typing a line into a 300-line file, the frame after a key took 8.4 ms at the median and 9.4 ms at the 90th percentile, against 8.3 and 9.0 ms in a build from before the list; no frame missed its budget either way. In headless Chrome, which draws in software, the frame after a key takes 20–34 ms with or without the list, and the first list drawn takes one frame of 50–100 ms (drawing the new list); later lists take as long as any key. Finding a list takes about 40 µs; the code is compiled for it only when typing pauses.
- **Why deferred:** Flutter's text field lays out its whole text, about 1,000 coloured pieces at 300 lines; the IDE no longer compiles the project or measures every line at each key, which halved it. Programs written in stage 1 are a few dozen lines.
- **Revisit:** when students write programs of more than about 150 lines, or if the completion list's first frame shows on real machines: then lay out only the lines on screen.

## In the macOS app, the syllable being composed is not underlined

- **What:** in the macOS desktop app, Korean typed in a TextBox, the Properties window or the code editor shows no underline under the syllable being composed, and the last syllable reaches the program (or the form file) only when the next one starts, a non-Hangul key comes, or the field commits it (Enter, a click, losing the focus).
- **Why deferred:** macOS 27's Korean input method sends no composing range to native text views: TextEdit shows no underline either, while Chrome on the same Mac does (DESIGN D37). The runtime guesses the composition so that the events match the web's; the underline would need the range the input method does not send.
- **Revisit:** when a macOS update or Flutter sends the composing range in desktop apps; then the guess stops by itself (it is used only while no range has come), and `test/ime_logs/macos-app.json` should be recorded again.

## The IME recordings have no Enter that commits a syllable

- **What:** block completion (DESIGN D50) closes no block when Enter commits Hangul being composed. It tells that Enter by the composing state before the line break and, where the commit and the break come as two changes, by no key having gone down between them. The recordings in `packages/gubasic_runtime/test/ime_logs` have no Enter, so the tests replay the recordings up to their last composing moment and then send Enter as a browser does (the key, the commit, the break) and as the macOS app does (the break alone); that order is not recorded from a real input method.
- **Why deferred:** a new recording needs the author's keyboard on each machine (CLAUDE.md), and in the macOS app the editor's guess (D37) keeps the last syllable as being composed until something else comes, so the composing state alone covers it there.
- **Revisit:** at the next recording with `ime_probe`: add a scenario that ends a syllable with Enter, on macOS (Chrome and the app) and Windows (Chrome and the app).
