# IME probe

[한국어](README.ko.md)

Records what a real input method sends to a Flutter text field: every value (text, the part still being composed, selection), keys, focus changes and clicks. The recordings are test input: `packages/gubasic_runtime/test/text_box_test.dart` replays every file in `test/ime_logs/` (DESIGN §9.1).

Recorded so far: `windows-chrome.json` (Windows Korean input method, Chrome).

## Recording

Use the pinned Flutter first (`dart tool/check_flutter.dart` in `packages/gubasic_runtime`), then:

```sh
cd packages/gubasic_runtime/tool/ime_probe
flutter pub get
flutter run -d chrome --release
```

1. Switch the system input method to Korean (2-set, 두벌식).
2. Do the four scenarios on the page in order. The page is in Korean; each scenario says which keys to type. If you make a mistake, press **다시** (again) and repeat that scenario: the tests use what comes after the last 다시. Scenario 4 asks for 다시 once on purpose (button A, then button B).
3. Press **저장 (Save)** at the top right. The browser downloads `ime-log-macos-chrome.json` on a Mac, `ime-log-windows-chrome.json` on Windows.
4. Copy it into the tests without the `ime-log-` prefix:

   ```sh
   cp ~/Downloads/ime-log-macos-chrome.json ../../test/ime_logs/macos-chrome.json
   ```

5. Run `flutter test` in `packages/gubasic_runtime`. The new file gets its own test group. If a test fails, the input method sends different signals: keep the recording, and change the test only where the expected behaviour (LANGUAGE §11.1) still holds for both recordings.
