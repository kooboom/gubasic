# GuBASIC IDE

[English](README.md)

IDE입니다. `examples/`의 예제 프로젝트(`hello`, 그리고 입력기를 시험할 TextBox가 있는 `typing`)와 디스크의 프로젝트를 열고 실행 창에서 실행합니다(docs/DESIGN.ko.md 2.3절). 오른쪽 위 메뉴로 프로젝트를 바꿉니다. macOS, Windows, 웹에서 실행됩니다.

```sh
flutter run -d macos     # 또는 -d windows, -d chrome
flutter build web --no-web-resources-cdn   # CI와 같은 빌드(D30)
dart run tool/web_load_sizes.dart          # "불러오는 중… 37%"에 쓰는 크기(D43)
```

- **파일**, 왼쪽 위(macOS, Windows; D32):
  - **열기…**(⌘O / Ctrl+O)는 `.gbproj` 파일로 프로젝트를 엽니다.
  - **저장**(⌘S / Ctrl+S)은 프로젝트 저장입니다: `.gbproj`, `.form.yaml`, `.gbas` 가운데 바뀐 파일을 모두 저장합니다.
  - **다른 이름으로 저장…**(⇧⌘S / Ctrl+Shift+S)은 프로젝트 전체를 새 폴더에 복사합니다: 위치와 이름을 정하면 `NAME/NAME.gbproj`와 폼 파일들을 만듭니다. Visual Basic 6처럼 파일마다 묻지 않습니다.
  - 폼의 `.form.yaml`과 `.gbas`는 이름이 같은 한 쌍이라 늘 함께 저장하고 함께 이름이 바뀝니다. 폼 하나만 따로 저장하는 기능은 여러 폼을 다루는 2단계에서 정합니다.
  - 문서·데스크톱·다운로드 폴더의 프로젝트를 처음 열 때 macOS가 GuBASIC IDE의 그 폴더 접근을 허용할지 묻습니다. 허용해야 폼 파일을 읽을 수 있습니다(D32).
  - 예제는 덮어쓰지 않습니다. 고칠 수는 있고, 저장하면 복사본이 저장됩니다. 프로젝트 이름 뒤의 "— 편집됨"은 저장하지 않은 변경이 있다는 뜻입니다.
