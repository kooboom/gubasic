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
