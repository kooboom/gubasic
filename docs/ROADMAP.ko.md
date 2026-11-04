# GuBASIC 로드맵

[English](ROADMAP.md)

각 단계는 실제로 돌아가는 무언가로 끝납니다. 끝내지 못한 큰 단계보다 끝낸 작은 단계가 낫습니다.

---

## 0단계 — 설계

- [x] 설계 결정 ([DESIGN.ko.md](DESIGN.ko.md))
- [x] 언어 초안 ([LANGUAGE.ko.md](LANGUAGE.ko.md))
- [x] 저장소 준비: 라이선스, `dart test`를 돌리는 CI

## 1단계 — 그리고, 더블클릭하고, 실행하기 (완료, v0.1.0)

IDE 안에서 완결되는 비주얼 베이직의 핵심 경험입니다.

- [x] 맥용 IDE 뼈대 (윈도우 빌드도 계속 유지, 웹에서도 실행)
- [x] 폼 디자이너: 도구상자, 캔버스, 끌어 놓기·크기 조절, 속성 창
- [x] 기본 컴포넌트: `Form`, `Button`, `Label`, `TextBox`
- [x] 기본 컴포넌트: `CheckBox`, `ListBox` (예제: [quiz](../examples/quiz))
- [x] 기본 컴포넌트: `Image` (D51–D55, 예제: [quiz](../examples/quiz))
- [x] 절대 배치 (`Left`, `Top`, `Width`, `Height`)
- [x] `Anchor`, `Form_Resize`, 폼 크기 프리셋 (폰 / 태블릿 / 데스크톱) (D57–D60)
- [x] 일반 텍스트 프로젝트 파일 (`.gbproj`, `.form.yaml`, `.gbas`)
- [x] 렉서와 **오류에 강한** 파서
- [x] 분석기: 이름, 범위, 타입 검사와 쉬운 말 진단 (영어 / 한국어)
- [x] 개발용 웹 놀이터 ([써 보기](https://kooboom.github.io/gubasic))
- [x] 코드 편집기: 구문 강조, 더블클릭 → 처리기 뼈대, 이름을 바꿔도 안전한 처리기
- [x] 가벼운 자동완성 (키워드, 컨트롤, 멤버, "혹시 이것인가요")
- [x] **비동기 인터프리터**, 놀이터의 실행 탭에서 프로그램 실행
- [x] F5로 IDE 안에서 앱 실행
- [x] `MsgBox`, `InputBox`, `DoEvents`, `Try…Catch`
- [x] `Settings` (`SaveSetting`, `GetSetting`), 프로젝트마다 따로(D48)
- [x] 실행 중 오류를 쉬운 설명으로 표시하고, 누르면 그 줄로 이동 (영어 / 한국어, 놀이터)
- [x] IDE 코드 편집기에서 실행 중 오류 줄 강조

**완료 기준:** 초보자가 Flutter를 설치하지 않고 작은 퀴즈 앱을 만들어 실행할 수 있다.

## 2단계 — 진짜 앱 만들기 (완료, v0.2.0)

프로젝트 하나를 웹, macOS, Windows에 출시할 수 있게 되어 끝났습니다(v0.2.0). 열린 채 남은 항목은 3단계로 옮겼습니다(D96).

계획, 단계, 결정: [STAGE2_PLAN.ko.md](STAGE2_PLAN.ko.md) (D79–D91).

- [x] 실행 창을 IDE와 플레이어가 함께 쓰는 패키지로 (2-1)
- [x] **플레이어**: 프로젝트 하나를 혼자 도는 앱으로. CI가 웹, macOS, Windows로 빌드. 크기와 속도 측정 (2-2)
- [x] 형식 버전이 있고 여러 폼을 담을 수 있는 프로젝트 묶음, 앱 ID (2-3, D83)
- [x] 파일 → 앱으로 내보내기: 웹 `.zip` (2-4, D84), Windows `.zip` (2-5, D86), macOS IDE에서 macOS `.zip` (2-6, D87)
- [x] 여러 폼: `Form2.Show`, `ShowDialog`, `Hide`, `Close`. 모든 플랫폼에서 창 하나 안에 겹쳐 보임(2-7, D88–D90). IDE에서 폼 추가, 이름 바꾸기, 지우기(2-8, D91). 폼 하나만 따로 저장하지는 않음: 저장은 프로젝트 전체를 저장함(D90)

**완료 기준:** 프로젝트 하나를 웹, macOS, Windows에 출시할 수 있다.

## 3단계 — VB처럼, 업무에, 실제 도구로, 그리고 생태계

릴리스 셋, 그다음 나머지(D94–D96). 순서는 GuBASIC의 대상(D92)을 따릅니다. 먼저 Visual Basic다운 작업 방식, 그다음 파일과 데이터로 하는 업무, 그다음 실제 개발 환경의 도구입니다.

### v0.3 — VB처럼 쓰기 (완료, v0.3.0)

- [x] Visual Basic .NET처럼 컨트롤 배열을 대신하는 것(D95, D98): 여러 컨트롤에 `Handles`, 이벤트를 낸 컨트롤 알기, 폼의 컨트롤을 반복문으로 돌기, 실행 중에 컨트롤 만들기(예제: [계산기](../examples/calculator), 숫자 버튼 10개를 처리기 하나로)
- [x] 컨트롤 배열이나 `On Error`를 쓰면 이 가운데 무엇으로 바꿀지 알려 주는 진단(D95, D99)
- [x] `Timer` 컨트롤(D82, D100)
- [x] `KeyDown` / `KeyUp`과 `KeyPreview`(D82, D101)
- [x] 모듈 파일(`Module1.gbas`)과 `Sub Main`으로 시작하기(D90, D102)
- [x] 디자이너에서 여러 컨트롤 고르기, 복사하고 붙여넣기(D97)
- [x] 메뉴 편집기와 GuBASIC으로 만든 앱의 메뉴: 메뉴 막대와 오른쪽 클릭 메뉴(Visual Basic 6의 [메뉴 편집기](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/62aawczc(v=vs.90))와 [PopupMenu](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa716251(v=vs.60)), Visual Basic .NET의 `ContextMenuStrip`(같은 출처)에 해당)(D106)
- [x] `DialogResult`(D103)
- [x] `OptionButton`: 묶음 안에서 하나만 고르는 라디오 버튼과 묶음을 만드는 방법(Visual Basic 6에서는 폼 위의 옵션 버튼이 한 묶음이고, 프레임마다 또 한 묶음: [Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa241737(v=vs.60))). `Frame`, `ComboBox`(D104, D105)
- [x] 프로젝트 탐색기: 폼으로 보기, 또는 디스크의 파일로 보기(D94)

### v0.4 — 업무에 쓰기

- [x] 마우스 버튼: `e.Button`, `e.X`, `e.Y`가 있는 `MouseDown`과 `MouseUp`, 터치 화면에서는 길게 누르기가 오른쪽 버튼(D111)
- [x] 파일 열기·저장 대화상자, 텍스트 파일 읽고 쓰기(D113)
- [x] CSV 파일(D114)
- [x] 날짜·형식 함수(`DateAdd`, `DateDiff`, `Format`)(D115)
- [x] 표 컨트롤(D116)
- [x] PDF 내보내기(D117)
- [x] 업무 자동화 예제(D95, D117): [Scores](../examples/scores), CSV 파일로 받은 명단을 Grid에 띄우고 합계와 평균을 내어 PDF로 저장

### v0.5 — 실제 개발 도구

- [x] 디버거: 중단점, 한 단계씩 실행(한 단계씩, 프로시저 단위, 프로시저 나가기), 멈춘 동안의 변수와 호출 스택(D127). 중단점은 IDE 설정에 프로젝트별로 남음(D129)
- [x] 디버거의 직접 실행 창, 읽기 전용: 멈춘 동안 `? 식`(D128). 문장 실행은 나중 후보
- [x] `Http` + JSON. 컴포넌트 통로를 거치는 첫 컴포넌트([COMPONENT_CHANNEL.ko.md](COMPONENT_CHANNEL.ko.md), D125): `Get`, `Post`, `GetJson`, `PostJson`, `Send`, `Header`, `Timeout`과 `Json` 형식. 예제: [Weather](../examples/weather)
- [x] `Database` (SQLite). 컴포넌트 통로를 거쳐(D126): `Execute`, `Table`로 주는 `Query`, `LastWasNull`이 있는 `Scalar`, `LastId`, `Open`, `Close`, `Path`. 브라우저 확인은 Playwright(`tool/web_check`). 데이터베이스를 파일로 `Export`·`Import`(D130). 예제: [Notes](../examples/notes)
- [x] 언어·컨트롤·함수를 한곳에 모은 참조 문서, 그리고 AI용 참조(`llms.txt`)(D121 d, D124): [docs/reference](reference/README.ko.md), [llms.txt](../llms.txt)

**v0.5를 시작하기 전에 정할 질문:**

- **Http: 기다리는 동안 화면이 멈추지 않는 방식.** 요청에는 시간이 걸리고, 그동안에도 폼은 그려지고 클릭을 받아야 합니다. 프로그램이 묻는 자리에서 기다리거나(`Dim reply = Await Http.Get(url)`, Visual Basic .NET의 `Await`처럼: [Microsoft](https://learn.microsoft.com/en-us/dotnet/visual-basic/programming-guide/concepts/async/)), `Http.Get`은 바로 돌아오고 완료 이벤트가 답을 가져오는 방식(`httpScores_Completed`, Winsock의 이벤트처럼)입니다. 이 답이 `WebSocket`과 `Room`(v0.6)도 정합니다.

### v0.5와 v0.6 사이

- [x] `Structure … End Structure`: 필드만, 대입하면 복사(배열 필드도), 그 배열과 List, 모듈에 두면 모든 폼에서, 폼에 두면 그 폼에서(D123, D131). 예제: [Quiz](../examples/quiz)
- [x] `New Student With {.Name = "Kim", .Score = 90}`과 배열의 항목 목록 `{"a", "b"}`. 중괄호 안에서는 `_` 없이 줄을 바꿈(D132). 예제: [Quiz](../examples/quiz)
- [x] 편집기가 키워드와 이름을 선언한 표기대로 맞춤(`dim total as integer` → `Dim total As Integer`, `TOTAL` → `total`). Visual Basic의 편집기처럼(D133)
- [x] `With … End With`: 한 값의 멤버 여러 개를 이름을 되풀이하지 않고 씀(D134)

### v0.6 — 함께 쓰기(후보, D122)

계획서: [plans/PLAN_V06.ko.md](plans/PLAN_V06.ko.md) (2026-11-03. 답은 D136. 공개 시험 서버는 두지 않음, 계획서 1절)

- [x] 컴포넌트 통로의 이벤트: 컴포넌트가 이벤트를 알리면 인터프리터가 그 핸들러를 차례로 실행(D136)
- [x] `WebSocket`: `Connect`(열릴 때까지 기다림), `Send`, `Close`, 그리고 `Message`, `Closed`, `Error`. 어떤 표준 WebSocket 서버에도 연결(D136)
- [x] `Room`: `Create`와 `Join`(들어갈 때까지 기다림), `Send`, `SendTo`, `Leave`, `Lock`, 그리고 `Joined`, `Left`, `Message`, `Closed`, `Error`. 메시지 형식을 공개한 중계 서버 위에서(`docs/ROOM_PROTOCOL.ko.md`)
- [x] 저장소에 둔 중계 서버(`packages/gubasic_relay`). 사용자의 자기 서버를 위한 [안내](RELAY_SERVER.ko.md), 설치 스크립트, Apache 설정 예(D123), 릴리스마다 Linux(x64, arm64) 실행 파일. 공개 시험 서버는 두지 않음(D136)
- [x] IDE의 로컬 중계 서버: `Room.Server`가 비면 저절로 켜짐, 기본이 꺼진 "같은 네트워크의 기기 허용"과 경고, QR 코드가 있는 "웹으로 미리 보기"(D136)
- [x] 컨트롤의 `Enabled`, `Visible`, `FontSize`, `FontBold`, `ForeColor`, `BackColor`와 Visual Basic .NET의 `Color`. 컨트롤은 Frame이나 폼의 글자를 물려받음(D137)
- [x] 예제: 폰으로 답하고 TV가 경주를 보여 주는 실시간 퀴즈 [LiveQuiz](../examples/livequiz)([IDEAS](IDEAS.ko.md#실시간으로-함께-websocket과-room))

### v0.7 — 게임 도구(D121 a, D138)

- [x] `Sprite`: 위치, 속도, 프레임이 있는 움직이는 그림(D138)
- [x] 충돌 검사: 사각형, 원, 픽셀: `Hits`, `DistanceTo`(D138)
- [ ] 소리: 효과음과 음악
- [x] `Keyboard.IsDown(Keys.Left)`: 게임 루프를 위한 동시에 누른 키(D138)
- [x] 게임 루프를 Timer 하나로 돌리기 위한 ms 단위 시간: `Milliseconds()`(D138)
- [ ] 예제: 정석을 보여 주는 슈팅 게임(Timer 하나의 게임 루프, 물체마다 상태, 적이 나오는 시간표), 격투 게임

### v0.6 다음(후보, 권장 순서)

- [ ] GuBASIC 서버: 서버에서 HTTP(JSON)와 WebSocket에 답하는 화면 없는 프로그램([IDEAS](IDEAS.ko.md#gubasic-서버)). 예제: 게시판
- [ ] 프로젝트가 고른 패키지를 위한 컴포넌트 통로, 트랜스파일러와 함께([COMPONENT_CHANNEL.ko.md](COMPONENT_CHANNEL.ko.md))
- [ ] UserControl: 다른 사용자의 도구 상자에 넣는, GuBASIC으로 만든 컨트롤([IDEAS](IDEAS.ko.md#usercontrol)). 컴포넌트 통로 다음

### v0.5 다음의 다른 후보

- [ ] 트랜스파일러: GuBASIC → Dart → Flutter 프로젝트. CI에서 변환된 Dart로 동일성 테스트 묶음을 돌림. 디버거 다음이고, pub.dev 컴포넌트가 필요해지거나 STAGE2_PLAN §7의 기준을 넘는 프로그램이 생기면 앞당김(D79, D96)
- [ ] 트랜스파일러와 함께, 네이티브 빌드를 위한 Flutter SDK 내려받기와 GitHub Actions 템플릿. 고르는 사람을 위해(D95)
- [ ] 엑셀 파일을 데이터로(D92)
- [ ] 인쇄
- [ ] 소리, 그림 여러 장으로 하는 애니메이션(게임 도구, v0.7과 함께)
- [ ] 레이아웃: `LayoutMode` (세로 / 가로 / 격자), `Dock`, 화면 크기별 레이아웃 덮어쓰기
- [ ] `ByRef`
- [ ] 동일성 테스트 프로그램을 플레이어로도 돌리기
- [ ] 폰용 Player와 함께 Android 빌드 (D80)
- [ ] iOS 빌드
- [ ] 폰용 **GuBASIC Player**
- [ ] `component.yaml` 어댑터를 통한 pub.dev 추가 컴포넌트
- [ ] `Supabase`, `Firebase` 컴포넌트; 비밀 키 경고
- [ ] 게시 메뉴: Vercel, Firebase Hosting, GitHub Pages, 개인 서버
- [ ] 타입을 아는 자동완성
- [ ] Dart 코드 삽입(비상구)

## 1.0 이후 (아이디어)

아직 계획하지 않은 아이디어는 [IDEAS.ko.md](IDEAS.ko.md)에 따로 둡니다. 그 가운데 [어드벤처 게임 컨트롤](IDEAS.ko.md#어드벤처-게임-컨트롤)이 있습니다.

- 데이터 바인딩 (VB의 Data 컨트롤)
- 패키지 API를 읽어 컴포넌트 어댑터 자동 생성
- 사용자 정의 클래스
- **셀프 호스팅:** GuBASIC IDE의 일부를 GuBASIC으로 다시 그리기

---

## 1.0에서 *하지 않을* 것

이 목록을 적어 두는 것이 사이드 프로젝트를 끝까지 가게 합니다.

- 클래스 상속, 사용자 정의 클래스 없음
- 데이터 바인딩 / Data 컨트롤 없음
- `On Error`, `GoTo` 없음
- 컨트롤 배열 없음
- `Variant` 없음
- 한글(비ASCII) 식별자 없음
- 플러그인 마켓 없음
