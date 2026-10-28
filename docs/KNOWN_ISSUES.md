# Known issues

[한국어](KNOWN_ISSUES.ko.md)

Problems we know about and have **deliberately** left unfixed for now. Each entry says what it is, why it was deferred, and when it will be looked at again. When an issue is fixed, remove its entry in the same change.

---

## Very long loops are slow

- **What:** a loop of a million rounds (`total = total + i * 2 - 1`) takes about 3.3 seconds in the player in Chrome, 1.1 seconds in WebKit and 1.3 seconds in the macOS player, since the interpreter pauses by time (STAGE2_PLAN §7); before, 7.5, 7.1 and 1.4 seconds.
- **Why deferred:** it is not a correctness problem, and programs of the size beginners write do not notice it.
- **Revisit:** when someone finds the playground or the IDE noticeably slow in practice; step 2-2 measures it in the player and sets the criteria for the transpiler (STAGE2_PLAN §7, D79).

## The playground does not run forms

- **What:** forms run in the IDE's run window (`apps/ide`) and in the parity tests, but the playground runs only programs without a form: there, controls and `Me` are still reported (A003).
- **Why deferred:** the playground is pure Dart without Flutter; imitating controls in HTML would create a second runtime (D24). The IDE's web build (E1e) runs forms in the browser instead.
- **Revisit:** when the IDE's web build is published; then decide whether the playground still needs its Run tab.

## Projects kept in the web IDE's browser can be lost

- **What:** on the web, projects are kept in the browser, in IndexedDB (D33, D53). Clearing the browser's data removes them, shared PCs may do that at every logout, and Safari removes them after seven days without a visit. Two tabs with the same project keep whichever saved last.
- **Why deferred:** a web page cannot keep files on disk by itself. The IDE makes the `.zip` download one click away, asks for it while there are changes that were not downloaded, and says so when a project is first saved.
- **Revisit:** if users lose work in practice; then consider saving into a folder where browsers allow it (the File System Access API, Chrome and Edge only).

## Changes made as the web IDE's page closes can still be lost

- **What:** a change is kept in IndexedDB a moment after it is made; as the page hides or goes away, its text is also written to `localStorage` and brought back at the next start (D54). It can still be lost when:
  - the page ends without `visibilitychange` or `pagehide`: the browser or the system crashes, the power goes, or a phone ends a tab without either event. What changed since the last finished write (about two seconds of work, or more while writes fail) is lost.
  - `localStorage` is full or turned off: the backup is not written, and nothing says so, since the page is closing.
  - a picture was being added or removed as the page closed: the picture is kept at once (D54), but if that write does not finish, the restored text names a picture that was not kept; the IDE says which.
  - the same project is open in two tabs: the backup of the tab hidden last wins, as with saving (above).
- **Checked:** in Chromium, a tab closed while its write was held, and in WebKit a page reloaded while its write could not commit: both brought the change back (Playwright, the release build). In Safari 27.0.1, by hand with the release build on a local server, a tab closed right after a change kept the change, but by the usual path: Safari asked whether to leave (the IDE asks whenever there are changes not downloaded, unkept ones included), and while it asked, the two-second keep finished, so nothing was left to bring back. **Not checked:** bringing a change back after a tab closes in Safari itself, that is, a close that comes before the keep finishes. Playwright's WebKit sends neither `pagehide` nor `visibilitychange` when it closes a page, even a plain one, so it cannot check this either. Also seen: Playwright's WebKit (1.56) crashed the page now and then on a reload or a navigation, on `main` as well; whether Safari does is not known.
- **Why deferred:** a page cannot delay its closing, and nothing a page can write is both larger than `localStorage` and synchronous.
- **Revisit:** when a Safari close can be made to come before the keep (Leave chosen within two seconds of the last change): check that the change comes back with the notice; and if users report losing work.

## The run window is inside the IDE's window

- **What:** a running program's form is shown in the middle of the IDE's window, not in a window of its own. Its corner resizes it (D59), but moving it or running two programs side by side is not possible.
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
- **Why deferred:** there is no transpiler yet. The player of stage 2 (D79) is an app of GuBASIC's own, so it can bring the IDE's font: step 2-2 does, and its apps then lay text out as the IDE does.
- **Revisit:** with the transpiler. Options include putting the same font into generated apps (they grow by about 3 MB), or having the designer warn when text may be cut off.

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

