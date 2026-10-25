# GuBASIC 설계

[English](DESIGN.md)

이 문서는 GuBASIC의 구조와 지금까지 내린 모든 결정을 **각 결정의 이유와 함께** 기록합니다. 결정이 바뀌면 이 문서부터 고칩니다.

---

## 1. 목표

**GuBASIC은 VB.NET의 문법 위에 VB6의 작업 감각을 얹고, 둘의 불편한 부분은 덜어 낸 BASIC이다.**
둘이 다를 때는, 헷갈리거나 위험한 부분은 VB.NET의 정리된 방식을, 손에 익은 편리함은 VB6에서 가져온다.

중요한 순서대로입니다.

1. **이벤트 드리븐 프로그래밍.** 코드는 컨트롤에 붙은 이벤트 처리기 안에 들어갑니다.
2. **그리는 UI.** 화면은 코드로 쓰지 않고 캔버스에 그립니다.
3. **BASIC 언어.** VB.NET을 단순화한 BASIC입니다.
4. **개발 환경은 macOS가 1순위, Windows가 2순위.**
5. **macOS, Windows, iOS, Android로 출시** (웹은 덤).

### 대상

GuBASIC은 우선 만든 사람 자신이 즐기려고 만들지만, **초보자도 쓸 수 있어야 합니다.** 기능과 단순함이 부딪치면, 강한 이유가 없는 한 단순함을 택합니다.

---

## 2. 구조

### 2.1 언어의 두 층

| 층 | 언어 | 이유 |
|---|---|---|
| IDE 자체 | **Dart / Flutter** | 코드 하나로 맥과 윈도우 데스크톱 앱이 나오고, 출력되는 앱도 Flutter라서 프로젝트 전체가 한 생태계 안에 있습니다. |
| 사용자가 쓰는 언어 | **GuBASIC** (BASIC) | 이 프로젝트의 정체성입니다. Dart를 쓰는 Flutter 비주얼 빌더는 이미 여럿 있지만, Flutter 위의 비주얼 베이직 스타일 도구는 없습니다. |

IDE를 C로 만드는 방안도 검토했지만 제외했습니다. C로 GUI를 만드는 수고에 비해 얻는 것이 적습니다.

### 2.2 같은 코드를 실행하는 두 가지 방식

```
소스 (.gbas) + 폼 (.form.yaml)
            │
     렉서 → 파서 → AST → 분석기
            │
     ┌──────┴───────┐
 인터프리터      트랜스파일러
 (F5, IDE 안)    (빌드 → Dart → Flutter → 네이티브 앱)
```

- **인터프리터**: 프로그램을 IDE 안에서 즉시 실행합니다. "F5를 누르면 바로 실행되는" 감각을 살리고, 초보자는 Flutter를 설치하지 않고도 앱을 만들고 실행할 수 있습니다.
- **트랜스파일러**: BASIC을 Dart로 변환해 Flutter 프로젝트를 만들고 `flutter build`를 호출합니다. 출시되는 앱은 AOT 컴파일된 네이티브 코드라서, Flutter로 직접 짠 앱과 속도가 같습니다.

두 방식은 렉서, 파서, AST, 분석기를 공유합니다. 원조 비주얼 베이직도 IDE에서는 해석 실행하고 출시할 때 컴파일하는 같은 구조였습니다.

**가장 큰 위험**은 두 방식의 동작이 어긋나는 것입니다. §9(동일성 테스트)를 보세요.

### 2.3 런타임 층

생성된 코드와 인터프리터는 Flutter 위젯을 직접 부르지 않습니다. 대신 얇은 패키지 **`gubasic_runtime`**이 제공하는 `GbButton`, `GbLabel`, `GbForm`, `MsgBox` 등을 씁니다.

이유는 이렇습니다.
- Flutter가 바뀌어도 `gubasic_runtime`만 고치면 됩니다.
- 인터프리터와 생성된 앱이 **같은 런타임**으로 화면을 그리므로, 구조적으로 동작이 같아집니다.
- 예전 VB 런타임 DLL과 같은 역할입니다.

GuBASIC의 각 릴리스는 검증한 Flutter 버전에 고정됩니다(D29). Flutter 업그레이드는 업데이트마다 따라가는 일이 아니라, 원할 때 하는 별도 작업입니다. 런타임은 기본적이고 안정적인 Flutter 위젯만 씁니다.

구조는 이렇습니다.
- **`GbFormModel`**은 폼과 컨트롤의 현재 속성(`GbControlState`, 이름과 타입은 `component.yaml`과 같음)을 담습니다. **`GbFormView`**가 이를 보여 줍니다: 각 컨트롤을 `Stack` 안의 `Left`, `Top` 위치에 둡니다(6절). Button은 테두리와 글자 사이를 8픽셀로 둡니다. 그래야 기본 너비의 Button에 자기 이름(`Button1`)이 다 보입니다. Material의 기본값 24로는 96픽셀 가운데 48픽셀만 글자에 남았습니다. 사용자가 한 일은 이벤트로 돌아옵니다: `Click`, 그리고 사용자가 TextBox의 확정된 글자나 CheckBox, ListBox에서 고른 항목을 바꿀 때의 `Changed`.
- **`GbDialogs`**는 `MsgBox`와 `InputBox`를 모달로 보여 주고(D28), 프로그램이 끝나면 모두 닫습니다.
- **`gubasic_runtime`은 `gubasic_lang`에 의존하지 않습니다.** 둘은 IDE가 이어 줍니다(인터프리터의 `FormHost`). 그래서 생성된 앱에는 인터프리터가 들어가지 않습니다.
- **IDE의 실행 창**(`apps/ide`): `RunHost`가 `GbFormModel`과 `GbDialogs` 위에 `FormHost`를 구현합니다. 속성 값은 모델 한 곳에만 있고, 프로그램이 넣고 사용자가 바꿉니다. 클릭과 입력은 이벤트로 인터프리터에 갑니다. 실행 창은 IDE 가운데를 채우고 자기 내비게이터를 가집니다. 그래서 MsgBox나 InputBox는 폼과 폼의 닫기 단추를 가리지만(D28) IDE의 도구 막대는 가리지 않아, 중지(Shift+F5)는 언제나 됩니다. 폼은 `Form_Load`가 끝나면 나타납니다.
  - **대화상자는 프로그램만 막습니다.** MsgBox나 InputBox는 실행 중인 프로그램의 폼만 막습니다. IDE는 계속 쓸 수 있고, 무엇보다 중지 단추가 눌립니다. 대화상자가 IDE까지 막으면 대화상자에서 기다리는 프로그램을 중지할 수 없기 때문입니다.
  - **실행 중에 파일 보기.** 프로그램이 실행되는 동안 파일 목록 맨 위에 "실행 화면" 항목이 생깁니다. 파일을 고르면 그 파일을 보여 주고, 이 항목을 고르면 실행 창이 그대로 돌아옵니다. 열려 있던 대화상자도 답을 기다리는 채로 남아 있습니다. 실행 창은 가려져 있는 동안 다시 만들지 않으므로 대화상자가 사라지지 않습니다.
  - **대화상자가 열린 채 중지하면** 어느 화면을 보고 있든 대화상자가 닫히고 프로그램이 끝납니다.
  - **프로그램이 실행되는 동안 파일은 읽기 전용입니다.** 프로그램은 시작할 때의 코드로 실행됩니다. 코드를 고치려면 먼저 중지합니다. 놀이터는 코드를 고치면 프로그램을 멈추지만(`apps/playground/lib/src/dom/app.dart`의 I5), IDE는 그렇게 하지 않습니다. 파일에서 실수로 누른 키 하나가, 대화상자에서 기다리는 프로그램을 사용자가 원하지 않았는데 끝내 버리기 때문입니다. 코드 편집기(D36)와 폼 디자이너도 이 규칙을 지킵니다.
  - 테스트: `apps/ide/test/ide_shell_test.dart`.
- **디스크의 프로젝트**(D32): macOS와 Windows에서는 IDE 왼쪽 위의 파일 메뉴로 프로젝트의 `.gbproj` 파일을 열고, 바뀐 파일을 저장하고(저장), 프로젝트 전체를 새 폴더에 복사합니다(다른 이름으로 저장…). 내장 예제는 덮어쓰지 않습니다. 예제를 고칠 수는 있고, 저장을 누르면 복사본을 저장합니다. 저장하지 않은 변경이 있으면 프로젝트 이름 뒤에 "— 편집됨"을 붙이고, 변경이 사라지기 전에 묻습니다: 다른 프로젝트를 열 때와 IDE를 끌 때입니다. 프로그램이 실행되는 동안에는 열지도 저장하지도 않습니다. 테스트: `apps/ide/test/folders_test.dart`, `folders_io_test.dart`, `project_menu_test.dart`.
- **브라우저의 프로젝트**(D33): 웹에서는 같은 파일 메뉴가 프로젝트를 브라우저에 보관하고, .zip으로 내려받기와 .zip 올리기…를 더합니다. 위쪽 막대에는 .zip 버튼이 늘 있고, 그 아래 상태 줄이 프로젝트가 어디 있는지 알립니다. 테스트: `apps/ide/test/browser_test.dart`, `project_zip_test.dart`, `web_menu_test.dart`, Chrome에서 도는 `test/web/`.
- **폼 디자이너**(D34): `.form.yaml` 파일을 고르면 실행 화면이 보여 줄 모양 그대로, 같은 runtime 위젯으로 폼을 그립니다(`apps/ide/lib/src/form_window.dart`의 `formModelOf`와 `FormWindowFrame`). 왼쪽에는 도구상자가 있습니다. 테두리가 없는 Label에는 디자이너에서만 점선 테두리를 그려서, 비어 있는 Label도 찾을 수 있습니다. 컨트롤 종류를 고르고 폼 위에서 사각형을 어느 방향으로든 끌면 컨트롤이 그려지고(클릭하거나 몇 픽셀만 끌면 기본 크기로 놓임), 종류를 더블클릭하면 폼 가운데에 놓입니다. 선택한 컨트롤은 끌어서 옮기고 손잡이 8개로 크기를 바꾸며, 폼의 오른쪽과 아래 변의 손잡이로 폼 크기를 바꿉니다. ⌘와 화살표 키(Windows에서는 Ctrl)로 선택한 컨트롤을 옮기고, Shift와 화살표 키로 크기를 바꿉니다. 마우스 커서는 끌면 무엇이 되는지 보여 줍니다. Delete나 Backspace는 선택한 컨트롤을 지우고, 되돌리기와 다시 하기(⌘Z / ⇧⌘Z, Ctrl+Z / Ctrl+Y)는 바뀐 것을 한 단계씩 오갑니다. Esc는 포인터로 돌아가고, 8픽셀 격자는 켜고 끌 수 있습니다. "폼 파일 보기"는 파일의 글자를 보여 줍니다. 오른쪽의 속성 창(D35)은 목록에서 폼이나 컨트롤을 고르고 속성을 바꿉니다. 글자는 치는 대로, 숫자는 Enter를 누르거나 칸에서 나갈 때 바뀝니다. 프로그램이 실행되는 동안과 폼 파일에 오류가 있을 때는 폼을 보여 주기만 합니다. 테스트: `apps/ide/test/designer_test.dart`, `form_edit_test.dart`.
- **런타임은 글꼴을 정하지 않습니다.** 런타임을 감싼 앱이 테마로 정합니다. 그래서 데스크톱과 휴대폰 앱은 계속 운영체제 글꼴을 씁니다. IDE는 자기 글꼴인 Pretendard를 담아 모든 플랫폼에서 씁니다(D30). 폼 위 컨트롤은 크기와 색을 스스로 정하고(`gbFormTheme`, D49), 글꼴만 감싼 앱에서 가져옵니다.
- `packages/gubasic_runtime/example`은 폼을 손으로 그린 예제입니다. CI가 변경마다 웹과 Windows로, PR에서는 macOS로도 빌드합니다.

### 2.4 저장소 구조 (계획)

```
gubasic/
├── apps/
│   ├── ide/                 Flutter IDE (macOS, Windows, 웹)
│   ├── player/              폰용 GuBASIC Player (3단계)
│   └── playground/          개발용 웹 놀이터 (순수 Dart, Flutter 없음)
├── packages/
│   ├── gubasic_lang/        순수 Dart: 렉서, 파서, AST, 분석기,
│   │                        인터프리터, 트랜스파일러. Flutter 의존 없음.
│   └── gubasic_runtime/     런타임 컨트롤과 함수 (Flutter)
├── components/              컴포넌트마다 폴더 하나 (component.yaml + 어댑터)
├── examples/                예제 GuBASIC 프로젝트
├── test/parity/             인터프리터-트랜스파일러 동일성 테스트
└── docs/
```

`gubasic_lang`은 Flutter에 의존하지 않으므로 일반 `dart test`로 빠르게 테스트할 수 있습니다.

---

## 3. 실행 모델

### 3.1 비동기 숨기기

옛 VB에서 `MsgBox`는 사용자가 확인을 누를 때까지 코드를 멈췄습니다. Flutter에서는 대화상자, 파일, 네트워크가 모두 비동기(`await`)입니다. GuBASIC은 **이것을 숨깁니다.**

- **사용자가 만든 모든 `Sub`와 `Function`은 `async`로 컴파일되고, 그 호출에는 모두 `await`가 붙습니다.** 어떤 함수가 비동기가 "되는지" 추적할 필요가 없어집니다. 약간의 성능 손해가 있지만 이 규모에서는 체감되지 않습니다.
- 기다려야 하는 내장 호출(`MsgBox`, `InputBox`, 파일, 데이터베이스, HTTP)에는 자동으로 `await`가 붙습니다.
- 사용자는 VB처럼 위에서 아래로 코드를 씁니다.

그로 인한 문제와 처리 방식입니다.

| 문제 | 처리 |
|---|---|
| 처리기가 아직 기다리는 중에 같은 버튼을 다시 누름 (중복 실행) | **실행 중인 이벤트 처리기는 다시 시작되지 않습니다.** 두 번째 클릭은 무시됩니다. |
| 처리기 두 개가 `await`마다 번갈아 실행되어 서로 하다 만 일을 봄 | **한 번에 처리기 하나만 실행합니다**(D28). 다른 처리기는 실행 중인 처리기가 끝나거나 `DoEvents`에서 기다릴 때 시작합니다. `MsgBox`와 `InputBox`는 모달이라서, 떠 있는 동안의 이벤트는 막힙니다. |
| 긴 `Do While` 루프가 화면을 멈춤 (Flutter의 UI는 스레드 하나) | VB와 똑같이 **`DoEvents`**를 제공합니다. 짧은 양보(`await Future.delayed(Duration.zero)`)로 컴파일되며, 다른 처리기가 실행되게 합니다. |
| 인터프리터가 문장 중간에 멈춰 기다릴 수 있어야 함 | **인터프리터는 처음부터 비동기로 만듭니다.** 나중에 바꾸기 가장 어려운 부분이라 지금 정합니다. |

### 3.2 시작점

- 프로젝트 설정 **시작 개체**: 폼(기본값) 또는 `Sub Main`.
- 대부분의 앱은 시작 폼을 쓰고 `Form_Load`에서 초기화합니다.
- `Sub Main`은 첫 폼을 조건에 따라 정할 때 씁니다 (예: 로그인하지 않았을 때만 로그인 폼 표시).
- 트랜스파일러는 이 설정으로 Dart의 `main()`을 만듭니다.

### 3.3 폼과 화면 이동

`Form2.Show`는 VB 문법을 유지하되 플랫폼에 맞게 동작합니다.

| 플랫폼 | `Form2.Show` |
|---|---|
| macOS / Windows | 새 창을 엽니다 |
| iOS / Android / 웹 | 새 화면으로 전환합니다 |

---

## 4. 이벤트

- **이름 기반 연결 (VB6 방식):** `btnSave_Click`이라는 처리기가 `btnSave`의 `Click` 이벤트를 처리합니다. 컨트롤을 더블클릭하면 처리기 뼈대가 생깁니다.
- **이름을 바꿔도 안전:** 디자이너에서 컨트롤 이름을 바꾸면 IDE가 그 컨트롤의 처리기 이름도 모두 바꿉니다. (VB6에서 유명했던, 처리기 연결이 끊기는 문제를 해결합니다.)
- **`Handles` 절 (2단계, 선택):** 처리기 하나를 여러 컨트롤이 함께 쓸 때 씁니다.

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

- **컨트롤 배열은 만들지 않습니다.** `Handles`와 실행 중 컨트롤 생성이 그 용도를 대신합니다.

---

## 5. 컴포넌트

기본 제공되는 Button, Label, TextBox, CheckBox, ListBox까지 포함해 **모든 컨트롤은 `component.yaml`로 설명되는 컴포넌트**입니다.

