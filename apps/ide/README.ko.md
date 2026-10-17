# GuBASIC IDE

[English](README.md)

IDE입니다. `examples/`의 예제 프로젝트(`hello`, 그리고 입력기를 시험할 TextBox가 있는 `typing`)와 디스크의 프로젝트를 열고 실행 창에서 실행합니다(docs/DESIGN.ko.md 2.3절). 오른쪽 위 메뉴로 프로젝트를 바꿉니다. macOS, Windows, 웹에서 실행됩니다.

```sh
flutter run -d macos     # 또는 -d windows, -d chrome
flutter build web --no-web-resources-cdn   # CI와 같은 빌드(D30)
```

- **파일**, 왼쪽 위(macOS, Windows; D32):
  - **열기…**(⌘O / Ctrl+O)는 `.gbproj` 파일로 프로젝트를 엽니다.
  - **저장**(⌘S / Ctrl+S)은 프로젝트 저장입니다: `.gbproj`, `.form.yaml`, `.gbas` 가운데 바뀐 파일을 모두 저장합니다.
  - **다른 이름으로 저장…**(⇧⌘S / Ctrl+Shift+S)은 프로젝트 전체를 새 폴더에 복사합니다: 위치와 이름을 정하면 `NAME/NAME.gbproj`와 폼 파일들을 만듭니다. Visual Basic 6처럼 파일마다 묻지 않습니다.
  - 폼의 `.form.yaml`과 `.gbas`는 이름이 같은 한 쌍이라 늘 함께 저장하고 함께 이름이 바뀝니다. 폼 하나만 따로 저장하는 기능은 여러 폼을 다루는 2단계에서 정합니다.
  - 문서·데스크톱·다운로드 폴더의 프로젝트를 처음 열 때 macOS가 GuBASIC IDE의 그 폴더 접근을 허용할지 묻습니다. 허용해야 폼 파일을 읽을 수 있습니다(D32).
  - 예제는 읽기 전용이라 저장하면 복사본이 저장됩니다. 프로젝트 이름 뒤의 "— 편집됨"은 저장하지 않은 변경이 있다는 뜻입니다.
- **웹에서는**(D33) 파일 메뉴가 프로젝트를 이 브라우저에 보관합니다(열기…에 목록이 나오고, 변경은 자동으로 보관됨). **.zip으로 내려받기**(⇧⌘E / Ctrl+Shift+E, 위쪽 막대의 버튼도 같음)와 **.zip 올리기…**가 더 있습니다. 브라우저 저장소는 지워질 수 있으니 수업이 끝날 때마다 .zip으로 내려받습니다. 내려받지 않은 변경이 있는 동안에는 버튼이 눈에 띄게 바뀝니다. .zip을 풀면 데스크톱 IDE가 여는 폴더가 됩니다.
- **F5**는 프로젝트를 실행하고, **Shift+F5**는 중지합니다. 화면의 말은 시스템 언어(영어 또는 한국어)를 따릅니다.
- 예제 프로젝트는 앱 안에 들어 있으므로(`lib/src/project/examples.g.dart`) 웹 빌드에 파일이 필요 없습니다. `examples/`를 바꾼 뒤에는 `dart run tool/embed_examples.dart`를 실행합니다. CI가 `--check`로 확인합니다.
- `test/widget_parity_test.dart`는 `test/parity/`의 이벤트 스크립트를 모두 실제 실행 창에서 실행합니다(DESIGN 9.1절).
- **글꼴:** IDE는 모든 플랫폼에서 Noto Sans KR을 씁니다(D30). 출처는 [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR)(버전 2.004, `NotoSansKR-Regular.otf`, `NotoSansKR-Bold.otf`)이고, SIL Open Font License 1.1을 따릅니다: [`fonts/OFL.txt`](fonts/OFL.txt).
- 웹 빌드는 엔진과 글꼴을 직접 내보내고(`--no-web-resources-cdn`), 앱의 첫 화면이 나올 때까지 "불러오는 중…"(영어로는 "Loading…")을 보여 줍니다(`web/index.html`).
