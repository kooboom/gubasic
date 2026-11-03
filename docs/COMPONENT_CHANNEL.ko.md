# 컴포넌트 통로

> 끝의 질문 세 개는 권장안대로 답을 받았습니다(DESIGN D123). 첫 컴포넌트 `Http`(D125)와 `Database`(D126)가 v0.5에서 이 통로로 들어왔고, 나머지는 설계입니다.

[English](COMPONENT_CHANNEL.md)

GuBASIC 바깥의 기능, 곧 Dart·Flutter 패키지를 GuBASIC 컴포넌트로 받아들이는 방법입니다(DESIGN D121 c).

## 왜

Visual Basic은 `Declare`로 Windows 라이브러리의 어떤 함수든 부를 수 있게 했습니다([Microsoft](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/statements/declare-statement)). VB 프로그램이 VB 자신이 못 하는 일을 할 수 있었던 길이었고, 동시에 프로그램이 깨지던 곳이기도 했습니다. 선언은 손으로 썼고, 형식이 하나 틀리면 프로그램이 죽었고, Windows 밖에는 같은 라이브러리가 없었습니다. GuBASIC은 앞의 것만 갖고 뒤의 것은 없애려 합니다. 형식이 있고, GuBASIC이 도는 모든 플랫폼에서 되는 공식 통로 하나입니다.

## 지금 있는 것

- 모든 컨트롤은 `components/NAME/component.yaml`로 설명되는 컴포넌트입니다(하드 규칙 7). 속성, 메서드, 이벤트가 적혀 있고, 분석기와 IDE의 도구 상자, 속성 창이 이것을 읽습니다.
- 컨트롤이 하는 일은 Dart로 두 곳에 씁니다. 인터프리터(`gubasic_lang`)와 위젯(`gubasic_runtime`)입니다. `File`, `Csv`, `PdfDocument` 같은 화면 없는 객체는 언어에 들어 있습니다.
- **통로의 첫 컴포넌트 `Http`(v0.5, D125):** `components/Http/component.yaml`은 `object: true`, 곧 이름으로 쓰는 내장 객체라고 말하고 `platforms`를 적습니다. 인터프리터는 호스트에 인스턴스를 달라고 하고(`ComponentHost.createComponent`) `ComponentInstance`로 이야기합니다: `getProperty`, `setProperty`, `call`, `assign`, 양쪽 다 GuBASIC의 값, 그리고 잘못된 것은 R 코드가 든 `ComponentProblem`. 컴포넌트 자체의 코드(`HttpComponent`)는 `gubasic_lang`의 순수 Dart이고, 보내는 일은 프로그램이 도는 곳의 하위 클래스가 합니다: 플레이어는 package:http로, 테스트는 미리 적은 답으로. 인터페이스는 아직 공개하지 않았습니다(질문 3).
- **두 번째 `Database`(v0.5, D126):** 같은 통로로 package:sqlite3 위에서, 패키지를 감싼 첫 컴포넌트. `component.yaml`은 SQL 뒤의 값을 `ParamArray values As Value`로 적고, 런타임의 `GbSqlite`가 패키지를 품으며(데스크톱은 빌드 훅이 만든 라이브러리, 웹은 쓸 때만 불러오는 WebAssembly), 플랫폼과 무관한 부분 `DatabaseComponent`는 `gubasic_lang`의 순수 Dart.
- **이벤트가 있는 첫 컴포넌트 `WebSocket`(v0.6, D136):** 객체가 아니라 디자이너 트레이의 컨트롤(component.yaml의 `channel: true`). 컨트롤마다 인스턴스가 하나씩 있고(`ComponentHost.createComponent(name, name: control)`), 프로그램은 그 읽기 전용 속성과 메서드를 쓰며, 인스턴스는 `ComponentWithEvents.onEvent`로 이벤트를 알림. 인터프리터는 이벤트를 차례로 실행하고 폼과 함께 인스턴스를 닫음. 런타임의 `GbWebSocket`이 package:web_socket_channel을 품음.
- 내보낸 앱은 미리 만든 플레이어에 프로젝트를 넣은 것입니다(D80). 플레이어에는 컴파일해 넣은 Dart 코드만 들어 있습니다.

## 설계

패키지를 감싸는 컴포넌트는 한 폴더에 세 가지로 이루어집니다.

