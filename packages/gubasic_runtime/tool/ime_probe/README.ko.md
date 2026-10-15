# 입력기 기록 페이지

[English](README.md)

실제 입력기가 Flutter 입력 칸에 보내는 것을 기록합니다: 모든 값(글자, 아직 조합 중인 부분, 선택 범위), 키, 포커스 변화, 클릭. 기록은 테스트 입력입니다: `packages/gubasic_runtime/test/text_box_test.dart`가 `test/ime_logs/`의 모든 파일을 재생합니다(DESIGN 9.1절).

지금까지의 기록: `windows-chrome.json`(Windows 한글 입력기, Chrome), `macos-chrome.json`(macOS 한글 입력기 두벌식, Chrome).

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

5. `packages/gubasic_runtime`에서 `flutter test`를 실행합니다. 새 파일은 자기 테스트 그룹을 따로 받고, 두 층으로 검사합니다.
   - **LANGUAGE 11.1절의 규칙**은 모든 기록에 똑같이 적용합니다. `Text`에는 확정된 글자만 있고, `Changed`는 확정될 때마다 한 번 실행되며, 치는 중인 음절은 나오지 않고, 마지막 `Text`가 같아야 합니다. 이 중 하나가 실패하면 런타임이 이 입력기에서 약속을 지키지 못하는 것입니다. 테스트가 아니라 런타임을 고칩니다.
   - **이 기록이 만든 이벤트 순서 그대로**는 `test/text_box_test.dart` 끝의 `recorded`에 고정합니다. 새 기록은 여기서 자기가 만든 이벤트를 보여 주며 실패합니다. 직접 친 내용과 맞는지 눈으로 확인한 다음 추가합니다. 이 층은 입력기마다 다를 수 있습니다(macOS는 스페이스를 조합 안에 넣으므로 닭만 따로 확정되지 않습니다). 나중에 여기서 실패하면 Flutter를 올리면서 그 입력기의 동작이 바뀐 것입니다.

   기록은 모두 남겨 두고, 손으로 고치지 않습니다.
