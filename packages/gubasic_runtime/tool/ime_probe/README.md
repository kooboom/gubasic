# IME probe

[한국어](README.ko.md)

Records what a real input method sends to a Flutter text field: every value (text, the part still being composed, selection), keys, focus changes and clicks. The recordings are test input: `packages/gubasic_runtime/test/text_box_test.dart` replays every file in `test/ime_logs/` (DESIGN §9.1).

Recorded so far: `windows-chrome.json` (Windows Korean input method, Chrome) and `macos-chrome.json` (macOS Korean input method, 2-set, Chrome).

## Recording

Use the pinned Flutter first (`dart tool/check_flutter.dart` in `packages/gubasic_runtime`), then:

```sh
cd packages/gubasic_runtime/tool/ime_probe
flutter pub get
flutter run -d chrome --release
```

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
   - **The exact events this recording made**, pinned in `recorded` at the end of `test/text_box_test.dart`. A new recording fails here with the events it made: check them by hand against what you typed, then add them. Input methods may differ here (on macOS the space goes into the composition, so 닭 is never committed alone); a later failure means a Flutter upgrade changed what that input method does.

   Keep every recording; never edit one by hand.

## What the recordings show

Behaviour seen in the recordings so far, with the scenario that shows it. The Windows recording does not have scenario 5 yet.

- **Backspace while composing is handled inside the input method.** 한 becomes 하 (scenario 3), 값 becomes 갑, 가, ㄱ (5-1), and 긂 becomes 글, 그, ㄱ (5-2): the text being composed shrinks one jamo at a time, nothing is committed, and `Changed` does not run. Windows and macOS.
- **A committed syllable is deleted in one step, and `Changed` runs once.** After the composition is gone, Backspace removes 닭 (5-1) or 한 (5-2) as a whole, never 달 or 하, and `Changed` runs once with the shorter text. macOS.
- **What was only being composed never reaches `Changed`.** 긂 in 5-2 and 값 while it is being erased in 5-1 are never committed, so `Changed` never shows them: in 5-2 it runs only for 한 and for the empty text. macOS.
- **A space goes into the composition on macOS.** After 닭, the space is committed together with it, so `Changed` sees `닭 ` but never `닭` alone (scenario 2); Windows commits `닭` first.
- **Leaving the field commits.** Both input methods commit what is being composed when the field loses the focus; on the web this happens about 150 to 180 ms before a click arrives (scenario 4).