## A picture made smaller is a PNG, not a JPEG

- **What:** Make Smaller and Add (D56) writes a PNG. A phone photo of 1024 × 768 then takes 1.3–1.8 MB (macOS, Chrome, WebKit), close to the 2 MB a picture may take; a photo with much fine detail is made smaller again, to 768 pixels or less. As a JPEG it would take a few hundred KB. Windows was not tried; it decodes and encodes with the same Flutter calls.
- **Why deferred:** Flutter encodes PNG only ([Flutter](https://api.flutter.dev/flutter/dart-ui/ImageByteFormat.html)); a JPEG encoder is a package, or code of the IDE's own, and the user asked for no heavy dependency.
- **Revisit:** when users' photos often end up smaller than 1024 pixels, or projects reach the 10 MB limit with photos; and on the school PC with the Windows IDE.

## A ListBox's items are added only in code

- **What:** the designer cannot enter a ListBox's items, as Visual Basic 6's List property in the Properties window does; a program adds them with `AddItem`, usually in `Form_Load` (D46).
- **Why deferred:** it needs a property that holds a list of texts in the form file and a Properties window field with one item per line. The quiz of stage 1 fills its lists from code, question by question.
- **Revisit:** when a program needs fixed items (a list of choices that never changes), or with the next form file change.

## A ListBox is used with the mouse only

- **What:** a ListBox's item is chosen by clicking it. The arrow keys and typing a letter do not move the choice.
- **Why deferred:** the controls of a running form do not take the keyboard focus in turn yet (Tab), and a quiz is answered with the mouse.
- **Revisit:** when the run window gets keyboard focus for its controls (Tab between them).

## Several chosen controls are not changed together in the Properties window

- **What:** with several controls chosen (D97), the Properties window says to choose one: a property they share, such as `Anchor` or `Width`, cannot be set for all of them at once. The mouse resizes one control at a time; Shift and an arrow resize every chosen one.
- **Why deferred:** which properties controls of different types share, and what to show when their values differ, are rules of their own; moving, deleting, ordering, copying and pasting cover most of the work with several controls.
- **Revisit:** when forms with many controls of one kind, such as the input forms of v0.4, make it a burden.

## The designer's clipboard is its own

- **What:** controls copied or cut in the designer (D97) stay in the IDE, not on the system clipboard: they cannot be pasted into another IDE window, or as text into another program, and they are gone when the IDE closes.
- **Why deferred:** a browser asks the user before a page reads the clipboard, and text pasted from elsewhere would have to be checked as a form file is checked (F codes).
- **Revisit:** when two IDE windows are used side by side, or with separate windows on the desktop (D89).

## Controls go into a Frame only in the designer

- **What:** the program cannot put a control into a Frame (D105): a Frame has no `Controls` of its own, so `Me.Controls.Add` puts a control on the form itself, and a control removed from a Frame and added again is on the form. A Frame that holds controls cannot be removed (R023). In the designer a dragged control stays in its Frame; it goes in or out by cut and paste.
- **Why deferred:** a Frame's own `Controls`, and dragging into and out of Frames, add rules (which Frame a drop means, what happens to the Anchor) that the first programs with Frames do not need.
- **Revisit:** when programs make Frames' contents at run time, or users ask to drag controls into Frames.

## Keys a TextBox uses do not reach the form

- **What:** with `KeyPreview` True and a TextBox typed in, the form gets the keys the TextBox only types (letters, digits, Space), not those it acts on itself, such as the arrow keys, Home and End, which move its caret (D101).
- **Why deferred:** Flutter's text field takes those keys before the form can see them; letting the form see them first would mean taking them over from every text field.
- **Revisit:** when a program needs them, or with the menus' shortcut keys.

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
- **Revisit:** when users write programs of more than about 150 lines, or if the completion list's first frame shows on real machines: then lay out only the lines on screen.

## In the macOS app, the syllable being composed is not underlined

- **What:** in the macOS desktop app, Korean typed in a TextBox, the Properties window or the code editor shows no underline under the syllable being composed, and the last syllable reaches the program (or the form file) only when the next one starts, a non-Hangul key comes, or the field commits it (Enter, a click, losing the focus).
- **Why deferred:** macOS 27's Korean input method sends no composing range to native text views: TextEdit shows no underline either, while Chrome on the same Mac does (DESIGN D37). The runtime guesses the composition so that the events match the web's; the underline would need the range the input method does not send.
- **Revisit:** when a macOS update or Flutter sends the composing range in desktop apps; then the guess stops by itself (it is used only while no range has come), and `test/ime_logs/macos-app.json` should be recorded again.

## The IME recordings have no Enter that commits a syllable

- **What:** block completion (DESIGN D50) closes no block when Enter commits Hangul being composed. It tells that Enter by the composing state before the line break and, where the commit and the break come as two changes, by no key having gone down between them. The recordings in `packages/gubasic_runtime/test/ime_logs` have no Enter, so the tests replay the recordings up to their last composing moment and then send Enter as a browser does (the key, the commit, the break) and as the macOS app does (the break alone); that order is not recorded from a real input method.
- **Why deferred:** a new recording needs the author's keyboard on each machine (CLAUDE.md), and in the macOS app the editor's guess (D37) keeps the last syllable as being composed until something else comes, so the composing state alone covers it there.
- **Revisit:** at the next recording with `ime_probe`: add a scenario that ends a syllable with Enter, on macOS (Chrome and the app) and Windows (Chrome and the app).

## The desktop IDE has no list of recent projects

- **What:** on the web, when the IDE starts with an example and projects are kept in the browser, a bar says so and opens their list (DESIGN D74). The desktop IDE opens the project open last (D62) but keeps no list of the others; File → Open is the way to them.
- **Why deferred:** the web already knows its projects; the desktop would need a list of folders kept with the settings, and a way to drop the ones that are gone.
- **Revisit:** when users use the desktop IDE for more than one project at a time, or with File → Recent in the menu.

## An exported Windows app's file says GuBASIC Player

- **What:** the program of an exported Windows app is renamed after the project and its window has the project's name (D86), but the program's file properties, which Task Manager shows as its name, still say "GuBASIC Player", with GuBASIC's version and copyright; and SaveSetting keeps the values of every exported app in one file under the user's AppData folder, named after that same "GuBASIC Player", kept apart by app ID.
- **Why deferred:** changing them means rewriting the program's version resource, which the IDE does not do yet; the app ID keeps the apps' settings apart as it is.
- **Revisit:** with choosing an app's icon (STAGE2_PLAN §9), which rewrites the same resources.

## An exported macOS app's program is named GuBASIC Player

- **What:** an exported macOS app is named after the project, in the Finder, the Dock, its menus and Force Quit (D87), but the program inside it (`Contents/MacOS`) keeps the name `GuBASIC Player`, which `ps` and crash reports show; the app also keeps the template's `get-task-allow` entitlement, which lets a debugger attach.
- **Why deferred:** `codesign` cannot check an app whose program's name is not ASCII; a program named after an English project alone would make Korean projects differ. Removing the entitlement means writing the entitlements anew at each export.
- **Revisit:** with choosing an app's icon (STAGE2_PLAN §9), when the export writes more of the app's metadata.

## A project's forms share one window

- **What:** `Form2.Show` shows Form2 in the same window, or page, as Form1, which it covers (D88, D89); on the desktop the window takes Form2's size. Visual Basic and the plan before step 2-7 (DESIGN §3.3) opened a window for each form on the desktop.
- **Why deferred:** Flutter 3.47.7, which GuBASIC is pinned to, has the classes for several windows only as internal ones behind a flag; a window for each engine would keep the forms from sharing variables.
- **Revisit:** when Flutter's multi-window API is public.

## A dialog form has no close button

- **What:** a form shown by `ShowDialog` is drawn over the form behind it with no close button of its own (D89): only its code, `Me.Hide` or `Me.Close`, takes it away. A dialog whose code never does stays until the window is closed, which ends the program.
- **Why deferred:** a close button on the dialog needs a rule for what it does (Visual Basic .NET treats it as Cancel, with a `DialogResult`), which waits for `DialogResult` (D90).
- **Revisit:** with `DialogResult`.

## A form's closing cannot be cancelled

- **What:** `Form_Closed` runs after a form is closed, or before the program ends when the window is closed (D88); there is no event that can keep the form open, as Visual Basic 6's `QueryUnload` and .NET's `FormClosing` do with their Cancel argument.
- **Why deferred:** a Cancel argument is a `ByRef` parameter, which comes later in stage 2.
- **Revisit:** with `ByRef`.