```yaml
name: QRScanner
version: 1
package: "mobile_scanner: ^5.0.0"   # 기본 컴포넌트는 생략
visual: true
properties:
  - { name: Enabled, type: Boolean, default: true }
  - { name: Torch,   type: Boolean, default: false }
events:
  - Detected(code As String)
methods:
  - Start()
  - Stop()
permissions:
  android: [CAMERA]
  ios: { NSCameraUsageDescription: "Scan QR codes" }
```

기본 컨트롤까지 처음부터 이 방식으로 만드는 이유: 나중에 GuBASIC을 확장하는 일이 "재설계"가 아니라 "컴포넌트 하나 추가"가 됩니다. 1단계에서 드는 추가 비용은 거의 없습니다.

같은 메타데이터가 도구상자, 속성 창, 자동완성, 트랜스파일러에 모두 쓰입니다. `layer: graphic`(Label)은 컨트롤을 다른 것들 아래에, `layer: control`(기본값)은 그 앞에 그립니다(D41). `otherNames`는 다른 버전의 BASIC에서 쓰는 이름을 GuBASIC에서 이름이 다른 멤버에 잇습니다(`Text: Caption`). "혹시 이것인가요"에 씁니다(A036, D50).

기본 컴포넌트는 `components/`에 있습니다(`Form`, `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`, `Image`. [LANGUAGE.ko.md](LANGUAGE.ko.md) 11.1절). 분석기는 파일을 읽을 수 없는 웹을 포함한 모든 플랫폼에서 이 컴포넌트들의 속성과 이벤트를 알아야 합니다. 그래서 `tool/embed_components.dart`가 `component.yaml`을 `gubasic_lang` 안으로 복사하고, CI가 복사본이 최신인지 확인합니다(D27).

### 5.1 기본 컴포넌트와 추가 컴포넌트

| | 인터프리터 (F5) | 빌드 |
|---|---|---|
| **기본 컴포넌트** (IDE와 Player에 미리 포함) | ✅ 실행됨 | ✅ |
| **추가 컴포넌트** (어댑터로 감싼 pub.dev 패키지) | 디자이너에 자리 표시 상자로 보이고 실행은 안 됨 | ✅ 생성되는 `pubspec.yaml`에 추가 |

이유: Dart는 실행 중에 새 패키지를 불러올 수 없고, Flutter에서는 리플렉션이 막혀 있습니다. Expo Go나 App Inventor Companion이 가진 한계와 같습니다.

### 5.2 비상구

아직 어댑터가 없는 패키지를 쓰고 싶은 고급 사용자는 Dart 코드를 직접 넣을 수 있습니다 (문법은 3단계에서 확정). 이런 코드는 빌드 모드에서만 실행됩니다.

### 5.3 앞으로

Dart의 `analyzer` 패키지로 패키지의 공개 API를 읽어 어댑터를 자동 생성합니다.

---

## 6. 레이아웃

**원칙: 이후 단계는 속성을 추가할 뿐, 기존 속성의 의미를 바꾸지 않습니다.** 그래서 이전 단계의 프로젝트는 변환 없이 그대로 열리고 똑같이 동작합니다.

| 단계 | 추가되는 것 | Flutter 대응 |
|---|---|---|
| 1 | 절대 위치 + `Anchor`(상하좌우 고정), 폼 크기 프리셋(폰 / 태블릿 / 데스크톱) | `Stack` + `Positioned` |
| 2 | 컨테이너의 `LayoutMode`(절대 / 세로 / 가로 / 격자)와 `Dock` | `Column`, `Row`, `Wrap`, 격자 |
| 3 | 화면 크기별 덮어쓰기 (어떤 속성이든 폰 / 태블릿 / 데스크톱 값을 따로 지정) | `LayoutBuilder` |

기본값이 호환성을 보장합니다: `LayoutMode = 절대`, 크기별 덮어쓰기 없음.

모든 프로젝트 파일에는 `formatVersion`이 들어갑니다. 호환이 깨지는 변경이 필요해지면, 변환기가 옛 파일을 자동으로 올려 줍니다.

나중에는 컨트롤의 위아래 순서를 읽어 절대 배치를 세로 쌓기로 바꿔 주는 도우미도 만들 수 있습니다.

---

## 7. 프로젝트 파일

모든 프로젝트 파일은 Git에서 변경 내역을 읽기 쉽도록 **일반 텍스트**입니다 (VB6의 `.frm`처럼). 확장자는 임시입니다.

| 파일 | 형식 | 내용 |
|---|---|---|
| `App.gbproj` | YAML | 프로젝트 설정: 이름, 시작 폼, 폼 목록 (나중에 Flutter 버전과 사용하는 컴포넌트도) |
| `Form1.form.yaml` | YAML | 폼의 속성, 컨트롤과 그 속성 |
| `Form1.gbas` | GuBASIC | `Form1`의 코드 |
| `Module1.gbas` | GuBASIC | 모듈 코드 (전역 변수, 공용 프로시저) |

모든 파일에는 `formatVersion`이 있습니다. 폼 파일과 프로젝트 파일의 형식은 [LANGUAGE.ko.md](LANGUAGE.ko.md) 11.2–11.3절에 있고, [examples/hello](../examples/hello)는 완성된 프로젝트 예입니다.

---

## 8. 편집기

### 8.1 1단계 자동완성

컴포넌트 메타데이터가 미리 선언되어 있어서, 가벼운 자동완성은 비용이 적게 들고 1단계에 들어갑니다.

- 키워드와 블록 완성 (`If` → `End If`)
- 현재 폼의 컨트롤 이름, 변수, 프로시저, 내장 함수
- 점 뒤의 멤버 목록 (`Label1.` → 속성과 메서드. 이벤트는 `Sub Label1_Click`으로 처리합니다, D38)
- **VB 습관과 비슷하지만 다른 문법에 대한 "혹시 이것인가요" 안내.** 예를 들어 VB에는 있지만 GuBASIC에서는 이름이 다른 속성을 썼을 때 알려 줍니다(A035, A036).

무엇을 늘어놓는지는 D50에 적었습니다.

나중에: 지역 변수와 함수 결과의 타입 추론.

### 8.2 오류에 강한 파서

입력 중인 코드는 거의 항상 문법이 깨져 있습니다. **파서는 오류를 만나도 복구해서 계속 읽어야** 구문 강조, 자동완성, 진단이 계속 동작합니다. 이것은 최적화가 아니라 1단계의 필수 조건입니다.

### 8.3 실행 중 오류

처리되지 않은 오류가 나면 프로그램이 멈추고, 편집기에서 해당 줄이 강조되며, 오류가 쉬운 말(영어 또는 한국어)로 설명됩니다. 초보자는 `Try`를 몰라도 쓸모 있는 오류 안내를 받습니다.

### 8.4 메시지

IDE 메시지와 오류 설명은 **영어와 한국어**로 제공됩니다.

---

## 9. 테스트

- `gubasic_lang`은 일반 `dart test`로, `gubasic_runtime`은 `flutter test`로 테스트합니다.
- **실제 입력기로 입력하기.** `packages/gubasic_runtime/tool/ime_probe`는 실제 입력기가 입력 칸에 보내는 것(조합 중인 부분을 포함한 모든 값)을 기록합니다. 기록은 `packages/gubasic_runtime/test/ime_logs/`에 두고 TextBox 테스트가 그대로 재생하므로, 한글 입력을 지어낸 신호가 아니라 실제 신호로 시험합니다. 재생은 두 층으로 검사합니다. LANGUAGE 11.1절의 규칙은 모든 입력기에 똑같이 적용하고, 각 기록이 만든 이벤트는 순서 그대로 고정합니다. 그래서 Flutter를 올리면서 한 입력기의 동작이 바뀌면 알아챕니다. 기록하는 방법: [README](../packages/gubasic_runtime/tool/ime_probe/README.ko.md).
- **동일성 테스트 (처음부터 필수):** `test/parity/`의 예제 프로그램을 인터프리터로 한 번, 변환된 Dart로 한 번 실행해서 기록된 출력이 같아야 합니다. 동일성을 깨는 변경은 병합하지 않습니다.
- 같은 동일성 프로그램을 Chrome(`apps/playground`)에서도 실행해서, 인터프리터가 VM과 웹에서 같은 출력을 내는지 확인합니다.

### 9.1 이벤트 스크립트

폼이 있는 동일성 프로그램(`NAME.gbas` + `NAME.form.yaml`)은 **이벤트 스크립트** `NAME.events`로 움직입니다. 한 줄이 사용자 동작 하나입니다.

```
btnHello.Click        ' 클릭
txtName.Type "Kim"    ' 사용자가 TextBox의 글자를 바꿈. Changed가 실행됨
chkShow.Click         ' CheckBox를 클릭함. Checked가 바뀌고 Changed가 실행됨
lstCity.Select 2      ' 사용자가 ListBox의 2번 항목을 고름. Changed가 실행됨
OK                    ' 열린 MsgBox를 닫음
Answer "Kim"          ' 열린 InputBox에 답함 (Cancel은 "")
Form.Resize 600 400   ' 사용자가 폼을 600 x 400으로 바꿈. Form_Resize가 실행됨 (D57, D58)
Close                 ' 폼을 닫음
```

각 줄은 프로그램이 사용자를 기다릴 때만 실행합니다: 실행 중인 처리기가 없거나, 실행 중인 처리기가 `DoEvents`에서 기다리거나, 대화상자가 열려 있을 때입니다. 그래서 출력이 모든 플랫폼에서 같습니다. `NAME.out`에는 각 줄을 `> 줄`로 적고, 이어서 프로그램이 보여 준 것(`Debug.Print`, `MsgBox`, `InputBox`), 프로그램이 넣은 속성 값(`Set lblMessage.Caption: Hello`), 이벤트가 어떻게 되었는지(`Ignored: …`, `Blocked: …`)를 적습니다. 마지막 줄은 실행이 어떻게 끝났는지입니다: `Closed`, `Ended`, `Stopped`, `Error R0xx @ 줄`. 실행 도구는 `package:gubasic_lang/testing.dart`이며, VM 테스트, Chrome 테스트, IDE의 위젯 테스트(`apps/ide/test/widget_parity_test.dart`)가 함께 씁니다. 위젯 테스트는 각 줄을 실제 실행 창에서 합니다. 단추를 누르고, TextBox에 치고, 대화상자의 단추와 창의 닫기 단추를 누릅니다. 위젯이 열린 대화상자에 가려졌거나 아직 화면에 없으면(`Form_Load` 중) 그 줄은 프로그램에 닿지 않고 `Blocked`가 됩니다. 사용자에게도 그렇기 때문입니다. 그래서 동일성 폼의 컨트롤은 서로 겹치면 안 됩니다.

---

## 10. 데이터

| 기능 | 단계 | 비고 |
|---|---|---|
| `Settings` (키-값; VB의 `SaveSetting` / `GetSetting`) | 1 | `shared_preferences`, 프로젝트마다 글자 하나(D48) |
| `Database` 컴포넌트 (SQLite) | 2 | `sqlite3` 패키지: macOS, Windows, iOS, Android, 웹(WebAssembly). IDE에 포함해 인터프리터에서도 동작 |
| 데이터 바인딩 (VB의 Data 컨트롤) | 1.0 이후 | 1.0에서 제외 |

```vb
Dim db = Database.Open("score.db")
db.Execute("INSERT INTO score(name, point) VALUES(?, ?)", txtName.Text, 90)
For Each row In db.Query("SELECT * FROM score")
    lstScores.AddItem(row("name"))
Next
```

---

## 11. 외부 서비스

### 11.1 앱이 실행 중에 쓰는 서비스

| 기능 | 단계 |
|---|---|
| `Http` (`Get`, `Post`) + JSON — Supabase를 포함해 REST API가 있는 서비스라면 어디든 연결 | 2 |
| `Supabase` 컴포넌트 (URL + 공개 키) | 3 |
| `Firebase` 컴포넌트 (플랫폼별 설정 파일 필요, `component.yaml`을 통해 빌드 때 자동 추가) | 3 |

**보안 원칙:** 앱 안에 들어간 것은 누구나 꺼낼 수 있습니다. 서버 쪽 보안 규칙으로 보호되는 공개 키(예: Supabase anon key)만 씁니다. **비밀 키나 관리자 키로 보이는 값이 프로젝트에 들어가면 IDE가 경고합니다.**

### 11.2 웹 빌드를 올리는 곳

**게시** 메뉴로 `build/web`을 Vercel, Firebase Hosting, GitHub Pages, 개인 서버(SFTP/rsync)에 올립니다. 각 서비스의 명령줄 도구나 GitHub Actions 워크플로로 구현합니다.

---

## 12. 배포와 설치

| 단계 | 사용자에게 필요한 것 | 대상 |
|---|---|---|
| 그리기, 코딩, 실행 | GuBASIC만 | 초보자 |
| 폰에서 테스트 | **GuBASIC Player** 앱 (App Inventor Companion 같은 방식) | 초보자 |
| Android / 웹 / 데스크톱 출시 | 첫 빌드 때 **자동으로 내려받는** Flutter SDK, 또는 **GitHub Actions** 클라우드 빌드 | 중급 |
| iOS / macOS 출시 | 맥, Xcode, 애플 개발자 계정 | 중급 이상 |

iOS/macOS 요구 사항은 GuBASIC이 아니라 애플의 정책에서 옵니다.

---

## 13. 이름

- 제품명 **GuBASIC** (저장소 `gubasic`). "BASIC"은 1964년부터 이어진 언어 계열의 일반 명칭입니다.
- 두 상표 소유자의 가이드라인에 따라 제품명에 "Flutter"나 "Visual Basic"을 넣지 않습니다. 대신 설명하는 표현("비주얼 베이직 스타일", "Flutter로 만든")을 쓰고, README에 비제휴 고지를 둡니다.

---

## 14. 결정 기록

