# GuBASIC IDE

[English](README.md)

IDE입니다. 지금은 `examples/`의 예제 프로젝트(`hello`, 그리고 입력기를 시험할 TextBox가 있는 `typing`)를 열고 실행 창에서 실행합니다(docs/DESIGN.ko.md 2.3절). 오른쪽 위 메뉴로 프로젝트를 바꿉니다. macOS, Windows, 웹에서 실행됩니다.

```sh
flutter run -d macos     # 또는 -d windows, -d chrome
flutter build web --no-web-resources-cdn   # CI와 같은 빌드(D30)
```

- **F5**는 프로젝트를 실행하고, **Shift+F5**는 중지합니다. 화면의 말은 시스템 언어(영어 또는 한국어)를 따릅니다.
- 예제 프로젝트는 앱 안에 들어 있으므로(`lib/src/project/examples.g.dart`) 웹 빌드에 파일이 필요 없습니다. `examples/`를 바꾼 뒤에는 `dart run tool/embed_examples.dart`를 실행합니다. CI가 `--check`로 확인합니다.
- `test/widget_parity_test.dart`는 `test/parity/`의 이벤트 스크립트를 모두 실제 실행 창에서 실행합니다(DESIGN 9.1절).
- **글꼴:** IDE는 모든 플랫폼에서 Noto Sans KR을 씁니다(D30). 출처는 [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR)(버전 2.004, `NotoSansKR-Regular.otf`, `NotoSansKR-Bold.otf`)이고, SIL Open Font License 1.1을 따릅니다: [`fonts/OFL.txt`](fonts/OFL.txt).
- 웹 빌드는 엔진과 글꼴을 직접 내보내고(`--no-web-resources-cdn`), 앱의 첫 화면이 나올 때까지 "불러오는 중…"(영어로는 "Loading…")을 보여 줍니다(`web/index.html`).