1. **`component.yaml`**: 지금과 같고, 필요한 패키지(`package: sqlite3: ^2.0.0`)와 도는 플랫폼(`platforms: [web, macos, windows]`)이 더해집니다.
2. **Dart로 쓴 어댑터**: 작은 인터페이스 하나를 구현합니다. 인터프리터와 나중의 트랜스파일 코드가 같은 인터페이스를 씁니다. 인스턴스 만들기, 속성 읽고 쓰기, 메서드 부르기, 콜백으로 이벤트 알리기입니다. 어댑터는 GuBASIC의 값(Integer, Double, String, Boolean, Date, Table 등)을 패키지의 형식으로 바꾸고 되돌립니다. 그래서 형식이 틀리면 실행 중이 아니라 `component.yaml`을 읽은 분석기가 먼저 잡습니다.
3. **문서와 예제**: 참조 문서의 그 컴포넌트 쪽, 그리고 `llms.txt`의 줄(D121 d).

분석기, 도구 상자, IDE는 이것을 기본 컨트롤과 똑같이 다루고, 프로그램도 차이를 알 수 없습니다.

## 제약: 미리 만든 플레이어에는 컴파일해 넣은 것만 있음

인터프리터는 실행 중에 Dart 패키지를 불러올 수 없고, 미리 만든 플레이어도 마찬가지입니다. 그래서 컴포넌트는 세 길 가운데 하나로 앱에 닿습니다.

| 길 | 방법 | 언제 |
|---|---|---|
| **기본으로** | GuBASIC이 통로를 거쳐 컴포넌트를 직접 담습니다. IDE와 플레이어에 컴파일해 넣습니다 | 많은 프로그램이 쓰는 것: `Http`, `Database`(SQLite), `WebSocket`, `Room`, 게임 도구. 통로의 첫 사용자가 GuBASIC 자신의 컴포넌트가 되어 통로가 먼저 시험됩니다 |
| **프로젝트를 위해 빌드해서** | GuBASIC이 담지 않은 패키지를 프로젝트가 고르고, 빌드가 그것을 컴파일해 넣습니다. 트랜스파일러의 네이티브 빌드(D79, D95)나, 그 컴포넌트를 넣어 CI가 만든 플레이어입니다 | 한 프로젝트만 쓰는 패키지. 트랜스파일러와 함께 옵니다 |
| **웹에서 나중에 불러서** | 큰 기본 컴포넌트를 지연 라이브러리로 컴파일해, 그것을 쓰는 프로그램만 불러옵니다([Dart](https://dart.dev/language/libraries#lazily-loading-a-library)) | PDF 글꼴을 쓰지 않는 앱에 넣지 않는 것처럼(D117) 웹 플레이어를 작게 둡니다 |

## 그래서 권하는 단계

1. **v0.5:** `Http`(완료, D125)와 `Database`(완료, D126)를 기본 객체로 더 넣지 말고, 어댑터 인터페이스를 거치는 컴포넌트로 씁니다. 그러면 인터페이스가 GuBASIC 자신의 컴포넌트로 먼저 검증됩니다.
2. **v0.6:** `WebSocket`과 `Room`도 같은 방식으로. 이벤트가 있는 첫 컴포넌트: 인스턴스가 콜백으로 이벤트를 알리고, 인터프리터는 Timer 틱처럼 그 핸들러를 차례로 실행함(D136).
3. **트랜스파일러와 함께:** "프로젝트를 위해 빌드해서" 길과, "패키지를 GuBASIC 컴포넌트로 감싸는 법" 안내.
4. **UserControl**(IDEAS)은 나머지 반쪽입니다. 이쪽이 Dart로 만든 컴포넌트라면, 그쪽은 GuBASIC 컨트롤과 코드로 만든 컴포넌트입니다. 둘 다 같은 도구 상자에 들어갑니다.

## 함께 오는 규칙

- 키나 비밀이 필요한 컴포넌트는 경고하고, 그것을 앱에 넣지 않습니다(하드 규칙 12).
- 컴포넌트는 자기 플랫폼을 적고, 지원하지 않는 플랫폼에서 쓰면 분석기가 내보내기 전에 알려 줍니다.
- 패키지의 라이선스는 오픈소스 라이선스에 들어갑니다(D120).

## 작성자에게 물을 것(권장안대로 답함, D123)

1. v0.5의 `Http`와 `Database`를 통로의 첫 컴포넌트로 할까요(권장), 아니면 먼저 기본으로 넣고 나중에 옮길까요?
2. 트랜스파일러 전에 "프로젝트를 위해 빌드해서" 길로 CI가 한 프로젝트를 위한 플레이어를 만드는 것이 값어치가 있을까요(GitHub 계정과 기다림이 필요함), 아니면 트랜스파일러를 기다릴까요(권장)?
3. 어댑터 인터페이스를 처음부터 공개해서 다른 사람도 컴포넌트를 쓰게 할까요, 아니면 "프로젝트를 위해 빌드해서" 길이 생긴 뒤에 공개할까요(권장: 그때)?