- **웹에서는**([kooboom.github.io/gubasic/ide](https://kooboom.github.io/gubasic/ide/), 놀이터 옆, E1e. 파일 → 놀이터 열기로 갈 수 있음)(D33) 파일 메뉴가 프로젝트를 이 브라우저에 보관합니다(열기…에 목록이 나오고, 변경은 자동으로 보관됨). **.zip으로 내려받기**(⇧⌘E / Ctrl+Shift+E, 위쪽 막대의 버튼도 같음)와 **.zip 올리기…**가 더 있습니다. 브라우저 저장소는 지워질 수 있으니 수업이 끝날 때마다 .zip으로 내려받습니다. 내려받지 않은 변경이 있는 동안에는 버튼이 눈에 띄게 바뀝니다. .zip을 풀면 데스크톱 IDE가 여는 폴더가 됩니다.
- **폼 디자이너**(D34): 파일 목록에서 `Form1.form.yaml`을 고릅니다. 도구상자에서 Button, Label, TextBox, CheckBox, ListBox 가운데 하나를 고르고 폼 위에서 어느 방향으로든 끌면 그 크기로 그려집니다(클릭하면 기본 크기). 도구상자 항목을 더블클릭하면 폼 가운데에 놓입니다. 컨트롤을 클릭하면 선택되고, 끌면 옮겨지며, 손잡이를 끌면 크기가 바뀝니다. 폼의 오른쪽과 아래 변의 손잡이로 폼 크기를 바꿉니다. ⌘와 화살표 키(Windows에서는 Ctrl)로 선택한 컨트롤을 옮기고, Shift와 화살표 키로 크기를 바꿉니다. 격자를 켜면 8픽셀, 끄면 1픽셀씩입니다. Delete나 Backspace로 지웁니다. ⌘Z / ⇧⌘Z(Ctrl+Z / Ctrl+Y)로 되돌리기와 다시 하기를 하고, Esc를 누르면 포인터로 돌아갑니다. **격자**는 8픽셀 격자를 켜고 끄며, **폼 파일 보기**는 파일의 글자를 보여 줍니다. 오른쪽 **속성** 창은 맨 위 목록에서 폼이나 컨트롤을 고르고, 속성을 바꿉니다. 글자는 치는 대로, 숫자는 Enter를 누르거나 칸에서 나갈 때 바뀝니다. 올바르지 않은 값은 이유를 알려 줍니다. 컨트롤 이름을 바꾸면 폼의 코드에서도 함께 바뀌고, 칸이 어느 줄인지 알려 줍니다(D39). 칸 안에서는 키가 글자를 고치고(⌘Z / Ctrl+Z는 글자 되돌리기), 폼을 클릭하면 디자이너의 키를 다시 쓸 수 있습니다. 프로그램이 실행되는 동안에는 폼을 고칠 수 없습니다.
- **F5**는 프로젝트를 실행하고, **Shift+F5**는 중지합니다. 화면의 말은 시스템 언어(영어 또는 한국어)를 따릅니다.
- 예제 프로젝트는 앱 안에 들어 있으므로(`lib/src/project/examples.g.dart`) 웹 빌드에 파일이 필요 없습니다. `examples/`를 바꾼 뒤에는 `dart run tool/embed_examples.dart`를 실행합니다. CI가 `--check`로 확인합니다.
- `test/widget_parity_test.dart`는 `test/parity/`의 이벤트 스크립트를 모두 실제 실행 창에서 실행합니다(DESIGN 9.1절).
- **처리기**(D38): 디자이너에서 컨트롤(또는 빈 폼)을 더블클릭하면 기본 이벤트의 처리기가 코드 편집기에 열리고, 없으면 만들어집니다. 코드 위의 개체·이벤트 목록으로 어느 처리기로든 가거나 처리기를 만들 수 있습니다.
- **디자이너**(D41, D42): Label은 다른 컨트롤 아래에 그려집니다. Tab / Shift+Tab으로 컨트롤을 고르고, Option+클릭(Alt+클릭)으로 아래에 깔린 컨트롤을 고릅니다. ⌘J / ⌘K(Ctrl+J / Ctrl+K)로 맨 앞이나 맨 뒤로 보냅니다. 오른쪽 클릭으로 디자이너 메뉴를 엽니다.
- **오류**(D40): 출력 창에서 줄 번호가 있는 오류를 클릭하면 코드의 그 줄로 갑니다. 실행이 오류로 멈춘 줄은 코드가 바뀔 때까지 표시됩니다.
- **코드 편집기**(D36): `Form1.gbas`를 고릅니다. 키워드, 문자열, 주석, 컨트롤에 색이 칠해지고, Tab / Shift+Tab으로 들여쓰고 내어쓰며, Enter는 들여쓰기를 이어 가고, ⌘Z / Ctrl+Z로 되돌립니다. 프로젝트는 폼으로 열리고, 코드 글꼴 D2Coding은 코드 편집기를 처음 열 때 받습니다.
- **코드 글꼴:** D2Coding 1.3.2 Regular. 출처는 [naver/d2codingfont](https://github.com/naver/d2codingfont/releases/tag/VER1.3.2)(`D2Coding-Ver1.3.2-20180524.ttf`, sha256 `8b1b23e5…711aba84`)이고, SIL Open Font License 1.1을 따릅니다: [`fonts/d2coding/OFL.txt`](fonts/d2coding/OFL.txt). 선언된 글꼴이 아니라 처음 쓸 때 불러오는 에셋입니다(D36).
- **글꼴:** IDE는 모든 플랫폼에서 Noto Sans KR을 씁니다(D30). 출처는 [notofonts/noto-cjk](https://github.com/notofonts/noto-cjk/tree/165c01b46ea533872e002e0785ff17e44f6d97d8/Sans/SubsetOTF/KR)(버전 2.004, `NotoSansKR-Regular.otf`, `NotoSansKR-Bold.otf`)이고, SIL Open Font License 1.1을 따릅니다: [`fonts/OFL.txt`](fonts/OFL.txt).
- 웹 빌드는 엔진과 글꼴을 직접 내보내고(`--no-web-resources-cdn`), 앱의 첫 화면이 나올 때까지 "불러오는 중…"(영어로는 "Loading…")을 보여 줍니다(`web/index.html`).