| # | 결정 | 이유 |
|---|---|---|
| D1 | IDE는 Flutter로 작성 | 맥과 윈도우를 코드 하나로; 출력물과 같은 생태계 |
| D2 | 사용자 언어는 BASIC | 프로젝트의 정체성; Flutter 위에 이런 것이 없음 |
| D3 | 인터프리터와 트랜스파일러가 AST 하나를 공유 | 즉시 F5 실행; 네이티브 출시 빌드 |
| D4 | 비동기를 숨김; 사용자 프로시저는 모두 async | VB식 위에서 아래로 쓰는 코드 |
| D5 | 같은 처리기는 다시 시작되지 않음 | 초보자가 가장 헷갈리는 버그 방지 |
| D6 | `DoEvents` 유지 | 긴 루프에 대한 익숙한 해법 |
| D7 | 이름 기반 이벤트 + 자동 이름 변경; `Handles`는 선택 (2단계) | VB6의 단순함은 살리고 이름 변경 문제는 없앰 |
| D8 | `Try…Catch…Finally`만; `On Error` 없음 | 범위가 보임; Dart와 1:1 대응; `GoTo`는 비동기 Dart로 깔끔하게 변환 불가 |
| D9 | 시작 폼(기본) 또는 `Sub Main` | VB6 / VB.NET / Xojo와 같은 모델 |
| D10 | 모든 것이 컴포넌트 (`component.yaml`) | 확장이 "컴포넌트 추가"가 됨 |
| D11 | `gubasic_runtime` 층; Flutter 버전 고정 | Flutter 변화를 한 곳에 가둠 |
| D12 | 레이아웃은 속성을 추가하는 방식으로만 발전 | 옛 프로젝트가 깨지지 않음 |
| D13 | 프로젝트 파일은 일반 텍스트 | Git 변경 내역을 읽을 수 있음 |
| D14 | 1단계부터 가벼운 자동완성; 오류에 강한 파서 | 초보자와 VB 사용자가 GuBASIC과의 차이를 쉽게 익힘 |
| D15 | 동일성 테스트 필수 | 인터프리터와 트랜스파일러의 불일치가 가장 큰 위험 |
| D16 | `Settings` 1단계, `Database` 2단계, 데이터 바인딩은 1.0 이후 | 쓸모 있는 데이터 기능은 일찍, 복잡한 바인딩은 나중에 |
| D17 | `Http` 2단계, Supabase/Firebase 3단계, 게시 메뉴는 웹 출시와 함께 | 범용 통로 먼저, 개별 연동은 나중에 |
| D18 | 언어 세부(타입, 범위, 배열, 연산자) | [LANGUAGE.ko.md](LANGUAGE.ko.md) 참조 |
| D19 | 이름은 GuBASIC; 타사 상표를 이름에 넣지 않음 | 구글과 마이크로소프트의 상표 가이드라인 |
| D20 | 만든 사람을 위한 도구, 초보자도 사용 가능 | 애매하면 단순함을 택함 |
| D21 | 개발용 웹 놀이터(`apps/playground`): Flutter 없이 순수 Dart를 자바스크립트로 컴파일하고, `main`에서 GitHub Pages로 배포 | 언어의 각 단계(토큰, 나중에는 AST와 실행 결과)를 설치 없이 브라우저에서 보여 주고, `gubasic_lang`이 웹에서도 같게 동작하는지 확인함. IDE가 아니라 개발용 도구 |
| D22 | `ByRef`로 넘긴 속성은 프로시저가 오류로 끝나면 값을 되돌려 쓰지 **않음** | 실패한 작업의 중간 값이 남지 않게 함. [LANGUAGE.ko.md](LANGUAGE.ko.md) 7.2절 참고 |
| D23 | 진단에는 등급(오류, 경고)이 있음. 경고는 실행이나 빌드를 막지 않음. 코드 접두사(L, P 등)는 등급이 아니라 알리는 쪽을 나타냄 | 동작은 하지만 살펴볼 만한 것(쓰지 않는 변수 등)은 알려 주되 막지는 않아야 함. [LANGUAGE.ko.md](LANGUAGE.ko.md) 1.2절 참고 |
| D24 | `gubasic_runtime`과 폼 디자이너가 생기기 전까지 놀이터는 **언어만** 실행함(변수, 식, 조건, 반복, 프로시저, `Try`). 출력은 `Debug.Print`(VB6의 직접 실행 창), `MsgBox`, `InputBox`로 함. 컨트롤과 폼을 HTML로 **흉내 내지 않음**. 컨트롤과 폼은 `gubasic_runtime`과 함께 붙이고, 그때 놀이터를 Flutter 웹으로 옮기는 방안을 검토함 | HTML로 만든 두 번째 런타임은 D11(인터프리터와 생성된 앱이 런타임 하나를 씀)에 어긋나고, 나중에 버려야 함 |
| D25 | 인터프리터는 분석기 결과를 그대로 따름. 사용자 프로시저 호출은 모두 await하고, 그런 호출이 없는 식은 동기로 계산함. 호출마다 새 마이크로태스크에서 시작하고 오류도 호출 하나마다 마이크로태스크를 거쳐 올라가므로, 재귀 깊이는 플랫폼 스택이 아니라 힙을 씀. 10,000단계보다 깊은 호출은 R009. `Dim`은 실행될 때마다 다시 실행됨(LANGUAGE 3.2절). 실행 중 오류는 `Try`로 잡을 수 있음 | 이름과 변환이 분석기와 같고, 따라서 나중의 트랜스파일러와도 같음. 동기 계산: 최적화된 웹 빌드에서 100만 번 반복이 9초 대신 약 3초이고 결과는 같음. 측정 결과: 호출마다 마이크로태스크를 두지 않으면 약 1,000단계 깊이에서 난 오류가 VM 스택을 넘쳤음. 두면 VM과 Chrome 모두 100만 단계 깊이도 안전함. 그래서 10,000은 안전을 위한 제한이 아니라 끝나지 않는 재귀를 잡기 위한 제한임 |
| D26 | **`Integer`는 모든 플랫폼에서 정확한 64비트 정수** — 웹의 인터프리터도, 나중에 생성되는 웹 앱도 마찬가지. VM은 Dart의 `int`, 웹은 package:fixnum의 `Int64`를 쓰며, 둘 다 넘침 검사와 함께 하나의 API 뒤에 있음(`checked_math.dart`). 같은 동일성 프로그램을 VM과 Chrome에서 돌림 | 프로그램은 어디서 돌든 같은 수를 계산해야 함. 웹에서의 비용: 마이크로 벤치마크에서 Chrome의 `Int64` 덧셈 500만 번은 97ms, 일반 숫자는 3ms(약 30배). 인터프리터에서는 차이가 드러나지 않음(100만 번 반복이 `Integer`와 `Double`에서 같은 시간). 해석 비용이 대부분이기 때문이며, 생성된 웹 앱의 정수 계산이 많은 코드는 이 비용을 치르게 됨. 렉서 경고 L007(웹이 정확히 담지 못하는 정수)은 불필요해져서 폐지함 |
| D27 | 폼 파일(`.form.yaml`)과 프로젝트 파일(`.gbproj`)은 `formatVersion: 1`인 YAML이며 `gubasic_lang`이 읽습니다. 기본 컴포넌트의 `component.yaml`은 생성기가 `gubasic_lang` 안으로 복사합니다. 이 파일들의 문제는 F 진단으로 그 자리에 알리고, 나머지는 계속 읽습니다. 코드는 폼과 함께 분석하므로 컨트롤, `Me`, 이벤트 처리기를 실행 전에 검사합니다 | 분석기는 웹을 포함한 모든 플랫폼에서 컨트롤을 알아야 하고, `gubasic_lang`은 계속 일반 `dart test`로 돌아야 합니다(CLAUDE.md 규칙 1). 파서처럼(D14) 문제 뒤에도 계속 읽어서 실수 하나가 다른 실수를 가리지 않게 합니다. 이벤트와 다르게 쓴 처리기는 실행되지 않는 보통 프로시저로 조용히 넘기지 않고 오류로 알립니다(A032) |
| D28 | **폼이 있는 프로그램은 한 번에 이벤트 처리기 하나만 실행합니다.** 다른 처리기는 실행 중인 처리기가 끝나거나 `DoEvents`에서 기다릴 때 시작하고, 그 사이의 이벤트는 순서대로 기다립니다. 같은 처리기는 다시 시작하지 않습니다(D5). `MsgBox`와 `InputBox`는 모달입니다: 차례를 넘기지 않으며, 떠 있는 동안의 이벤트는 버립니다. 긴 반복 중의 자동 화면 갱신으로는 다른 처리기가 실행되지 않습니다. 변경 이벤트가 있는 속성(`TextBox.Text`)에 프로그램이 값을 넣으면 처리기를 그 대입의 일부로 바로 실행합니다. 기다릴 수 있는 대입은 이것뿐이라서, 다른 속성 대입은 모두 D25의 동기 경로를 그대로 씁니다 | 처리기가 서로의 일을 볼 수 있는 곳이 코드에 보이는 곳(`DoEvents`)뿐이라서, 실행이 결정적이고 모든 플랫폼에서 같습니다. 대화상자는 데스크톱과 휴대폰에서처럼, 그리고 기본으로 응용 프로그램 모달인 Visual Basic .NET의 `MsgBox`처럼 동작합니다([Interaction.MsgBox](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.interaction.msgbox)). VM에서 잰 값: `Label.Left`에 1,000,000번 대입하는 데 0.29초, `TextBox.Text`에 0.66초가 걸리며, 속성을 쓰지 않는 반복은 전과 같은 속도입니다 |
| D29 | **저장소 전체에 Flutter 버전 하나, 적는 곳도 하나:** `packages/gubasic_runtime/pubspec.yaml`의 `environment: flutter: 3.47.7`. CI는 모든 작업에서(순수 Dart 작업도 그 Flutter의 Dart를 씀) `subosito/flutter-action`(`flutter-version-file`)으로 정확히 그 버전을 설치합니다. 개발 컴퓨터에서는 `dart tool/check_flutter.dart`(`packages/gubasic_runtime`에서)가 설치된 Flutter와 비교합니다 | 맥과 Windows PC가 같은 Flutter로 빌드하고 시험해야 합니다. pub은 그 줄을 하한으로만 검사합니다: "The Flutter SDK only enforces the lower bound of the flutter constraint" ([pubspec](https://dart.dev/tools/pub/pubspec)). 그래서 정확히 비교하는 검사가 따로 필요합니다. flutter-action은 pubspec에서 정확한 버전을 읽습니다([flutter-action](https://github.com/subosito/flutter-action)). Flutter를 올릴 때는 그 줄을 바꾸고, 입력기 기록과 동일성 테스트를 다시 확인합니다 |
| D30 | **IDE는 자기 글꼴과 엔진을 담아 다님.** Pretendard 1.3.9(Regular, Bold, OFL, `apps/ide/fonts/pretendard/`, D49)를 넣어 모든 플랫폼(웹, macOS, Windows)에서 씀. 웹 빌드는 `--no-web-resources-cdn`으로 만들어, 엔진(CanvasKit)과 대체 글꼴을 Google CDN이 아니라 앱과 같은 서버에서 받음. 첫 방문에는 첫 화면이 나올 때까지 "불러오는 중…"("Loading…")과 받은 양(D43)을 보여 줌. Bold는 첫 화면 뒤에 불러오는 애셋임(`BoldFont`): 코드 편집기 Event 목록에서 이미 있는 처리기만 Bold를 쓰며(D38), 받기 전에는 Regular로 그림. **첫 방문에 첫 화면 전까지 받는 양: 4.2 MB**. https://kooboom.github.io/gubasic/ide/ 에서 캐시를 끈 Chrome으로 잼(GitHub Pages가 gzip으로 압축해 보냄): Regular 1.05 MB, CanvasKit 2.1 MB, 앱 코드 0.97 MB, 나머지 0.1 MB. Bold 1.07 MB는 첫 화면 뒤에 받음. Noto Sans KR 2.004일 때는 https://kooboom.github.io/gubasic/ide/ 에서 잰 6.9 MB였음(Regular 3.7 MB, 뒤에 받는 Bold 3.9 MB). 모든 파일이 IDE 자신의 호스트에서 오고, D2Coding은 받지 않음(D36). **두 번째 방문**은 10분 안이면 아무것도 받지 않음: Pages가 `Cache-Control: max-age=600`을 보내고, 브라우저가 가진 사본을 씀. 그 뒤에는 브라우저가 다시 묻고, Pages가 파일 없이 `304 Not Modified`(`ETag`로)를 돌려줌: 0.01 MB 미만, 첫 화면은 0.4초 대신 1.6초 뒤(집에서 잼). | GuBASIC은 폼을 픽셀 단위로 그리는 도구임. 플랫폼마다 한글 글꼴(macOS, Windows 기본 글꼴)의 글자 폭이 다르면, 한쪽에서 맞게 그린 Label이 다른 쪽에서 잘림. IDE가 어디서나 같은 글꼴을 쓰면 "그린 대로 보인다"는 디자이너의 약속이 지켜짐. 엔진과 글꼴을 직접 내보내면 Google 서버가 막힌 곳에서도 웹 IDE가 동작하고, CDN에서 받은 글꼴로 한글 음절이 빠지는 문제([flutter/flutter#188255](https://github.com/flutter/flutter/issues/188255))도 피함. 대가: 데스크톱 IDE도 약 3 MB 커짐. 개발 도구이므로 받아들임. 나중에 만드는 앱에는 이 글꼴이 들어가지 않음: KNOWN_ISSUES 참고 |
| D31 | **IDE는 폼 파일을 한 가지 모양으로 씀** (`gubasic_lang`의 `writeFormFile`): 속성은 `component.yaml` 순서대로, 기본값과 다른 값만, 따옴표는 YAML이 다르게 읽을 글자에만, 보이지 않는 글자와 줄 구분 문자는 `\uXXXX`로 씁니다. 손으로 쓴 파일의 주석과 줄 배치는 남기지 않습니다 | 같은 폼은 늘 같은 바이트가 되므로, 저장만으로는 Git 변경이 생기지 않고 고친 곳은 그 줄만 바뀝니다(D13). 주석을 남기려면 원래 글을 보존하는 YAML 편집기가 필요한데, 디자이너가 생기면 손으로 쓰는 폼 파일은 드뭅니다. `gubasic_lang`에서 쓰므로 리더와 함께 일반 `dart test`로 시험합니다(CLAUDE.md 규칙 1): 예제는 바이트 그대로 다시 써지고, 어떤 글자든 그대로 다시 읽힙니다 |
| D32 | **프로젝트는 `.gbproj` 파일**과, 그 파일에 적힌 폼마다 옆에 있는 `FORM.form.yaml`, `FORM.gbas`입니다. 폴더의 다른 파일은 건드리지 않습니다. 데스크톱 IDE는 Visual Basic 6이 `.vbp`를 열듯 `.gbproj` 파일로 프로젝트를 엽니다. 대화상자는 시스템의 것을 씁니다(`file_selector`). **저장**(⌘S / Ctrl+S)은 프로젝트 저장입니다: `.gbproj`, `.form.yaml`, `.gbas` 가운데 바뀐 파일을 모두 저장합니다. 파일마다 임시 파일에 다 쓴 뒤 그 파일로 바꿔 놓고, 연 뒤에 다른 프로그램이 디스크의 파일을 바꿨다면 먼저 묻습니다. **다른 이름으로 저장**은 프로젝트 전체를 새 폴더에 복사합니다: 시스템의 저장 창에서 위치와 이름을 정하면, IDE가 `NAME` 폴더와 `NAME.gbproj`(`name:`을 `NAME`으로, D31 방식으로 씀), 폼 파일들을 만듭니다. 이미 있는 폴더에는 쓰지 않고, Visual Basic 6처럼 파일마다 묻지 않습니다. 저장 창에는 `.gbproj` 파일을 저장한다고 알려 주므로(맥 앱이 `Info.plist`에 선언한 형식 `io.github.kooboom.gubasic.project`. 선언하지 않았을 때는 macOS가 `.band`라는 다른 확장자를 붙였습니다) macOS가 확장자를 붙이고([Apple](https://developer.apple.com/documentation/appkit/nssavepanel/allowedcontenttypes)), 프로젝트 이름과 같은 폴더를 대치할지 묻지 않습니다. 그 폴더가 있으면 IDE가 이미 있는 프로젝트를 덮어쓰지 않는다고 알립니다. 프로젝트 이름에는 점을 쓸 수 없습니다. macOS는 `MyQuiz.band`처럼 이름 붙은 폴더를 다른 프로그램의 문서로 보여 줄 수 있기 때문입니다. **폼의 `.form.yaml`과 `.gbas`는 이름이 같은 한 쌍**이라 늘 함께 저장하고 함께 이름이 바뀝니다. 폼 하나만 따로 저장하는 기능(Visual Basic 6의 "Form1을 다른 이름으로 저장")은 여러 폼을 다루는 2단계에서 정합니다. **내장 예제는 덮어쓰지 않습니다.** 고칠 수는 있고(D34), 예제에서 저장을 누르면 다른 이름으로 저장이 됩니다. 저장하지 않은 변경이 있으면 제목의 프로젝트 이름 뒤에 "— 편집됨"이 붙습니다. **macOS IDE는 샌드박스 없이 실행됩니다.** 그래서 문서·데스크톱·다운로드 폴더의 프로젝트를 처음 열 때 macOS가 그 폴더에 접근해도 되는지 한 번 묻습니다. 허용해야 `.gbproj` 옆의 폼 파일을 읽을 수 있습니다. 앱 식별자가 바뀌면 다시 묻습니다. 웹에서는 대신 브라우저에 보관합니다(D33) | Visual Basic 사용자에게 익숙한 것은 프로젝트 파일을 여는 방식입니다. macOS 앱 샌드박스에서는 사용자가 고른 항목만 쓸 수 있습니다([Apple](https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox)). 그래서 `.gbproj` 파일 하나를 고르면 옆의 폼 파일을 읽거나 저장할 수 없습니다. 이 때문에 IDE는 샌드박스 없이, App Store 밖에서 배포하는 앱이 그럴 수 있듯 사용자 자신의 권한으로 실행됩니다. 프로젝트마다 폴더 하나는 파일들이 이미 그런 모양이기 때문입니다(7절, D13). 그래서 프로젝트를 그대로 복사하거나 압축하거나 Git에 넣을 수 있습니다. 파일을 한 번에 바꿔 놓으면, 도중에 앱이 죽거나 디스크가 차도 옛 파일이나 새 파일 중 하나만 남고 반쯤 쓴 파일은 남지 않습니다. 덮어쓰기 전에 물으면 다른 프로그램이 바꾼 내용이 말없이 사라지지 않습니다. 예제를 그대로 두면 학생 모두가 같은 프로젝트에서 시작하고, 복사본을 만들면 자기 작업이 어디 있는지 분명해집니다. 저장 뒤의 알림을 놓쳐도 제목의 표시로 저장하지 않은 것이 있는지 알 수 있습니다. `file_selector`는 Flutter 팀의 패키지입니다([pub.dev](https://pub.dev/packages/file_selector)). 웹에서는 파일을 여는 것만 되므로, 웹은 저장 방식을 따로 정합니다 |
| D33 | **웹 IDE는 프로젝트를 브라우저에 보관하고, 안전하게 지키는 것은 `.zip`입니다.** 웹에서 저장한 프로젝트는 브라우저에 보관합니다. D53부터는 IndexedDB에 보관합니다(그 전에는 `localStorage`에 프로젝트마다 `gubasic.ide.`로 시작하는 키 하나). 형식 버전을 담은 JSON입니다. 바뀐 뒤 잠시 후, 그리고 페이지가 가려질 때 다시 보관합니다. 예제는 덮어쓰지 않으므로, 저장하면 이름을 물어 복사본을 보관합니다. **.zip으로 내려받기**(위쪽 막대에 늘 있는 버튼도 같음)는 `NAME/` 폴더와 프로젝트 파일이 든 `NAME.zip`을 줍니다. 데스크톱 IDE가 그대로 열 수 있습니다. 내려받지 않은 변경이 있는 동안에는 버튼이 눈에 띄게 바뀌고, 페이지를 떠나기 전에 브라우저가 묻습니다. 상태 줄에는 이 브라우저에 보관 중이라는 것과 마지막으로 내려받은 시각을 보여 줍니다. 처음 저장할 때는 브라우저마다 한 번, 공용 PC에서는 지워질 수 있고 Safari는 7일 동안 방문하지 않으면 지운다고 알립니다. **.zip 올리기…**는 프로젝트를 다시 가져옵니다. `.zip`은 12MB, 가져오는 파일 100개까지이고, 풀었을 때 GuBASIC 파일은 2MB, 그림은 D52의 상한까지입니다. 절대 경로나 `..`이 있는 항목이 하나라도 있으면 파일 전체를 거절합니다. `.gbproj`, `.form.yaml`, `.gbas`만 맨 위나 폴더 하나 안에서 가져오고, 그 옆 `pictures/`에서는 `.gbproj`가 적은 그림을 가져오며(D52), 다른 파일은 빼고 이름을 알립니다. 거절할 때는 언제나 이유를 알립니다(en/ko) | 브라우저는 디스크에 파일을 쓸 수 없지만(D32), 학생이 새로고침이나 탭 닫기로 작업을 잃으면 안 되므로 자동으로 보관합니다. 브라우저 저장소는 오래가지 않습니다. 사용자나 공용 PC가 지우고, Safari는 사이트를 방문하지 않은 채 7일 동안 쓰면 `localStorage`를 포함해 스크립트가 쓸 수 있는 저장소를 지웁니다([WebKit](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/)). 그래서 `.zip`을 늘 한 번에 누를 수 있게 두고, 필요한 동안에는 내려받으라고 알립니다. 앞머리는 같은 사이트의 다른 페이지(`kooboom.github.io`에는 놀이터도 있음)와 키가 섞이지 않게 합니다. 프로젝트가 몇 KB의 텍스트였고 `localStorage`는 동기식이라 페이지가 닫히는 중에도 보관되었습니다. 그림 때문에 IndexedDB로 옮겼습니다(D53). 올린 파일은 밖에서 온 것이라 보관하기 전에 검사합니다. 운영체제가 만든 `.zip`은 압축되어 있으므로 `.zip`은 `archive` 패키지로 읽고 씁니다([pub.dev](https://pub.dev/packages/archive)) |
| D34 | **폼 디자이너는 동작 하나마다 폼 파일을 바꿉니다.** 동작 하나(컨트롤 놓기, 옮기기, 크기 조절, 지우기, 폼 크기 조절, 화살표 키 한 번)가 끝날 때마다 `writeFormFile`(D31)로 폼 파일 전체를 다시 써서 열린 프로젝트에 넣습니다. 그 파일이 바뀐 것과 같습니다. 마우스로 끄는 동안에는 화면만 바뀝니다. runtime 위젯이 마우스를 바로 따라옵니다. 선택한 컨트롤은 마우스로 끌거나, macOS에서는 ⌘와 화살표 키(다른 곳에서는 Ctrl과 화살표 키)로 옮깁니다. 크기는 손잡이 8개로, 또는 Shift와 화살표 키로 바꾸며, 이때는 오른쪽이나 아래 변이 움직입니다. 폼 크기는 폼의 오른쪽과 아래 변에 있는 손잡이로 바꾸며, 64픽셀보다 작아지지 않습니다. 컨트롤은 폼 밖으로 나가지 않고 8픽셀보다 작아지지 않습니다. 그래서 "— 편집됨", 저장(바뀐 폼 파일만), 웹의 자동 보관, F5가 다른 파일이 바뀔 때와 똑같이 동작하고, 디자이너만을 위한 것은 없습니다. 되돌리기와 다시 하기는 파일이 가졌던 글자를 오가며, 폼 파일마다 100단계까지입니다. 기록은 프로젝트를 바꾸거나 닫으면 사라지고, 저장한 글자까지 되돌리면 "— 편집됨"도 사라집니다. 새 컨트롤의 이름은 종류 이름에, 대소문자와 상관없이 어느 컨트롤도 쓰지 않는 가장 작은 번호를 붙인 것입니다(`Button1`, `Label1`, `TextBox1`). 놓자마자 선택됩니다. Button과 Label의 `Caption`은 이름으로 시작하고, TextBox의 `Text`는 비어 있습니다. 격자(8픽셀, 처음에는 켜짐, 모든 폼에 같이 적용)를 켜면 컨트롤을 격자 단위로 놓고 크기를 맞추며 화살표 키는 다음 격자선으로 옮기고, 끄면 1픽셀 단위입니다. 예제도 고칠 수 있지만 덮어쓰지는 않습니다(D32). 오류가 있는 폼 파일은 오류와 함께 보여 주기만 합니다 | 폼을 바꾸는 길이 하나이면 디자이너와 파일이 어긋나지 않습니다. 파일은 늘 디자이너가 보여 주는 그대로이고, 늘 같은 방식으로 쓰이므로 바뀐 것이 Git에서 바뀐 줄로만 보입니다(D13). 글자를 기록하면 어떤 동작이든 정확히 되돌릴 수 있고, 파일 내용과 어긋날 수 없습니다. 종류 이름과 번호로 된 이름은 무슨 컨트롤인지 알려 주고 언제나 올바른 이름입니다(LANGUAGE.md §1). 이름을 보여 주는 Label은 폼에서 바로 보이고, TextBox는 보통 빈 채로 시작합니다. 오류가 있는 폼 파일을 다시 쓰면 읽지 못한 항목이 사라집니다. 테두리만이 아니라 위젯 자체를 옮기면 폼이 어떻게 보일지 바로 알 수 있습니다. macOS에서는 Control과 왼쪽·오른쪽 화살표가 데스크톱(Spaces)을 바꾸어 앱까지 오지 않으므로([Apple](https://support.apple.com/guide/mac-help/work-in-multiple-spaces-mh14112/mac)), macOS에서는 ⌘로 컨트롤을 옮깁니다 |
| D35 | **속성 창은 글자는 치는 대로, 숫자는 Enter에서 반영합니다.** 디자이너 오른쪽의 목록에서 폼이나 아무 컨트롤이나 고르면, 그 대상의 (Name)과 속성이 component.yaml 순서로 나옵니다. 글자(Caption, Text)는 디자이너의 다른 동작처럼(D34) 치는 대로 폼 파일에 들어가므로 캔버스에 바로 보입니다. 숫자는 Enter를 누르거나 칸에서 나갈 때 들어가고, 치는 동안에는 검사만 합니다. TextBox와 같이(LANGUAGE.md §11.1) 입력기가 확정한 글자만 들어갑니다. 조합 중인 글자는 칸과 캔버스에는 치는 대로 보이지만 파일과 되돌리기 기록에는 들어가지 않고(작성자가 키마다 폼이 따라오는 쪽을 더 자연스럽게 봄), 칸에서 나가거나 Enter를 누르면 확정됩니다. 조합 중에 누른 Esc는 조합 중인 글자만 버리고, 한 번 더 누르면 원래 값으로 돌아갑니다. 한 칸에서 고친 것은 되돌리기 한 단계이고, 그 단계는 칸에서 나가거나, Enter를 누르거나, 다른 칸으로 옮길 때 끝납니다. 올바르지 않은 값(숫자가 아니거나 component.yaml의 범위 밖)은 반영하지 않습니다. 칸이 그 이유를 영어나 한국어로 알려 주고, 칸에서 나가면 마지막으로 올바르던 값을 다시 보여 줍니다. Esc는 칸이 처음 가졌던 값으로 되돌리고 폼으로 돌아갑니다. 범위는 component.yaml의 것만 따릅니다. 직접 친 Left는 음수일 수 있고, 마우스와 화살표 키만 컨트롤을 폼 안에 둡니다. **디자이너의 키(Delete, Backspace, 되돌리기, 다시 하기, 화살표, Esc)는 폼에 포커스가 있을 때만 동작합니다.** 칸 안에서는 글자를 고치고, ⌘Z / Ctrl+Z는 칸의 글자를 되돌립니다. 도구 막대의 되돌리기는 언제나 폼을 되돌립니다. 폼의 (Name)은 파일 이름이라 여기서 바꾸지 않습니다(2단계). **컨트롤의 (Name)을 바꾸면 폼의 코드에서도 함께 바뀝니다(D39).** 새 이름은 Enter를 누르거나 칸에서 나갈 때 적용되며, 쓸 수 있는 이름(`isUsableName`)이고, 다른 컨트롤의 이름이 아니고, 코드에서 이미 쓰이지 않을 때만 적용됩니다. 대소문자와 상관없이 코드의 이름 가운데 새 이름과 같거나, 새 이름과 `_`로 시작하는 것(이벤트 처리기)이 없어야 합니다. 주석과 문자열은 세지 않습니다(`gubasic_lang`의 `linesUsingName`). `Caption`은 그대로입니다 | 치는 동안 글자가 폼에 보여야 속성 창이 쓸모 있고, 칸 하나에 한 단계여야 되돌리기를 쓸 만합니다. 숫자는 치는 동안 아무도 뜻하지 않은 값을 거칩니다. Chrome에서 실제 키로 Width 120을 고쳐 치자 12, 1을 거치며 컨트롤이 1픽셀까지 줄었기 때문에, 숫자는 Enter를 기다립니다. 글자 칸에서 키는 글자를 고치는 데 씁니다. 빈 칸에서 누른 Backspace가 컨트롤을 지우면 아무 말 없이 작업을 잃습니다. 값을 고쳐 넣지 않고 거절하면 사용자가 쓴 것이 몰래 바뀌지 않습니다. 직접 친 값은 정확한 값이므로 마우스가 아니라 언어의 규칙을 따릅니다. 조합 중인 글자는 아직 사용자가 친 글자가 아닙니다. 기록된 한글 입력기를 칸에 재생하자(`apps/ide/test/properties_ime_test.dart`), 확정된 글자만 쓰게 고치기 전에는 갈가를 치는 동안 ㄱ, 가, 갉이 폼에 들어갔습니다. 조합 중에 폼을 클릭하면 입력기가 확정하기 전에 포커스가 먼저 옮겨지므로, 칸이 나갈 때 스스로 확정합니다. 그러지 않으면 마지막 글자가 사라집니다. 컨트롤 이름만 바꾸면 코드는 사라진 컨트롤을 가리키고, 이벤트 처리기는 아무 말 없이 실행되지 않습니다(VB6에서 처리기가 떨어져 나가던 문제, 4절). 새 이름이 이미 코드에 있으면 그 코드의 뜻이 몰래 바뀝니다 |
| D36 | **코드 편집기는 Flutter의 `TextField`이고, lexer로 색을 칠하며, 처음 쓸 때 받는 D2Coding으로 보여 줍니다.** `.gbas` 파일을 고르면 코드 편집기가 열립니다. 줄 번호가 있고, 키워드·문자열·주석·숫자·폼의 컨트롤을 인터프리터가 읽는 것과 같은 토큰(`lex`)으로 칠합니다. Tab과 Shift+Tab은 4칸 단위로 들여쓰고 내어쓰며, Enter는 그 줄의 들여쓰기를 이어 가고, ⌘Z / Ctrl+Z는 친 것을 되돌립니다. 속성 창(D35)과 TextBox(LANGUAGE.md §11.1)처럼 입력기가 확정한 글자만 파일에 들어가므로, 조합 중인 글자는 저장되거나 실행되지 않습니다. 편집기에서 나가면 조합 중인 글자를 확정합니다. 줄은 자동으로 접히지 않습니다. 글꼴은 **D2Coding 1.3.2 Regular**([naver/d2codingfont](https://github.com/naver/d2codingfont/releases/tag/VER1.3.2), OFL)입니다. 한글이 영문의 정확히 2배 폭입니다. 선언된 글꼴이 아니라 에셋이라, 코드 편집기를 처음 열 때 불러오고, 그때까지는 IDE 글꼴로 보여 줍니다(웹에서 gzip으로 약 2.1MB, 데스크톱 앱에서 4.2MB). IDE는 프로젝트를 첫 폼의 디자이너로 열므로 첫 방문에는 이 글꼴을 받지 않습니다. 코드 파일이 다른 곳에서 바뀌면(나중에 디자이너가 바꿀 때) 편집기에 보이고, 되돌리기 기록은 새로 시작합니다 | Flutter가 주는 글자 칸은 TextBox와 속성 창이 이미 쓰는 것이라, 기록된 한글 입력기를 그대로 재생할 수 있습니다(`apps/ide/test/code_ime_test.dart`). 코드 편집기 패키지를 먼저 비교했고, 입력을 직접 구현한 것([re_editor](https://pub.dev/packages/re_editor))도, 입력기 문제가 열려 있는 것([flutter_code_editor #126](https://github.com/akvelon/flutter-code-editor/issues/126))도 쓰지 않았습니다. lexer로 칠한 색은 언어와 어긋날 수 없습니다. 한글이 정확히 2칸인 글꼴은 한글 주석과 문자열이 있어도 코드 열을 맞춰 줍니다. D30의 이유가 그대로 적용되지만, 학교망 첫 방문이 이미 오래 걸리므로 글꼴은 코드를 열 때까지 기다립니다. 1.3.2는 작성자가 고른 버전이며, 그 뒤 버전은 메타데이터, 합자, 점 있는 0 선택, 힌팅, 편집기에서 아무것도 그리지 않는 제어 문자 매핑만 바꿨습니다 |
| D37 | **플랫폼이 조합 범위를 알려 주지 않으면 runtime이 알아냅니다.** macOS 데스크톱 앱(Flutter 3.47.7, macOS 27, 두벌식 한글 입력기)에서는 자모가 모두 확정된 글자로 오고, 커서 앞 음절이 제자리에서 바뀌며, 조합 범위는 오지 않습니다(`test/ime_logs/macos-app.json`, `tool/ime_probe`를 macOS 앱으로 돌려 기록, semantics 꺼짐). 같은 맥의 Chrome은 조합 범위를 받습니다. 그래서 macOS 데스크톱에서, 그 입력 칸에 플랫폼이 범위를 한 번도 보내지 않은 동안 `gubasic_runtime`의 `ComposingTracker`는 커서 바로 앞에서 입력되거나 바뀐 한글 한 글자를 조합 중으로 봅니다. 새 음절이 시작되거나, 한글이 아닌 키가 오거나, 커서가 움직이거나, 칸이 확정할 때(Enter, 클릭, 포커스 이동)까지입니다. TextBox, 속성 창, 코드 편집기가 모두 이것을 씁니다. 플랫폼이 범위를 보내면 그때부터는 그것을 믿습니다 | LANGUAGE §11.1은 어디서나 같은 이벤트를 약속합니다. 이것이 없으면 맥 앱의 TextBox는 자모마다 `Changed`를 실행하고, 디자이너에는 갈ㄱ이 보였습니다. 짐작을 거쳐 재생하면 맥 앱 기록은 같은 맥의 Chrome에 고정해 둔 이벤트와 똑같이 나옵니다(`text_box_test.dart`). 이것은 Flutter가 아니라 입력기의 동작입니다. 네이티브 macOS 앱인 텍스트 편집기(TextEdit)에서도 조합 중인 음절에 밑줄이 없고, 같은 맥의 Chrome 주소창에는 밑줄이 있습니다(작성자 확인, macOS 27.0.1, `com.apple.inputmethod.Korean.2SetKorean`). 그래서 Flutter에 이슈를 올리지 않았습니다. 가장 가까운 [flutter/flutter#194199](https://github.com/flutter/flutter/issues/194199)는 semantics가 켜져 있어야 합니다. Flutter가 범위를 보내기 시작하면 짐작은 쓰이지 않습니다. 대가: 마지막 음절은 입력기가 다음으로 넘어가거나 칸이 확정할 때 프로그램에 닿습니다. 웹과 같습니다 |
| D38 | **디자이너에서 더블클릭하면 기본 이벤트의 처리기가 열리고, 코드 편집기에는 개체·이벤트 목록이 있습니다.** 컨트롤을 더블클릭하면 그 component.yaml의 `defaultEvent`(`Button`, `Label`: Click, `TextBox`: Changed) 처리기로 코드 파일이 열리고, 빈 폼을 더블클릭하면 `Form_Load`로 열립니다. 처리기가 있으면(대소문자 무시, lexer로 읽으므로 주석과 문자열은 세지 않음) 커서가 본문 첫 줄 끝으로 갑니다. 없으면 코드 끝에 빈 줄 하나를 두고 `Sub NAME_EVENT(…)`, 들여쓴 빈 줄, `End Sub`를 넣고 커서를 그 빈 줄에 둡니다. 선언은 컴포넌트의 이벤트에서 가져옵니다(`EventSpec.handlerSignature`). 프로그램이 실행되는 동안에는 있는 처리기만 열리고, 아니면 이유를 알립니다. 코드 위의 개체 목록((일반), `Form`, 컨트롤들)과 이벤트 목록(그 개체의 이벤트, 처리기가 있으면 굵게. (일반)에서는 (선언)과 어느 이벤트도 처리하지 않는 프로시저)도 같은 방식으로 처리기로 가거나 처리기를 만들고, 커서를 따라 바뀝니다. 방금 만든 처리기는 ⌘Z / Ctrl+Z 한 번에 지워집니다. 더블클릭의 두 번 누름은 같은 컨트롤 위에서, 8픽셀 안이어야 합니다 | 더블클릭으로 처리기 만들기는 1단계의 약속이고(ROADMAP), 목록은 VBA 코드 창의 개체(Object) 상자와 프로시저(Procedure) 상자입니다([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/code-window)). 목록으로는 더블클릭으로 열 수 없는 이벤트(폼의 다른 이벤트 등)도 갈 수 있습니다. 끝에 넣으면 사용자가 둔 코드의 자리는 그대로입니다. 글자 칸 자체의 기록은 0.5초마다 한 단계만 남기므로, 편집기가 열리면서 넣은 처리기는 그대로 두면 첫 단계에 섞입니다. Flutter의 더블탭은 두 번 누름 사이를 100픽셀까지 허용하는데, 손가락에는 맞지만 마우스에는 맞지 않습니다 |
| D39 | **컨트롤 이름을 바꾸면 폼의 코드에서도 한 단계로 함께 바뀝니다.** 속성 창(D35)에서 정한 새 (Name)은 폼의 `.gbas`에도 들어갑니다. 대소문자와 상관없이 코드의 이름 가운데 옛 이름과 같거나 옛 이름과 `_`로 시작하는 것(처리기: `btnHello_Click` → `btnOk_Click`)은 그 부분이 새 이름으로 바뀝니다. 코드는 lexer로 읽으므로(`gubasic_lang`의 `renameInCode`) 주석, 문자열, `btnHelloWorld` 같은 다른 이름은 그대로입니다. `.` 뒤의 이름은 `Me.` 뒤일 때만 바뀝니다. 다른 곳에서는 멤버이기 때문입니다(`lblMessage.Caption`). 바꾸기 전에 속성 창이 코드의 몇 번째 줄에서 그 이름을 쓰는지 알려 줍니다. 실행 취소 한 번에 폼과 코드가 함께 돌아가고, 다시 실행 한 번에 함께 나아갑니다. 이름을 바꾼 뒤 코드가 바뀌었으면, 실행 취소는 옛 텍스트를 되돌리는 대신 코드 안의 이름을 다시 바꿉니다. 코드 편집기는 새 코드를 보여 주고 실행 취소 기록을 새로 시작합니다(D36). 바뀌는 코드는 컨트롤을 쓰는 그 폼의 코드뿐입니다(LANGUAGE.md 11절) | 처리기 이름을 컨트롤과 함께 바꿔야 처리기가 떨어져 나가지 않습니다(VB6에서 처리기가 떨어져 나가던 문제, 4절). 더블클릭으로 여는 처리기(D38)도 마찬가지입니다. lexer의 토큰은 인터프리터가 읽는 토큰과 같으므로 프로그램의 뜻은 그대로입니다. 코드가 이미 쓰는 새 이름은 받지 않으므로(D35) 바뀐 이름은 모두 그 컨트롤의 것이었고, 다시 원래 이름으로 바꾸면 같은 코드가 됩니다. 다만 옛 이름의 대소문자는 한 가지로 통일됩니다(`names_test.dart`). 코드가 바뀐 뒤 옛 텍스트를 되돌리면 그 변경이 사라집니다 |
| D40 | **출력 창의 오류는 그 줄로 가고, 실행이 멈춘 줄은 표시됩니다.** 출력 창의 오류 가운데 코드 파일의 줄이 있는 것(실행 중 오류, 또는 프로젝트가 시작하지 못하게 한 오류)에는 밑줄이 그어집니다. 클릭하면 그 파일이 코드 편집기에 열리고, 커서는 그 줄의 들여쓰기 뒤에 놓입니다. 마지막 실행이 실행 중 오류로 멈춘 줄에는 편집기 너비만큼 배경 띠가 그려지며, 코드 파일이 실행한 그대로일 때만 보입니다. 코드를 고치거나 다시 실행하면 사라집니다. 그 줄이 더 이상 오류가 난 줄이 아닐 수 있기 때문입니다. 프로젝트가 시작하지 못하게 한 오류는 코드에 표시하지 않고 목록에만 보입니다 | 플레이그라운드가 실행 중 오류에 이미 하는 일이고(ROADMAP), 처음 배우는 사람에게 가장 필요한 일입니다. 메시지가 줄을 말하고, 클릭하면 그 줄을 보여 줍니다. 코드가 바뀌지 않았을 때만 표시하므로 오류가 나지 않은 줄을 가리키는 일이 없습니다. 띠는 텍스트가 아니라 입력란 뒤에 그리므로 입력란과 입력기는 그대로입니다(D36) |
| D41 | **컨트롤은 두 층으로 그립니다: graphic(Label)이 control(Button, TextBox) 아래에 있습니다.** component.yaml의 `layer`가 컨트롤을 graphic 층에 두거나, 정하지 않으면 control 층에 둡니다. 폼 파일의 순서와 상관없이 graphic 층을 먼저 그리고, 같은 층 안에서는 폼 파일 `controls` 목록에서 뒤에 있는 컨트롤을 위에 그립니다. 컨트롤이 겹친 곳에서는 위에 있는 컨트롤이 클릭을 받고 아래의 것을 가리며, 실행 화면과 디자이너가 같습니다. Button은 테마의 `surfaceContainerHigh`, 폼보다 한 단계 짙은 색으로 채웁니다(`gbButtonFace`). 순서는 `gubasic_runtime`의 `GbFormModel.drawingOrder`가 정합니다. 실행 화면은 이 순서로 그리고, 디자이너는 이 순서로 그리고 고르며, 트랜스파일러가 만들 앱도 같은 런타임을 쓰므로 이 순서로 그립니다(2.3절). **바뀐 점:** 전에는 파일의 순서만으로 정해졌으므로, Button보다 뒤에 적힌 Label이 Button을 덮고 클릭을 가져갔습니다. 이제 그런 폼에서는 Button이 위에 보입니다. 폼 파일 형식은 바뀌지 않습니다(`formatVersion: 1`). 1단계는 아직 출시되지 않았고, 어떤 마이그레이션으로도 이번에 고치는 예전 모습을 지킬 수 없기 때문입니다. 예제에는 겹친 컨트롤이 없어 전과 같이 보입니다(`designer_test.dart`) | Label을 Button 위에 놓으면 실행 화면에서도 디자이너에서도 Button을 클릭할 수 없었습니다. Visual Basic 6의 폼에는 세 층이 있어서 그래픽 컨트롤과 Label은 가운데 층에, 다른 컨트롤은 맨 앞 층에 있고, ZOrder는 같은 층 안에서만 순서를 바꿉니다([ZOrder Method](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa267180(v=vs.60))). GuBASIC에는 아직 그리기 층이 없으므로 두 층이 남습니다. 폼을 보여 주는 모든 곳이 함수 하나로 정하므로, 디자이너와 프로그램이 다르게 보일 수 없습니다 |
| D42 | **디자이너에서 Tab과 Option+클릭으로 컨트롤을 고르고, ⌘J / ⌘K로 순서를 바꾸며, 오른쪽 클릭으로 디자이너 메뉴를 엽니다.** 폼에 포커스가 있을 때 Tab과 Shift+Tab은 폼 파일 순서로 다음 컨트롤과 이전 컨트롤을 고르고, 끝에서는 처음으로 돌아갑니다. 속성 창과 코드 편집기에서 Tab은 그대로 그쪽의 것입니다. 클릭은 맨 위의 컨트롤을 고릅니다(D41). Option+클릭(Alt+클릭)은 그 자리에서 고른 컨트롤 바로 아래의 컨트롤을 고르고, 맨 아래 다음에는 맨 위로 돌아가며, 코드는 열지 않습니다. ⌘J / Ctrl+J(맨 앞으로)는 고른 컨트롤을 폼 파일 목록의 끝으로 옮겨 그 층의 맨 위에 두고, ⌘K / Ctrl+K(맨 뒤로)는 목록의 처음으로 옮겨 맨 아래에 둡니다. 도구 막대에도 두 버튼이 있고, 바꿀 때마다 실행 취소 한 단계입니다. 두 단축키는 글자가 아니라 키의 자리로 받습니다. 한글 입력기가 켜져 있으면 Mac의 Chrome은 Ctrl+K를 ㅏ로 알리기 때문입니다. 오른쪽 클릭, 두 손가락 클릭, Apple 시스템에서 Control+클릭은 디자이너의 컨텍스트 메뉴를 열고, 그 자리의 컨트롤을 먼저 고릅니다. 컨트롤 위에서는 코드 보기(더블클릭과 같음, D38), 맨 앞으로, 맨 뒤로, 삭제, 속성(속성 창의 첫 칸이 포커스를 받음)이 있고, 빈 폼 위에서는 코드 보기(Form_Load)와 격자가 있습니다. 프로그램이 실행되는 동안에는 코드 보기만 됩니다. 웹에서는 마우스가 폼 위에 있는 동안 브라우저의 메뉴를 끕니다. 메뉴는 폼 위의 위치를 받는 함수 하나가 열므로, 나중에 터치 화면의 길게 누르기도 같은 메뉴를 열 수 있습니다 | 겹친 컨트롤(D41)은 아래에 깔린 것에 닿는 방법이 필요합니다. Visual Studio의 Visual Basic 6.0 단축키 구성에서 Tab은 디자인 화면의 다음 컨트롤을 고르고, Ctrl+J는 맨 앞으로 보냅니다([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/ms172689(v=vs.90))). Ctrl+K는 VBA UserForm 창의 맨 뒤로입니다([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/userform-windowc-visual-basic-user-interface)). 그냥 클릭할 때마다 돌아가며 고르면 더블클릭(D38), 끌어 옮기기와 부딪힙니다. 목록 안에서 옮기므로 폼 파일 형식은 그대로입니다(D41). 컨텍스트 메뉴는 마우스 아래에 있는 것으로 디자이너가 할 수 있는 일을, 처음 배우는 사람이 찾는 자리에 모읍니다 |
| D43 | **웹에서 불러오는 중 글자에 받은 양을 보여 줌: "불러오는 중… 37%".** 빌드 단계(`apps/ide/tool/web_load_sizes.dart`. CI와 Pages 워크플로가 실행함)가 `load_sizes.json`을 씀: 앱 코드(`main.dart.js`), CanvasKit 빌드 각각, 글꼴 목록에 있는 글꼴 각각의 크기. `web/flutter_bootstrap.js`는 Flutter 로더가 시작하기 전에 `fetch`를 감싸서, 엔진과 글꼴의 바이트를 Flutter가 읽었는지와 상관없이 도착하는 대로 셈. `<script>` 태그로 받는 `main.dart.js`는 다 받았을 때 셈(Resource Timing). 퍼센트는 페이지에 필요한 파일 가운데 받은 양이며, CanvasKit은 로더가 고른 빌드만 셈. 99%에서 멈추고 첫 화면과 함께 사라짐. `load_sizes.json`이 없으면 "불러오는 중…"만 보임. 파일은 여전히 Flutter가 직접 한 번씩만 받음: 느린 망을 흉내 낸 Chrome과 WebKit(Safari의 엔진)에서 확인함 | 느린 망(D30: 느린 4G 설정에서 약 100초)에서는 바뀌지 않는 글자가 멈춘 페이지처럼 보여서, 학생이 새로고침하고 처음부터 다시 받게 됨. 받은 바이트의 퍼센트는 망을 따라 움직임. 세기 위해 파일을 Flutter보다 먼저 받으면 브라우저 캐시가 넘겨주기를 기대해야 하고, 그러지 않는 곳에서는 두 번 받음. Flutter가 직접 받는 것을 세면 그런 일이 없음. 단계 이름("엔진", "글꼴")만 보여 주는 것이 대안이었지만, 가장 큰 단계에서 1분 동안 멈춰 있음 |
| D44 | **CheckBox: `Caption`, `Checked` As Boolean, 이벤트는 `Changed` 하나.** 상자나 `Caption`을 클릭하면 `Checked`가 바뀌고 `Changed`가 실행됨. 프로그램이 `Checked`를 바꿔도 `TextBox.Changed`처럼 바로 실행됨(LANGUAGE 11.1절). 상태는 두 가지뿐. 자기 `Changed`가 실행 중일 때 CheckBox를 클릭하면 무시되고 상자도 바뀌지 않음: 위젯이 먼저 물어봄(`Interpreter.refusal`, 런타임의 `GbEventFilter`를 거침). 클릭은 `Click` 전과 같이 조합 중인 글자를 먼저 확정함. 이벤트 스크립트에서는 `chkShow.Click`이 사용자의 클릭. 기본 크기 120 × 32 | Visual Basic 6의 `Value`(0, 1, 회색은 2)는 Visual Basic .NET에서 `Checked`(Boolean)와 `CheckState`가 되었고, VB6의 `Click`은 프로그램이 상태를 바꿀 때도 일어나서 .NET에서는 대신 `CheckStateChanged`를 씀([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/kk8bb7ac(v=vs.90))). Windows Forms CheckBox의 기본 이벤트는 `CheckedChanged`임([dotnet/winforms](https://github.com/dotnet/winforms/blob/main/src/System.Windows.Forms/System/Windows/Forms/Controls/Buttons/CheckBox.cs)). `If chkShow.Checked Then`은 뜻 그대로 읽히고 외울 상수도 없으며, 회색인 세 번째 상태는 초보자의 폼에서 쓸 데가 없음. `Caption`은 Button, Label과 같은 이름. 프로그램이 바꿀 때도 실행되는 이벤트를 `Click`이라 부르면 하는 일을 말하지 못함. `Changed`는 TextBox를 따름. 실행 중인 처리기 밑에서 상자가 바뀌면 처리기가 본 적 없는 상태를 보여 주게 됨 |
| D45 | **컨트롤에 메서드, 읽기 전용 속성, 실행 중에만 정하는 속성이 있을 수 있음.** component.yaml은 `methods:`(`AddItem(item As String)`, `List(index As Integer) As String`)를 적고, 속성에 `readOnly: true`(프로그램은 읽기만 함. 값을 저장하지 않고 컴포넌트 코드가 계산함: ListBox의 `ListCount`), `designTime: false`(폼 파일(F013)과 속성 창에 나오지 않음: `ListIndex`), `internal: true`(런타임이 가진 상태로, 프로그램은 메서드로만 다룸: ListBox의 항목)를 표시함. 읽기 전용 속성에 값을 넣으면 A034이며 `List.Count`도 같음. 메서드는 다른 프로시저처럼 인수를 괄호에 넣어 부름(LANGUAGE 7절). 변경 이벤트가 있는 속성을 바꾸는 메서드는 그 호출의 일부로 이벤트를 실행함(D46). `Object`를 거치면 `o.Name(x)`가 호출인지 항목인지는 실행할 때 정하며, 목록과 문자열도 같음 | ListBox는 코드에서 채우고 읽어야 하고, LANGUAGE 4절에 이미 `lstNames.AddItem(n)`이 있음. Visual Basic .NET의 `Items` 컬렉션은 화면과 묶인 객체를 프로그램에 건네서, 변수에 담아 두었다가 컨트롤 몰래 바꿀 수 있음. 메서드를 쓰면 모든 변경이 컨트롤을 거침. `methods:`는 처음부터 component.yaml 설계에 있었음(5절). 계산하는 값은 낡지 않고, 실행 중의 상태를 폼 파일 밖에 두면 폼 파일은 디자이너가 그린 그대로임 |
| D46 | **ListBox: `AddItem`, `RemoveItem`, `Clear`, `List(index)`, `ListCount`, `ListIndex`, `Text`, 이벤트는 `Changed` 하나.** Visual Basic 6의 이름. 항목 번호는 0부터. `ListIndex`는 고른 것이 없으면 −1이고 실행 중에 프로그램만 정함. `Text`는 고른 항목이나 `""`. `Changed`는 `ListIndex`가 바뀔 때마다 실행됨: 사용자가 다른 항목을 고를 때, 프로그램이 `ListIndex`를 바꿀 때(그 대입의 일부로 바로), `RemoveItem`이나 `Clear`가 고른 항목을 옮기거나 지울 때(그 호출의 일부로). 고른 항목보다 위의 항목을 지우면 고른 번호가 하나 당겨져 같은 항목이 계속 골라져 있음. 고른 항목을 지우거나 `Clear`하면 아무것도 고르지 않은 상태가 됨. 자기 `Changed`가 실행 중일 때 고르면 무시되고 아무것도 바뀌지 않음(D44와 같음). 없는 항목 번호는 R003. `AddItem`에는 위치 인수가 없고 `Sorted`도 없음. 항목은 지금은 코드에서만 넣음(KNOWN_ISSUES). 디자이너에서 빈 ListBox는 이름을 보여 줌. 이벤트 스크립트에서는 `lstCity.Select 2`가 사용자가 2번 항목을 고르는 것. 기본 크기 160 × 120 | Visual Basic 6에는 `AddItem`, `RemoveItem`, `Clear`, `List`, `ListCount`, `ListIndex`(실행 중에만, 없으면 −1, 바꾸면 `Click`이 일어남), `Text`가 있음([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa242144(v=vs.60))). Visual Basic .NET은 이를 `Items.Add`, `Items.Count`, `SelectedIndex`로 바꿨고([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/2yc9d57t(v=vs.90))), ListBox의 기본 이벤트는 `SelectedIndexChanged`임([dotnet/winforms](https://github.com/dotnet/winforms/blob/main/src/System.Windows.Forms/System/Windows/Forms/Controls/ListBoxes/ListBox.cs)). 원인과 상관없이 "`ListIndex`가 바뀌면 `Changed`가 실행된다"는 규칙 하나가, 프로그램이 바꿀 때도 일어나는 VB6의 `Click`이 말하지 못하는 것을 말해 줌. VB6 문서는 정렬된 목록에 위치를 주어 `AddItem`하면 결과를 예측할 수 없다고 경고함. 퀴즈에는 둘 다 필요 없음 |
| D47 | **CI가 Windows IDE와 입력기 기록 도구를 바로 실행할 수 있게 내줌.** Windows 작업이 둘을 빌드하고, 각 `Release` 폴더를 실행 결과의 artifact로 올림(`gubasic-ide-windows`, `ime-probe-windows`, 30일 보관). `.exe` 옆에 Visual C++ 런타임(`msvcp140.dll`, `vcruntime140.dll`, `vcruntime140_1.dll`, 러너의 `System32`에서 복사)을 함께 둠. Windows PC에서는 폴더를 풀고 `.exe`를 실행하면 됨: Windows 10 이상(x64)에서는 Flutter, Visual Studio, 재배포 패키지 설치가 필요 없음: 그 DLL 세 개 말고는 `.exe`와 `.dll` 파일이 Windows 자체 DLL과 Universal CRT(`api-ms-win-crt-*`)만 가져다 쓰며, Universal CRT는 Windows 10 이상에 들어 있음([Microsoft](https://learn.microsoft.com/en-us/cpp/windows/universal-crt-deployment)). 첫 artifact를 `objdump -p`로 확인함. 서명하지 않은 앱이라 처음 실행할 때 Windows가 경고할 수 있음 | Visual Studio는 Windows 앱을 빌드할 때 필요하고, 실행할 때는 필요 없음. Flutter Windows 앱은 `.exe`와 옆의 `.dll` 파일, `data` 폴더, 그리고 Visual C++ 런타임이 필요하며, 런타임은 설치해도 되고 앱 옆에 두어도 됨("application-local")([Flutter](https://docs.flutter.dev/platform-integration/windows/building)). 앱 옆에 두면 아무것도 설치할 수 없는 학교 PC에서도 동작함. 이렇게 하면 학교 PC에서 Windows 앱을 써 보고 입력기를 기록할 수 있음 |
| D48 | **`SaveSetting` / `GetSetting`은 프로젝트마다, 프로젝트 이름으로 글자를 저장함.** 인수는 키와 값 두 개. Visual Basic의 앱 이름 자리는 프로젝트 이름(`.gbproj`의 `name`)이 대신하고, 구역(section)은 없음. 키는 대소문자를 가리지 않고, 값은 글자. 프로젝트의 설정은 JSON 글자 하나로, 인터프리터가 프로그램이 처음 물을 때 읽고 `SaveSetting`마다 통째로 씀. 65536자까지(R011)이며, 저장하지 못하면 R012. `gubasic_runtime`의 `GbSettingsStore`가 `shared_preferences`에 `gubasic.settings.<프로젝트>` 키로 저장함: macOS는 IDE의 사용자 기본값(`~/Library/Preferences/io.github.kooboom.gubasic.ide.plist`, `defaults read`로 확인함), Windows는 `%APPDATA%\Jungmo Gu\GuBASIC IDE\shared_preferences.json`(앱 지원 폴더: [path_provider_windows](https://github.com/flutter/packages/blob/main/packages/path_provider/path_provider_windows/lib/src/path_provider_windows_real.dart), 파일 이름: [shared_preferences_windows](https://github.com/flutter/packages/blob/main/packages/shared_preferences/shared_preferences_windows/lib/shared_preferences_windows.dart)), 웹은 브라우저 `localStorage`의 그 키로, IDE 자체 키(`gubasic.ide.`, D33)와 나뉨. 놀이터는 모든 프로그램이 `gubasic.playground.settings` 하나를 씀. 설정은 프로젝트의 파일이나 `.zip`에 들어가지 않음. 파일 → 저장된 설정 지우기가 열린 프로젝트의 설정을 지움. `DeleteSetting`은 나중에 | Visual Basic은 설정을 앱, 구역, 키로 `HKEY_CURRENT_USER\Software\VB and VBA Program Settings` 아래에 저장함([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/savesetting-statement)). 초보자의 프로그램에는 자기 이름 하나와 키면 충분하고, 프로젝트에는 이미 이름이 있음. 설정은 레지스트리처럼 사용자의 데이터이므로 프로젝트 파일 밖에 둠. 한도는 잘못된 반복문이 웹 IDE가 프로젝트를 보관하는 브라우저 저장 공간을 채우는 것을 막음. 런타임의 저장소 하나를 나중에 만드는 앱도 씀(D11) |
| D49 | **IDE는 차분하고 촘촘한 데스크톱 개발 도구처럼 보이고, 폼 위 컨트롤은 각지고 차분함.** IDE의 테마(`ideTheme`): Pretendard(D30)에 꼬리 있는 소문자 l인 문자 변형 `cv05`를 모든 곳에 켜서, `lblName`, `lstCity`가 `IblName`, `IstCity`로 읽히지 않게 함. 글자는 13px이고 목록과 속성 창은 12px이며 모두 보통 굵기. 데스크톱 밀도(목록 한 줄 26px). 모서리는 4px 이하. 회색 위주에 파란 강조색(`ColorScheme.fromSeed`의 neutral 변형). 코드 편집기는 D2Coding 13px. 폼 위 컨트롤은 IDE와 따로 `gubasic_runtime`에 자기 테마(`gbFormTheme`)가 있어서, IDE의 모양과 상관없이 실행 창, 디자이너, 나중에 만드는 앱이 같게 그림: 13px 보통 굵기 글자, 진한 글자에 모서리 3px인 회색 Button, 모서리 2px인 TextBox, ListBox, CheckBox, 한 줄 22px인 ListBox. 글꼴(이름과 기능)만 감싼 앱에서 가져옴(2.3절). 누를 수 없는 Button은 Material의 회색 글자를 그대로 두어, 나중의 `Enabled` 속성에 쓰임. 맥과 Chrome에서 나란히 비교해 고름: IDE는 원래 모양, Noto Sans KR의 촘촘한 모양, 같은 모양의 Pretendard. 폼은 원래 모양과 각진 모양 | IDE가 장난감처럼 보였음: 크고 굵은 글자, 둥근 모서리, 알약 모양 버튼. 데스크톱 개발 도구의 차분한 촘촘함을 원했음. Pretendard는 한글 11,172자와 호환 자모 51자를 모두 담고(글꼴의 문자 표에서 셈) Noto Sans KR의 3분의 1 크기라, 첫 방문에 2.7 MB를 덜 받음(D30). l과 I가 비슷하게 생겼는데, `cv05`가 글꼴에 있음(GSUB 표가 l을 꼬리 있는 l로 바꿈). 폼의 모양을 IDE와 따로 두면 IDE의 모양을 바꿔도 학생이 그린 컨트롤은 바뀌지 않음 |
| D50 | **가벼운 자동완성은 분석기가 아는 것을 알고, "혹시 이것인가요"는 분석기의 진단에서 나옴.** `gubasic_lang`의 `completionsAt`이 코드의 한 자리에 쓸 수 있는 이름을 늘어놓음. `.` 뒤: 그 앞에 있는 것의 멤버(`membersOf`: 컨트롤은 component.yaml의 속성(internal 제외)과 메서드, 그리고 String, List, 배열, `Debug`, `Integer`). 이벤트는 넣지 않음. 이벤트는 `Sub 이름_이벤트`로 처리함(D38). `As`, `New`, `Of` 뒤: 타입 이름. 그 밖의 곳: 지원하는 키워드, 그 자리에서 보이는 이름(프로시저의 지역 변수와 매개변수, 폼 수준 변수와 상수, 이벤트 처리기를 뺀 프로시저, 컨트롤), 내장 함수와 내장 객체. 문자열, 주석, 숫자 안, 한글 바로 뒤, 새 이름을 선언하는 자리(`Dim`, `Const`, `Static`, `Sub`, `Function`, `Optional`, `ByVal` 뒤)에서는 아무것도 내놓지 않음. 커서가 있는 줄만 읽고, 이름은 마지막 컴파일 결과에서 철자로 찾음. 그 결과는 몇 키 전의 것일 수 있음. 친 글자로 시작하는 이름이 먼저, 세 글자부터는 그 글자를 품은 이름이 뒤에 나옴(`count`: `ListCount`). 타입에 없는 멤버는 가까운 멤버가 있으면 A035(A002와 같은 가까움), 다른 버전에서 쓰던 이름이면 A036. 그런 이름은 component.yaml의 `otherNames`에 적음: `Text` → `Caption`(Button, Label, Form, CheckBox), CheckBox `Value` → `Checked`, ListBox `SelectedIndex` → `ListIndex`, `Items` → `AddItem`, `List`, `ListCount`. A002, A035, A036은 그 단어를 바꿀 수 있는 이름을 담고 있고, 자동완성은 그것을 맨 위에 보임. **코드 편집기에서** 목록은 `.` 뒤와 이름의 두 글자째에 단어 아래에 열림(한 글자부터 열면 거의 모든 키에서 열림). 맥은 ⌥Space, 그 밖에서는 Ctrl+Space로도 열고, A002, A035, A036이 있는 단어에서는 바꿀 이름이 "혹시 이것인가요?" 아래 맨 위에 나옴. ↑ ↓로 고르고, Enter, Tab, 클릭으로 단어 전체를 그 이름으로 바꿈(괄호는 넣지 않음). Esc로 닫으면 그 단어에서는 다시 열리지 않음. 이름에 쓸 수 없는 글자, 단어 밖으로 가는 커서, 편집기가 포커스를 잃는 것도 목록을 닫음. 끝까지 친 단어에서 Enter는 줄을 바꾸고, 그 단어 하나뿐인 목록은 열리지 않음. 입력기가 조합하는 동안과 ASCII가 아닌 글자에서는 열리지 않음. 목록에 쓰는 컴파일은 키마다가 아니라 입력이 0.3초 멈출 때 함. **블록 완성:** 블록을 여는 줄(`If … Then`, `For`, `For Each`, `Do`, `Select Case`, `Try`, `Sub`, `Function`) 끝에서 Enter를 누르면, 그것이 짝을 더 맞출 때(D61) 그 줄의 들여쓰기로 닫는 줄을 넣고 커서를 한 단계 안쪽에 둠. 아래에서 이미 닫힌 블록, 한 줄 `If`, 줄 가운데에서 나눈 줄에는 아무것도 넣지 않음. 조합 중인 한글을 확정하는 Enter는 블록을 닫지 않음. 편집기는 줄바꿈 직전의 조합 상태로, 그리고 브라우저처럼 확정과 줄바꿈을 두 번에 나눠 보내는 곳에서는 그 사이에 눌린 키가 없다는 것으로 이를 가림 | 컴포넌트 메타데이터에 이미 모든 멤버가 있고(5절), 분석기에 이미 범위(scope)가 있음. 편집기만을 위한 언어 모델을 하나 더 두면 둘이 어긋나게 됨. GuBASIC에서는 점 뒤에 이벤트를 쓸 수 없으므로, 거기에 이벤트를 늘어놓으면 컴파일되지 않는 코드를 권하게 됨. 한 줄만 읽으면 300줄 파일에서도 키 하나의 비용이 같음(KNOWN_ISSUES). 이름 가운데의 두 글자는 너무 많이 맞음(`st`: `List`). Visual Basic .NET의 Windows Forms 컨트롤은 `Caption`을 `Text`라고 부르고([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/66817acc(v=vs.90)), [Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/kk8bb7ac(v=vs.90))), CheckBox의 `Value`는 `Checked`가 되었으며([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/kk8bb7ac(v=vs.90))), ListBox의 `ListIndex`와 `AddItem`은 `SelectedIndex`와 `Items.Add`가 되었음([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/2yc9d57t(v=vs.90))). 어느 버전으로 배운 초보자든 이런 이름을 씀. 맥에서 ⌃Space는 입력 소스를 바꾸는 키이고([Apple](https://support.apple.com/guide/mac-help/mchlp1406)), 한국 학생은 이 키를 늘 씀. 글자마다 열리거나 다 친 단어의 Enter를 가로채는 목록은 입력을 방해함. 300줄 파일의 컴파일은 VM에서 약 3ms, Chrome에서 2–6ms로, 키마다 하기에는 많지만 입력이 멈출 때는 문제가 없음. 파서가 이미 어떤 블록이 열려 있고 무엇으로 닫는지 알고 있으므로(P006), 블록 완성은 언어 자신의 규칙을 따름. 한국 학생은 음절을 조합하는 중에 Enter로 주석을 끝냄. 그 Enter는 음절을 확정하려는 것이고, 그때 닫는 줄이 들어오면 놀라게 됨 |
| D51 | **Image는 프로젝트의 그림 하나를 보이고, 그림은 프로젝트 폴더 `pictures/`의 보통 파일이며 `.gbproj`에 이름을 적음.** Image 컴포넌트: `Picture`(String, 프로젝트 그림의 이름, 없으면 `""`), `Stretch`(Boolean, 기본 False), `Left`, `Top`, `Width`, `Height`, 이벤트 `Click`(기본). Label처럼 그래픽 층에 그림(D41). `Stretch`가 False면 그림 전체를 비율을 지켜 안에 맞추고, True면 컨트롤을 채움. 컨트롤이 그림에 맞춰 크기를 바꾸지는 않음. component.yaml은 이런 속성에 `picture: true`를 표시함(String, 기본값 빈 글자). **그림**은 프로젝트 폴더 `pictures/`의 파일이고 `.gbproj`의 `pictures:`에 적으며, 그때 `.gbproj`는 `formatVersion: 2`로 씀. 그림이 없는 프로젝트는 여전히 버전 1로 씀. **이름**에는 한글을 쓸 수 있고, 한글은 음절로 모아(NFC) 둠(맥은 파일 이름의 음절을 풀어서(NFD) 줌). 이름은 `.png`, `.jpg`, `.jpeg`, `.gif`로 끝나고 `/ \ : * ? " < > |`를 쓸 수 없음(F014). 코드의 이름처럼 비교함: 영문 A–Z만 대소문자를 가리지 않고, 한글은 음절로(`pictureKey`). 그래서 그렇게만 다른 두 그림은 한 프로젝트에 둘 수 없음(F015). 프로그램은 `Picture`를 대소문자에 상관없이 이름으로 정하고, 읽으면 프로젝트의 철자로 나옴. 프로젝트에 없는 이름은 프로그램을 멈추고(R013), 글자로 쓰면 미리 경고하며(A037), 폼 파일에서는 F016. Visual Basic의 이름은 GuBASIC의 이름으로 안내함: `Image` → `Picture`, `SizeMode` → `Stretch`(A036) | Visual Basic 6의 Image에는 `Picture`와 `Stretch`가 있고, `Click`을 받으며, 가벼운 컨트롤임. `Stretch`가 False면 그림 크기에 맞춰 컨트롤 크기가 바뀜([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa242027(v=vs.60))). Visual Basic .NET의 PictureBox는 그림을 `Image`라 부르고 VB6의 `AutoSize`를 `SizeMode`로 바꿨으며([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/zzt5x46b(v=vs.90))), 값은 `Normal`부터 `Zoom`까지 다섯 가지임([Microsoft](https://learn.microsoft.com/dotnet/api/system.windows.forms.pictureboxsizemode)). `Picture`와 Boolean 하나는 GuBASIC에 없는 상수 목록 없이 초보자가 정할 수 있음. 위치로 배치하는 폼에서 큰 사진에 맞춰 커진 컨트롤은 다른 컨트롤을 덮으므로, False는 대신 그림을 맞춤(VB.NET의 `Zoom`). VB6는 폼의 그림을 폼마다 편집할 수 없는 이진 `.frx` 파일에 넣었음([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa232715(v=vs.60))). 보통 파일은 프로젝트의 다른 파일처럼 보이고, 바꾸고, Git에 넣을 수 있음(D13). 코드는 어느 폼에도 없는 그림을 이름으로 쓸 수 있으므로 `.gbproj`가 목록을 가짐. 예전 GuBASIC은 `pictures:`를 무시하고 저장하면서 그림을 잃을 것이므로, 버전 2로 써서 대신 열지 않게 함(F003, D12). Windows와 macOS는 파일 이름의 대소문자를 가리지 않아서 대소문자만 다른 두 이름은 거기서 한 파일이 됨. 지역 설정 없이 A–Z만 비교하면 VM과 JavaScript에서 답이 같음 |
| D52 | **IDE는 그림을 프로젝트에 복사해 넣기 전에 검사하고, 뺀 그림의 파일은 프로젝트를 저장할 때 지움.** 파일 → 그림…은 프로젝트의 그림을 작은 미리 보기, 크기, 빼기 버튼과 함께 늘어놓고, 그림 추가…가 있음. 속성 창의 Picture 속성은 목록임: (없음), 프로젝트의 그림들, 그리고 그림을 추가해 바로 고르는 그림 추가…. 프로젝트에 없는 이름은 표시를 붙여 목록에 보임. 툴박스에 Image가 있음. **추가**는 운영체제의 창에서 PNG, JPEG, GIF 파일을 받고, 이름의 한글은 음절로 모음(D51). 다음은 이유와 고치는 방법을 알리며 거절함(en/ko, 일부는 줄여서 넣을 수 있음, D56): 그림 이름으로 쓸 수 없는 이름(F014의 규칙), 이름과 상관없이 첫 바이트로 보아 PNG, JPEG, GIF가 아닌 파일(HEIC 사진은 따로 알림), 2MB 넘는 파일, 가로나 세로가 4096픽셀 넘는 그림, 프로젝트의 그림을 모두 합쳐 10MB 넘는 경우, 오류가 있는 `.gbproj`. 대소문자와 상관없이 프로젝트에 이미 있는 이름의 그림은 물어본 뒤 바꾸고, 이름은 프로젝트의 철자를 지킴. 컨트롤의 그림 속성이 가리키는 그림을 **빼기**는 그 컨트롤을 알리며(`Form1.imgShape`) 거절함. 아니면 물어본 뒤 `.gbproj`에서 빼고, 저장할 때 `pictures/`에서 파일을 지움. 저장은 새 그림을 먼저 쓰고, 그다음 텍스트 파일을 쓰고, 지우기는 마지막에 해서 `.gbproj`가 디스크에 없는 그림을 적는 일이 없음. 디스크에서 바뀐 그림은 파일처럼 저장 전에 알리고(D32), 다른 이름으로 저장은 그림도 복사함. 디스크에서 연 프로젝트는 `.gbproj`가 적은 그림을 읽고 없는 그림을 알림. `.zip`(D33)은 그림을 `NAME/pictures/`에 담음. 웹 IDE도 그림을 받고, IndexedDB에 보관함(D53) | 복사해 넣으면 프로젝트는 옮기고, 압축하고, Git에 넣을 수 있는 폴더 하나로 남음(D13, D51). 확장자로는 파일 안에 무엇이 있는지 알 수 없음. 휴대폰 사진은 `.jpg`라는 이름의 HEIC일 수 있으므로 바이트로 판단하고, 메시지는 무엇을 하면 되는지 알림. 상한은 프로젝트를 내려받고, 올리고, 보관할 수 있을 만큼 작게 둠(D33의 `.zip`, 웹에서는 저장소). 한 변 4096픽셀은 폼이 보이는 것보다 큼. 쓰는 그림을 빼면서 컨트롤의 Picture를 비우는 대신 빼기를 거절하면, 사용자가 하지 않은 폼 변경이 없고, 프로젝트에 없는 그림을 가리키는 폼(F016, 실행할 수 없게 됨)도 생기지 않음. `pictures/`에 파일을 넣은 것은 IDE이므로 IDE가 치움. 남겨 두면 나중에 같은 이름의 그림을 넣을 때 부딪침. 바로 지우지 않고 저장할 때 지우면, 저장 안 함은 여전히 디스크가 바뀌지 않았다는 뜻임. 웹 IDE는 프로젝트를 사이트 전체에 약 5MB인 `localStorage` 밖으로 옮길 때까지 그림을 기다렸음(D53) |
| D53 | **웹 IDE는 프로젝트를 IndexedDB에 보관하고, `localStorage`에 있던 프로젝트를 그리로 옮김.** 데이터베이스 `gubasic.ide.db`에는 저장소가 둘 있음: 프로젝트 기록(형식 버전을 담은 JSON, 버전 2는 그림 목록을 적음, 이름의 소문자로 찾음)과 그 그림(바이트, `NAME/PICTURE`로 찾음). 저장은 기록을 쓰고 그림을 바꾸는 것을 한 트랜잭션에서 하므로, 모두 되거나 아무것도 안 됨. 기록은 IDE가 시작할 때 읽어서, 보관한 프로젝트 목록과 페이지를 떠나기 전의 물음이 곧바로 답함. 그림은 프로젝트를 열 때 읽음. 쓰기는 하나씩 차례로 하고, 쓰는 것은 저장을 시작할 때의 프로젝트임. 그 사이의 변경은 저장 안 된 채로 남아 다음에 보관됨. 쓰기가 끝나지 않은 동안에는, 내려받지 않은 변경이 있을 때처럼 페이지를 떠나기 전에 브라우저가 물음. **옮기기:** 시작할 때 아직 `localStorage`에 있는 프로젝트(`gubasic.ide.project.*`)를 IndexedDB로 복사하고, 다시 읽어 같을 때만 `localStorage`에서 지움. 실패한 것은 남겨 두고 다음에 옮김. IndexedDB에 이미 있는 것은 더 새것이므로 그대로 둠. 읽을 수 없는 항목은 그 자리에 둠. 한 번만 보이는 알림 표시는 `localStorage`에 그대로 둠. IndexedDB를 열지 않는 브라우저에서는 아무것도 보관하지 못하고, 저장할 때 그렇다고 알림(D33의 메시지). 이로써 웹 IDE도 데스크톱처럼 그림을 받음(D52) | `localStorage`는 출처마다 약 5MiB인데, IndexedDB는 디스크의 큰 몫을 쓸 수 있음: Chrome과 Safari는 약 60%, Firefox는 10%([MDN](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria)). 프로젝트 하나의 그림이 10MB일 수 있고(D52), 사이트는 놀이터와 함께 씀. IndexedDB는 바이트를 그대로 보관하지만 `localStorage`는 글자만 보관함. 시작할 때 그림을 모두 읽으면 목록 하나를 보이려고 모든 프로젝트의 사진을 메모리에 올리게 됨. IndexedDB는 비동기라서, `localStorage`일 때처럼(D33) 페이지가 닫히기 전에 저장을 끝낼 수 없음. 쓰는 동안 물어보는 것으로 그 약속을 다른 방법으로 지킴. 다시 읽어 같을 때만 옛 사본을 지우면 프로젝트를 잃는 일이 없고, 헷갈릴 두 번째 사본도 남지 않음. Safari의 「7일 동안 방문하지 않으면 지움」은 `localStorage`처럼 IndexedDB에도 적용되므로([WebKit](https://webkit.org/blog/10218/full-third-party-cookie-blocking-and-more/)), 작업을 지키는 것은 여전히 `.zip`임 |
| D54 | **웹 IDE의 페이지가 가려지거나 떠날 때, 열린 프로젝트의 글자를 `localStorage`에도 바로 쓰고, IndexedDB 쓰기가 끝나지 않았다면 다음 시작 때 되살림.** `visibilitychange`로 가려질 때와 `pagehide` 때, 변경이 있는 브라우저 프로젝트의 텍스트 파일만 `gubasic.ide.unsaved.NAME`에 씀(버전과 시각을 담은 JSON). 그다음 예전처럼 IndexedDB에 보관함(D53). 보관한 뒤 저장 안 된 것이 없으면 이 기록을 지움. 시작할 때 기록이 프로젝트의 기록보다 새것이고 내용이 다르면 그 내용으로 프로젝트를 보관하고, 「저장되지 않았던 변경을 되살렸습니다」(en/ko)라고 알리며 그 프로젝트를 엶. 그 뒤 임시 기록을 지움. 더 오래되었거나 같거나, 프로젝트가 없어진 것은 말없이 지움. 쓸 수 없는 것은 다음을 위해 남겨 두고, 읽을 수 없는 것은 그대로 둠. 그림은 임시 기록에 넣지 않음: 브라우저에서는 그림을 넣거나 빼면 잠시 뒤가 아니라 바로 프로젝트를 보관하고, 되살린 프로젝트가 보관되지 않은 그림을 적고 있으면 그렇다고 알림 | D53의 쓰기는 비동기라서, 탭을 닫기 직전의 변경을 잃을 수 있었음. `localStorage`는 동기로 쓰므로 처리기가 끝날 때 임시 기록은 다 써져 있음. 텍스트는 몇 KB라 놀이터 옆에도 들어가지만, 그림은 몇 MB일 수 있어 `localStorage`(출처마다 약 5MiB, [MDN](https://developer.mozilla.org/en-US/docs/Web/API/Storage_API/Storage_quotas_and_eviction_criteria))에 담을 수 없으므로 대신 바로 보관함. 보이는 채로 닫힌 페이지는 먼저 가려지지 않고 떠날 수 있어 두 신호를 다 들음. 프로젝트의 기록과 비교하면 묻지 않고도 어느 쪽이 새것인지 정할 수 있음. 결국 끝난 쓰기는 되살릴 것을 남기지 않음 |
| D55 | **예제의 그림은 글자와 함께 IDE에 들어 있고, 퀴즈는 직접 그린 그림 두 개를 보여 줌.** `tool/embed_examples.dart`는 예제마다 `.gbproj`에 적힌 그림(D51)을 그 순서대로 Base64로 `examples.g.dart`에 넣고, 모든 예제의 그림을 합쳐 16 KB를 넘으면 실패함. 예제는 그림과 함께 열리고, 저장, 다른 이름으로 저장, 내려받기는 프로젝트 자신의 그림처럼 함께 가져감. 퀴즈(examples/quiz)에는 그림 문제가 두 개 있음: 삼각형과 정오각형이며, `tool/draw_quiz_pictures.dart`가 그린 그림(160 × 160 PNG, 1.4 KB쯤)을 Image `imgQuestion`에 보여 줌. 프로그램은 문제마다 `Picture`를 정하고, 그림이 없는 문제에서는 `""`로 정함 | 함께 들어 있으면 예제는 글자처럼 웹을 포함한 모든 플랫폼에서 바로 열림. Flutter 자산이라면 예제를 열 때 받아야 해서, 여는 것이 기다려야 하고 실패할 수도 있음. 사진을 생각하던 때의 계획은 자산이었음: 웹 IDE가 시작하기 전에 받는 양(D43)에 넣지 않으려는 것. 작은 그림 두 개는 그 양을 4 KB쯤 늘리고, 16 KB 한도가 그 정도로 묶어 둠. 더 큰 그림이라면 다시 자산을 생각할 까닭이 됨. 저장소의 스크립트로 그리므로 그림은 프로젝트 자신의 것이어서 누구의 저작권에도 묶이지 않고, 똑같이 다시 그릴 수 있음. 이 예제는 디자이너에서 고른 그림이 보여 주지 못하는 것도 보여 줌: 실행 중에 `Picture`를 바꾸는 것과 `""`로 비우는 것 |
| D56 | **너무 크거나, 너무 넓거나, 프로젝트에 너무 많아 거절된 그림은 사용자가 버튼을 누르면 줄여서 넣을 수 있음.** 거절 이유를 알리는 창에 **줄여서 넣기**가 있고, 무엇을 할지 알림: 긴 변이 1024픽셀 이하인 PNG 사본을 만들고, 이름은 파일 이름에 `.png`를 붙이며, 고른 파일은 그대로 둠. 누르면 그림을 필요한 만큼만 크게 디코딩하고(사진은 EXIF대로 돌려서), 첫 장면을 그 크기로 그린 뒤 Flutter의 PNG 인코더로 씀. 사본이 2MB나 프로젝트에 남은 자리보다 크면 4분의 1씩 더 줄이고, 64픽셀까지 줄여도 크면 줄일 수 없다고 알림. 움직이는 GIF는 미리 알아보고, 사본에는 첫 장면만 남는다고 알림. 사본은 여느 그림처럼 검사해서 넣고(D52), 같은 이름의 그림은 물어본 뒤 바꾸며, 짧은 알림으로 크기를 알려 줌. IDE가 읽을 수 없는 파일에는 버튼이 없음 | 학생이 고르지 않으면 아무것도 바뀌지 않음: 버튼이 사본이 어떻게 될지 알리고, 고른 파일은 그대로 남음. Flutter는 웹을 포함한 모든 플랫폼에서 PNG, JPEG, GIF를 디코딩하고 PNG를 인코딩하므로 패키지가 필요 없음. JPEG 인코딩은 없어서, 사진이 더 작아지지는 않음([Flutter](https://api.flutter.dev/flutter/dart-ui/ImageByteFormat.html), KNOWN_ISSUES). 1024픽셀은 폼이 보여 주는 것보다 큼. 3–6MB 휴대폰 사진(4032 × 3024)은 macOS, Chrome, WebKit에서 1024 × 768, 1.3–1.8MB가 되었고, 압축되지 않는 잡음은 더 줄였음. 디코딩 전에 그림 크기를 알려 주는 `ImageDescriptor`는 웹에 없음. `instantiateImageCodecWithSize`는 어디서나 그 크기를 콜백에 줌 |
| D57 | **모든 컨트롤에는 `Anchor`가 있음: 폼 크기가 바뀔 때 거리를 지킬 폼의 가장자리를 적은 글자.** 기본값은 `"Left Top"`. `Left`, `Top`, `Right`, `Bottom`을 아무 순서, 아무 대소문자로 띄어쓰기나 쉼표로 나눠 적고, `Left Top Right Bottom` 순서로 지킴(`normalAnchor`). 가장자리가 없으면 `""`. 다른 단어는 폼 파일에서 F017, 코드의 글자에서 A038, 넣을 때 R014. 방향마다: 두 가장자리에 붙이면 늘어나고(0 밑으로는 안 줄어듦), 하나에 붙이면 그 가장자리와의 거리를 지키고, 어느 쪽에도 붙이지 않으면 폼이 커진 만큼의 절반을 움직임(내림). 컨트롤마다 기준이 있음: 폼 파일에서, 또는 프로그램이 `Left`, `Top`, `Width`, `Height`, `Anchor`를 마지막으로 넣었을 때의 자리와 그때의 폼 크기. 어떤 폼 크기에서의 자리든 그 기준에서 계산하므로, 폼을 키웠다가 원래대로 하면 모든 컨트롤이 정확히 제자리로 돌아옴. 폼 크기는 사용자가 창 크기를 바꾸거나 프로그램이 폼의 `Width`나 `Height`를 넣을 때 바뀌고, 그 뒤 컨트롤의 속성을 읽으면 지금 자리가 나옴. 런타임(`gbAnchored`, `GbFormModel.setProperty`와 `resize`)과 언어의 테스트 호스트(`anchoredRect`)가 같은 방식으로 계산하고, 동일성 프로그램 `events_anchor`가 둘을 확인함. 이벤트 스크립트에서 `Form.Resize 600 400`은 사용자가 폼 크기를 바꾸는 것. `Dock`은 아직 없음(6절, 2단계) | Visual Basic .NET의 `Anchor`는 네 가장자리의 조합이고 기본값은 `Top`과 `Left`. 마주 보는 가장자리는 컨트롤을 늘이고, 하나도 없으면 폼 크기가 바뀐 거리의 절반을 움직임([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.control.anchor), [Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.anchorstyles)). Visual Basic 6에는 이런 속성이 없어서 프로그램이 `Form_Resize`에서 컨트롤을 옮김([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa445540(v=vs.60))). 폼마다 코드가 필요함. `Stretch`가 Boolean인 것처럼(D51), 글자는 GuBASIC에 없는 상수 목록이 필요 없음. 마지막 자리가 아니라 기준에서 계산하면, 반올림(홀수의 절반)과 0까지 눌린 컨트롤 때문에 창을 끌 때마다 조금씩 어긋나는 일이 없음. 프로그램이 컨트롤을 놓은 곳은 그곳에 두려는 뜻이므로 거기서부터 거리를 잼 |
| D58 | **폼에는 `Resize` 이벤트가 있음: 안쪽 크기가 바뀔 때, 그리고 처음 보일 때 한 번.** 사용자가 창 크기를 바꾸면, 실행 창의 모서리를 놓을 때 일어남(D59). 컨트롤이 `Anchor`대로 옮겨진 뒤임(D57). 폼의 `Width`와 `Height`는 이것을 변경 이벤트로 가지므로, 프로그램이 둘 중 하나를 넣으면 그 대입 안에서 바로 처리기가 실행되고, 그것을 넣는 처리기는 그 변경으로 다시 시작되지 않음(D5). `Form_Load` 다음, 폼이 처음 보일 때 한 번 실행됨. 같은 크기로는 아무것도 일어나지 않음. 대화상자가 열려 있는 동안에는 폼 크기를 바꿀 수 없음(이벤트 스크립트에서 `Blocked`) | Visual Basic 6의 `Form_Resize`는 폼이 처음 보일 때나 창 상태가 바뀔 때 일어나며, 프로그램이 컨트롤을 옮기거나 크기를 바꾸는 곳임([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa445540(v=vs.60))). `Anchor`가 있으면 대부분의 폼에는 코드가 필요 없지만, `Anchor`로 말할 수 없는 배치(버튼 둘이 너비를 나눠 갖기)는 여전히 여기에 쓸 수 있음. `TextBox.Changed` 같은 변경 이벤트로 하면 순서가 늘 같음: 크기가 바뀌고, 그다음 처리기가 그것을 봄. 시작할 때 한 번 실행하면 처리기 하나로 처음 크기의 배치도 할 수 있음 |
| D59 | **IDE는 `Anchor`를 보여 주고 정하며, 디자이너에서 폼 크기를 바꿀 때 적용하고, 실행 중인 폼의 크기를 바꾸게 함.** **속성 창:** `Anchor`는 글자 칸처럼 생긴 상자로 가장자리를 보여 주고(없으면 `(없음: 가운데 가까이 머묾)`), 누르면 십자가 열림: 폼을 뜻하는 틀 안에 컨트롤을 뜻하는 상자가 있고, 상자에서 각 가장자리로 팔이 뻗음. 채워진 팔은 컨트롤이 거리를 지키는 가장자리이고, 누르면 켜지거나 꺼지며, 한 번이 되돌리기 한 단계. **폼:** 고른 컨트롤은 붙은 가장자리마다 그 가운데에서 폼 가장자리까지 점선을 보임. **디자이너에서 폼 크기를 바꾸면**(손잡이, 나중에는 크기 프리셋) 컨트롤이 `Anchor`대로 움직이고, 끄는 동안에도 따라오며, 한 번 끈 것이 되돌리기 한 단계. 폼 자체의 크기는 전처럼 격자를 따르지만, 컨트롤의 자리는 따르지 않음: `Anchor`가 놓은 자리에 있음. 자리는 기준에서 계산함: 연이은 크기 바꾸기의 첫 번째 전의 컨트롤과 폼 크기이며, 폼 파일이 마지막 크기 바꾸기가 남긴 그대로인 동안 유지됨. 파일을 바꾸는 다른 일(컨트롤 옮기기, 속성, 되돌리기)이 있으면 다음 크기 바꾸기는 그때의 폼에서 시작함. 그래서 폼을 키웠다가 원래대로 하면 파일이 정확히 원래와 같음. **실행 창:** 창 모서리 바로 바깥의 모서리 손잡이가 실행 중인 폼의 크기를 바꿈(120 × 24보다 작아지지 않음). 움직이는 동안 컨트롤이 따라오고, 놓으면 `Form_Resize`가 실행됨(D58). 제목을 두 번 누르면 폼이 그린 크기로 돌아감. 대화상자가 열려 있으면 손잡이가 가려짐 | Visual Basic .NET의 디자이너는 속성 창의 십자로 `Anchor`를 정함. 가장자리마다 팔이 하나씩 있음([Microsoft](https://learn.microsoft.com/en-us/dotnet/desktop/winforms/controls/how-to-dock-and-anchor)). 십자는 단어를 읽어야 알 것을 한눈에 보여 줌. 디자이너에서 폼 크기를 바꿀 때 컨트롤을 옮겨야 크기 프리셋이 쓸모 있음(폰 배치가 태블릿 배치가 됨). 기준이 없으면 원래 크기로 돌아가도 컨트롤이 거의 제자리일 뿐임: 홀수의 절반은 내림되고, 0까지 눌린 컨트롤은 크기를 잃음. `Anchor`가 놓은 자리를 격자에 맞추면 사용자가 옮기지 않은 컨트롤이 움직임. 끄는 걸음마다가 아니라 끝에 한 번 `Form_Resize`를 실행하면, 거기에 쓴 배치가 사용자가 고른 크기로 한 번 실행됨 |
| D60 | **디자이너는 폼 크기를 고르게 함: 폰 360 × 800, 태블릿 768 × 1024, 데스크톱 800 × 600, 그리고 폼을 돌리는 단추.** 도구 줄의 크기 메뉴가 셋을 크기와 함께 보이고, 하나를 고르면 폼의 `Width`와 `Height`를 세운 방향으로 정함. 돌리기 단추는 둘을 바꿈. 컨트롤은 D59의 기준에서 `Anchor`대로 움직이므로, 폰 → 태블릿 → 폰(또는 모든 프리셋과 돌리기를 거쳐 폰)으로 하면 폰 폼이 정확히 돌아옴. 한 번 고를 때마다 되돌리기 한 단계. 단추는 지금 폼이 어느 프리셋인지(세웠든 돌렸든)와 크기를 보임(`폰 · 360×800`). 폼 파일에는 새것을 쓰지 않음: 프리셋은 크기일 뿐. **2단계:** 폰이나 태블릿 앱의 폼은 실행되는 화면을 채우므로, 그린 크기는 컨트롤을 재는 기준이고 `Anchor`가 실제 화면에 맞춤. IDE에서 실행 창의 모서리가 하는 것과 같음(D59). 데스크톱 앱은 그린 크기로 창을 엶. **3단계:** 크기별 덮어쓰기(6절)는 이 셋의 이름을 씀. 너비로 어떻게 가를지는 그때 정함 | 크기는 `Width`, `Height`처럼(11.1절) 폼 안쪽이라서 상태 표시줄이나 제목 표시줄은 셈에 넣지 않음. 360은 논리 픽셀로 좁은 폰이며 Android의 compact 너비 구간(600dp 미만)에 들고, 800은 긴 목록을 둘 자리를 남김. 768 × 1024는 세워 든 태블릿, 800 × 600은 작은 데스크톱 창. 태블릿(768)과 데스크톱(800)은 둘 다 Android의 medium 너비 구간(600–840dp)에 들어서([Android](https://developer.android.com/develop/ui/compose/layouts/adaptive/use-window-size-classes)), 3단계는 그 구간만으로는 둘을 가를 수 없음. 프리셋 이름을 파일에 쓰면 1단계에서는 아무 효과 없는 속성이 생김. 크기만으로 이미 알 수 있음 |
| D61 | **Enter 뒤 편집기는 파서가 짝지은 블록대로 들여쓰고, 짝 없는 블록이 줄어들 때 닫는 줄을 넣음.** 파서는 블록마다 여는 줄과 그것이 받는 닫는 줄, 이어지는 줄(`Else`, `ElseIf`, `Case`, `Catch`, `Finally`), 닫는 줄을 적어 둠(`ParseResult.blockLines`). `afterEnter`는 Enter로 끝난 줄에 대해 정함: 블록을 잇거나 닫는 줄은 여는 줄의 들여쓰기로 옮기고, 새 줄은 이은 뒤(`Else`)에는 한 단계 안쪽, 닫은 뒤(`End If`)에는 여는 줄과 같은 곳에서 시작함. 여는 줄 뒤의 새 줄은 한 단계 안쪽이고, 닫는 줄을 넣은 프로그램이 넣지 않은 것보다 닫히지 않은 블록(P006)과 블록 없는 닫는 줄(P007)이 적으면 닫는 줄을 넣음. 그 밖의 줄은 들여쓰기를 그대로 둠. 가운데에서 나눈 줄은 들여쓰기만 지키고, 조합 중인 한글을 확정하는 Enter는 끝난 줄의 들여쓰기만 지킴. 여는 줄이나 닫는 줄처럼 보이는 줄만 파싱함: 한 번, 여는 줄은 두 번. 300줄 파일에서 VM 약 0.5ms, Chrome 약 0.6ms, 보통 줄은 0.01ms | 파서는 닫는 줄을 가장 안쪽의 열린 블록과 짝짓기 때문에, `If a Then` / `If b Then` / `End If`에서 닫히지 않았다고 알리는(P006) 것은 바깥 `If`임. 그 줄 자체의 P006을 찾던 방식(전의 D50)은 안쪽 `If` 뒤에 아무것도 넣지 않았음. 닫는 줄이 있을 때와 없을 때 짝 없는 블록을 세면, 「이 줄에 닫는 줄이 필요한가」를 파서에게 직접 묻는 셈임. 같은 짝짓기가 `End If`가 어느 `If`의 것인지 알려 주므로, 들여쓰기가 윗줄이 아니라 프로그램을 따름. 줄이 끝난 Enter 때 하므로 치고 있는 줄을 옮기지 않음 |
| D62 | **IDE는 시작할 때 마지막에 연 프로젝트를 엶.** 보여 준 프로젝트마다 `example:이름`, `browser:이름`, `folder:경로`(`.gbproj` 파일)로 `gubasic.ide.lastProject`에 기억함: 웹은 브라우저의 localStorage, 데스크톱은 shared_preferences(macOS 앱의 사용자 기본값, Windows는 앱 지원 폴더의 `shared_preferences.json`). IDE가 시작하면 첫 화면 뒤 한 번만 그 프로젝트를 열되, 사용자가 이미 다른 것을 열었거나 바꿨으면 열지 않음. 더는 없는 프로젝트(지운 브라우저 프로젝트, 옮긴 폴더)면 `hello` 예제가 열린 채로 그 이름을 짧게 알림. 너무 일찍 닫혀 되살린 페이지(D54)는 그다음이며, 그것이 열린 채로 남음 | 페이지를 새로 고치거나 다음 수업에 IDE를 연 학생은 예제가 아니라 자기 작업을 기대함. 에이전트의 초보자 시험에서 새로 고침 뒤 hello가 다시 열렸음. macOS 앱은 샌드박스가 아니므로(entitlements가 비어 있음) 한 번 읽은 경로를 북마크 없이 다시 읽을 수 있음. 마지막 프로젝트 하나만 기억하는 것이 가장 작은 걸음이고, 최근 프로젝트 목록은 나중에 같은 키로 할 수 있음 |
| D63 | **파일 → 새 프로젝트는 빈 폼이 있는 프로젝트를 만듦: 대화상자 하나가 이름, 폼의 Caption, 크기를 물음.** Caption은 직접 칠 때까지 이름을 치는 대로 따라감. 크기는 프리셋(D60) 가운데 하나이고, 고르지 않으면 데스크톱. 데스크톱에서는 그다음 운영 체제의 저장 대화상자가 바로 어디에 둘지 묻고(거기서 고른 이름이 프로젝트 이름), 다른 이름으로 저장처럼(D32) 새 폴더에 씀: `이름.gbproj`, Caption과 크기를 담고 컨트롤이 없는 `Form1.form.yaml`, 빈 `Form1.gbas`. 그러면 저장된 채로 열림. 웹에서는 바로 그 이름으로 브라우저에 보관하고(이미 있는 이름이면 다시 물음), 처음 한 번 안내를 보임(D33). 열린 프로젝트에 저장하지 않은 변경이 있으면 먼저 물음 | 초보자의 하루는 예제를 고치는 것이 아니라 새 프로그램으로 시작함. 에이전트의 시험에서 새로 시작할 방법이 없었음. 이름과 Caption을 먼저 물으면 폼이 처음부터 `Form1`이 아닌 제목을 가짐. 폴더를 바로 고르면 그 뒤로 ⌘S가 제자리에 저장하고, 처음부터 보관되는 웹과 같아짐. 데스크톱(800 × 600)은 IDE 창에 맞고, 폰 폼은 한 번 누르면 됨 |
| D64 | **코드가 쓰는 컨트롤을 지우면 먼저 묻고, 그 줄을 알림.** `usesOfControl`이 컨트롤 자체를 쓰는 줄(`btnOk.Caption`, `Me.btnOk`. `Me.` 말고 다른 것의 `.` 뒤 멤버는 해당하지 않고, 주석과 문자열은 코드가 아님)과 그 처리기(`Sub btnOk_Click`)를 찾음. 하나라도 있으면 지우기(키나 디자이너 메뉴)가 보여 줌: 그 줄은 컨트롤이 없으면 오류가 된다는 것, 처리기는 남지만 더는 실행되지 않는다는 것, 되돌리기(⌘Z, Ctrl+Z)로 컨트롤을 살릴 수 있다는 것. 단추는 지우기와 취소. 코드가 말하지 않는 컨트롤은 전처럼 바로 지워짐 | 지우기는 클릭 한 번이고, 오류는 나중에 코드에서 방금 있던 이름의 A001로 나타남. 미리 줄과 함께 말하면 초보자가 무엇이 무엇에 기대는지, 그리고 잃는 것이 없다는 것을 알 수 있음. 처리기는 컨트롤과 함께 지우지 않고 코드에 남김: 남길 만한 작업이 들어 있을 수 있고, 학생이 하지 않은 코드 변경은 하지 않음(D39는 이름 바꾸기만 함) |
| D65 | **온전하지 않은 그림은 넣을 때 거절하고, 그런 그림이 있는 프로젝트를 열 때 이름을 알림.** `pictureLooksWhole`이 순수 Dart로 파일 구조를 읽음: PNG는 `IEND`까지의 청크와 각 CRC, JPEG는 이미지 데이터까지의 세그먼트와 그 뒤의 끝 표시(뒤에 약간의 여백은 허용), GIF는 끝(trailer)까지의 블록. 그런 파일을 넣으면 크기 거절보다 먼저 이유와 할 일(다른 프로그램에서 열어 다시 저장)을 알리고, 줄여서 넣기는 보이지 않음. 프로젝트를 열면(디스크, `.zip`, 브라우저, 되살림) 온전하지 않은 그림의 이름을 없는 그림 다음에 알림. 그 그림은 프로젝트에 남고, 파일 → 그림에서 바꿀 때까지 깨진 그림으로 보임. 완전한 디코딩이 아니므로 통과하고도 그려지지 않는 그림이 있을 수 있음 | 받기나 복사가 실패해 잘리거나 손상된 파일이 그대로 들어가서, 아무 설명 없이 깨진 그림으로만 보였음. 구조 검사는 빠르고 모든 플랫폼에서 같으며 엔진이 필요 없음. 디코딩은 엔진의 시간이 필요해서, 그림을 넣는 동안의 검사가 기다릴 일이 아님. PNG의 CRC는 바뀐 바이트를 모두 잡고, JPEG는 체크섬이 없어 모양과 끝만 확인함 |
| D66 | **디자이너와 실행 창은 자리보다 큰 폼을 줄여서 다 보이게 함.** 디자이너 도구 줄의 「화면에 맞춤」과 실행 창 모서리의 단추로 켜고 끄며, 처음에는 켜져 있고 IDE가 실행되는 동안 프로젝트가 바뀌어도 기억함. 켜져 있으면 들어맞지 않는 폼(창, 제목 표시줄, 손잡이 포함)을 더 작게 그리고(크게는 하지 않고, 10분의 1 밑으로는 줄이지 않음), 모서리에 비율을 보임. 폼 파일과 실행 중인 폼은 바뀌지 않음. 마우스는 사용자가 보는 대로 폼에 닿음: 클릭은 그 아래 컨트롤에 가고, 끌기는 컨트롤, 폼 손잡이, 실행 창 모서리를 화면에서 포인터가 움직인 만큼을 비율로 나눈 만큼 옮김 | 폰 폼(360 × 800)은 대부분의 화면에서 디자이너와 실행 창보다 높음. 스크롤하면 조각조각 보이지만 학생은 만들고 있는 화면 전체를 보고 싶어 함. 들어맞지 않는 것만 줄이면 더 작은 폼은 모두 제 크기 그대로라서, 대부분의 작업에서 격자와 픽셀이 그대로임. 포인터가 비율을 거쳐 폼에 닿게 하면 클릭과 끌기가 사용자가 겨눈 곳에 감 |
