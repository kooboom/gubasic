# GuBASIC

**Flutter™로 만든 비주얼 베이직 스타일의 RAD 도구.**
화면을 그리고, 컨트롤을 더블클릭하고, BASIC 몇 줄을 쓰면 macOS, Windows, iOS, Android, 웹으로 출시할 수 있습니다.

[English](README.md)

> **상태: 1단계 완료**(v0.1.0, 개발판). 폼을 그리고, 컨트롤을 더블클릭하고, BASIC을 쓰고, F5를 누르는 일이 모두 IDE 안에서 되며, Flutter를 설치하지 않아도 됩니다. 내 앱을 플랫폼마다 빌드하는 것(트랜스파일러)은 [2단계](docs/ROADMAP.ko.md)입니다.
>
> - **웹 IDE:** https://kooboom.github.io/gubasic/ide/ (macOS·Windows 앱도 있음: [apps/ide](apps/ide))
> - **놀이터:** https://kooboom.github.io/gubasic (개발용으로 언어만 따로 실행)
>
> **지금 할 수 있는 것**
> - `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`, `Image`로 폼을 그리고, 속성 창에서 속성을 정하고, `Anchor`와 폰·태블릿·데스크톱 크기를 씁니다.
> - 컨트롤을 더블클릭해 이벤트 처리기를 씁니다. 코드 편집기가 코드에 색을 입히고, 이름을 완성하고, 블록을 닫아 줍니다.
> - F5를 눌러 IDE 안에서 앱을 실행합니다. 오류는 한국어나 영어로 설명하고, 누르면 그 줄로 갑니다.
> - 프로젝트를 브라우저에 보관하거나 macOS·Windows에서 폴더로 저장하고, `.zip`으로 내려받습니다. 예제 hello, quiz, typing에서 시작할 수 있습니다.
>
> **알려진 한계:** 아직 내 앱을 빌드할 수 없고(2단계), 프로젝트에는 폼이 하나뿐이며, macOS·Windows 앱은 서명하지 않은 개발판이고, Windows 앱은 CI 빌드와 위젯 테스트로만 확인했습니다. 전체 목록: [docs/KNOWN_ISSUES.ko.md](docs/KNOWN_ISSUES.ko.md).

---

## 왜 만드나

옛 비주얼 베이직에는 아직 무엇도 제대로 대체하지 못한 작업 흐름이 있었습니다.

1. 폼 위에 버튼을 끌어다 놓는다.
2. 속성 창에서 캡션을 바꾼다.
3. 버튼을 더블클릭한다.
4. `Command1_Click` 안에 `Label1.Caption = "안녕"`이라고 쓴다.
5. F5를 누른다.

요즘 크로스플랫폼 도구들은 훨씬 강력하지만, 이 *그리기 → 더블클릭 → 코드 작성 → 실행* 흐름은 사라졌습니다. GuBASIC은 그 흐름을 맥에서 먼저 되살리고, 내부적으로 Flutter를 써서 같은 프로젝트를 주요 플랫폼 모두에 출시할 수 있게 합니다.

GuBASIC은 일부러 즐기려고 만드는 프로젝트이기도 합니다. 무언가를 만드는 도구를 만드는 재미를 위해, 한 사람이 언어와 인터프리터와 트랜스파일러와 IDE를 직접 만듭니다.

## 동작 방식 (그림 한 장)

```
 ┌──────────────────────── GuBASIC IDE (Flutter 데스크톱 앱) ────────────────────────┐
 │  폼 디자이너  →  form.yaml            코드 편집기  →  .gbas (BASIC)               │
 │                       │                                  │                        │
 │                       └───────────────┬──────────────────┘                        │
 │                                파서 → AST                                         │
 │                       ┌───────────────┴──────────────────┐                        │
 │               인터프리터 (F5)                     트랜스파일러 (빌드)             │
 │            IDE 안에서 즉시 실행                Flutter 프로젝트 생성              │
 │                                               → macOS / Windows / iOS /          │
 │                                                 Android / 웹                      │
 └───────────────────────────────────────────────────────────────────────────────────┘
```

- **개발하는 동안**은 F5를 누르면 인터프리터가 IDE 안에서 앱을 바로 실행합니다. Flutter를 설치할 필요가 없습니다.
- **출시할 때**는 트랜스파일러가 BASIC을 Dart로 바꾸고, Flutter로 네이티브 앱을 빌드합니다.

## 언어 맛보기

```vb
Dim clickCount As Integer

Sub Form_Load()
    lblMessage.Caption = "버튼을 눌러 보세요"
End Sub

Sub btnHello_Click()
    clickCount = clickCount + 1
    Dim name = InputBox("이름이 무엇인가요?")
    MsgBox("안녕하세요, " & name & "님! (" & clickCount & ")")
End Sub
```

`await`도, 위젯도, build context도 없습니다. 예전처럼 이벤트와 코드만 있습니다. 같은 프로그램을 폼과 함께 [examples/hello](examples/hello)에 넣어 두었습니다.

## 문서

| 문서 | 내용 |
|---|---|
| [docs/DESIGN.ko.md](docs/DESIGN.ko.md) | 구조와 모든 설계 결정, 그리고 그 이유 |
| [docs/LANGUAGE.ko.md](docs/LANGUAGE.ko.md) | GuBASIC 언어 명세 초안 |
| [docs/ROADMAP.ko.md](docs/ROADMAP.ko.md) | 단계와 목표, 1.0에서 *하지 않을* 것 |
| [docs/KNOWN_ISSUES.ko.md](docs/KNOWN_ISSUES.ko.md) | 지금은 일부러 고치지 않은 문제와 다시 볼 시점 |
| [CLAUDE.md](CLAUDE.md) | 이 저장소에서 일하는 AI 코딩 도구의 규칙 (영문) |

## 플랫폼

| | 개발 환경 | 출시 대상 |
|---|---|---|
| macOS | ✅ (주력) | ✅ |
| Windows | ✅ | ✅ |
| iOS | — | ✅ (맥, Xcode, 애플 개발자 계정 필요) |
| Android | — | ✅ |
| 웹 | — | ✅ |

## GuBASIC을 만드는 방식

GuBASIC은 **Jungmo Gu**가 설계하고 이끕니다. 문서와 코드 초안 작성에는 AI 코딩 도구(Claude)의 도움을 받으며, 모든 변경은 직접 검토합니다. AI가 참여한 커밋에는 `Co-Authored-By` 줄이 붙어 있어서, 어디에 AI가 관여했는지 기록으로 남습니다.

AI와 함께 언어와 IDE를 만드는 과정 자체가 이 프로젝트의 재미이자 기록입니다.

## 라이선스

MIT — [LICENSE](LICENSE)를 보세요. © 2026 Jungmo Gu

## 상표와 관계 고지

GuBASIC은 독립적인 개인 프로젝트입니다. **마이크로소프트나 구글과 제휴하거나, 그들의 보증·후원을 받는 프로젝트가 아닙니다.**

- Visual Basic은 Microsoft Corporation의 상표입니다. "비주얼 베이직 스타일"은 GuBASIC이 영감을 받은 프로그래밍 방식을 설명하는 표현입니다.
- Flutter와 관련 로고는 Google LLC의 상표입니다. GuBASIC은 Flutter SDK로 만들어집니다.
