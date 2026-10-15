# 입력기 기록 페이지

[English](README.md)

실제 입력기가 Flutter 입력 칸에 보내는 것을 기록합니다: 모든 값(글자, 아직 조합 중인 부분, 선택 범위), 키, 포커스 변화, 클릭. 기록은 테스트 입력입니다: `packages/gubasic_runtime/test/text_box_test.dart`가 `test/ime_logs/`의 모든 파일을 재생합니다(DESIGN 9.1절).

지금까지의 기록: `windows-chrome.json`(Windows 한글 입력기, Chrome).

## 기록하는 방법

먼저 고정된 Flutter인지 확인하고(`packages/gubasic_runtime`에서 `dart tool/check_flutter.dart`), 다음을 실행합니다.

```sh
cd packages/gubasic_runtime/tool/ime_probe
flutter pub get
flutter run -d chrome --release
```

1. 시스템 입력기를 한글(두벌식)로 바꿉니다.
2. 페이지의 네 시나리오를 차례로 합니다. 시나리오마다 칠 키가 적혀 있습니다. 잘못 쳤으면 **다시**를 누르고 그 시나리오를 다시 합니다. 테스트는 마지막 "다시" 뒤의 기록을 씁니다. 4번 시나리오는 일부러 "다시"를 한 번 누릅니다(버튼 A, 그다음 버튼 B).
3. 오른쪽 위 **저장 (Save)**을 누릅니다. 맥에서는 `ime-log-macos-chrome.json`, Windows에서는 `ime-log-windows-chrome.json`이 내려받아집니다.
4. `ime-log-` 접두어를 빼고 테스트 폴더에 복사합니다.

   ```sh
   cp ~/Downloads/ime-log-macos-chrome.json ../../test/ime_logs/macos-chrome.json
   ```

5. `packages/gubasic_runtime`에서 `flutter test`를 실행합니다. 새 파일은 자기 테스트 그룹을 따로 받습니다. 테스트가 실패하면 입력기가 다른 신호를 보내는 것입니다. 기록은 그대로 두고, 기대하는 동작(LANGUAGE 11.1절)이 두 기록 모두에서 성립하는 범위에서만 테스트를 고칩니다.
