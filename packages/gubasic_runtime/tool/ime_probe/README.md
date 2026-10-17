# IME probe

[한국어](README.ko.md)

Records what a real input method sends to a Flutter text field, in the browser or in a desktop app: every value (text, the part still being composed, selection), keys, focus changes and clicks. The recordings are test input: `packages/gubasic_runtime/test/text_box_test.dart` replays every file in `test/ime_logs/` (DESIGN §9.1).

Recorded so far: `windows-chrome.json` (Windows Korean input method, Chrome), `macos-chrome.json` (macOS Korean input method, 2-set, Chrome) and `macos-app.json` (the same on macOS 27, in the macOS app). A desktop app's recording replays as that platform.

## Recording

Use the pinned Flutter first (`dart tool/check_flutter.dart` in `packages/gubasic_runtime`), then:

```sh
cd packages/gubasic_runtime/tool/ime_probe
flutter pub get
flutter run -d chrome --release     # the web IDE's path
flutter run -d macos --release      # the macOS app's path
flutter run -d windows --release    # the Windows app's path (on Windows)
```

The browser and the desktop apps take different paths from the input method to Flutter, so each is recorded on its own: the desktop app saves `ime-log-macos-app.json` or `ime-log-windows-app.json` in the Downloads folder (the snack bar says where), and the file is copied without the `ime-log-` prefix, as below.

1. Switch the system input method to Korean (2-set, 두벌식).
2. Do the five scenarios on the page in order. The page is in Korean; each scenario says which keys to type. The tests use only what comes after the last **다시** (again) of each scenario. Scenario 4 asks for 다시 once on purpose (button A, then button B).

   > **Before every new try, press 다시.** A mistake erased by hand stays in the recording and becomes part of what the tests check: the first Windows recording has two such tries mixed in.

3. Press **저장 (Save)** at the top right. The browser downloads `ime-log-macos-chrome.json` on a Mac, `ime-log-windows-chrome.json` on Windows.
4. Copy it into the tests without the `ime-log-` prefix:

   ```sh
   cp ~/Downloads/ime-log-macos-chrome.json ../../test/ime_logs/macos-chrome.json
   ```

5. Run `flutter test` in `packages/gubasic_runtime`. The new file gets its own test group, checked in two layers:
   - **The rules of LANGUAGE §11.1**, the same for every recording: `Text` holds only committed characters, `Changed` runs once per commit, no syllable in the middle of being typed comes out, and the final `Text` is the same. If one of these fails, the runtime does not keep its promise for this input method: fix the runtime, not the test.
   - **The exact events this recording made**, pinned in `recorded` at the end of `test/text_box_test.dart`. A new recording fails here with the events it made: check them by hand against what you typed, then add them. Input methods may differ here, although the Windows and macOS recordings made the same events; a later failure means a Flutter upgrade changed what that input method does.

   Keep every recording; never edit one by hand.

## What the recordings show

Behaviour seen in the recordings so far, with the scenario that shows it. Both recordings made the same events in every scenario; they differ only in the signals on the way (the space, below).

- **Backspace while composing is handled inside the input method.** 한 becomes 하 (scenario 3), 값 becomes 갑, 가, ㄱ (5-1), and 긂 becomes 글, 그, ㄱ (5-2): the text being composed shrinks one jamo at a time, nothing is committed, and `Changed` does not run. Windows and macOS.
- **A committed syllable is deleted in one step, and `Changed` runs once.** After the composition is gone, Backspace removes 닭 (5-1) or 한 (5-2) as a whole, never 달 or 하, and `Changed` runs once with the shorter text. Windows and macOS.
- **What was only being composed never reaches `Changed`.** 긂 in 5-2 and 값 while it is being erased in 5-1 are never committed, so `Changed` never shows them: in 5-2 it runs only for 한 and for the empty text. Windows and macOS.
- **A space is committed together with the syllable before it.** After 닭, `Changed` sees `닭 ` but never `닭` alone (scenario 2). The signals differ: macOS first puts the space into the composition (`닭 ` being composed), Windows replaces the composed 닭 with the committed `닭 ` at once. Windows and macOS.
- **The macOS app gets no composing range.** In `macos-app.json` every value has composing `[-1, -1]`: each jamo arrives committed and the syllable before the caret is replaced in place (ㄱ, 가, 갈, 갉, 갈, 갈가), and nothing is sent when the field loses the focus. The text is the same as in Chrome. The runtime guesses the composition there (DESIGN D37), and the events come out the same as Chrome's.
- **Leaving the field commits.** Both input methods commit what is being composed when the field loses the focus; on the web this happens about 150 to 180 ms before a click arrives (scenario 4).
