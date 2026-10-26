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

## 2단계 — 진짜 앱 만들기 (다음)

계획, 단계, 결정: [STAGE2_PLAN.ko.md](STAGE2_PLAN.ko.md) (D79–D82).

- [ ] 실행 창을 IDE와 플레이어가 함께 쓰는 패키지로 (2-1)
- [ ] **플레이어**: 프로젝트 하나를 혼자 도는 앱으로. CI가 웹, macOS, Windows로 빌드. 크기와 속도 측정 (2-2)
- [ ] 형식 버전이 있고 여러 폼을 담을 수 있는 프로젝트 묶음 (2-3)
- [ ] 파일 → 앱으로 내보내기: 웹 `.zip` (2-4), Windows (2-5), macOS IDE에서 macOS (2-6)
- [ ] 동일성 테스트 프로그램을 플레이어로도 돌리기
- [ ] 레이아웃: `LayoutMode` (세로 / 가로 / 격자), `Dock`
- [ ] `Handles` 절; 실행 중 컨트롤 생성
- [ ] `OptionButton`: 묶음 안에서 하나만 고르는 라디오 버튼과 묶음을 만드는 방법(Visual Basic 6에서는 폼 위의 옵션 버튼이 한 묶음이고, 프레임마다 또 한 묶음: [Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa241737(v=vs.60))). 퀴즈의 보기에 자연스러운 컨트롤이며, 1단계의 퀴즈는 ListBox를 씀
- [ ] 학생 앱의 메뉴: 메뉴 막대와 오른쪽 클릭 메뉴(Visual Basic 6의 [메뉴 편집기](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/62aawczc(v=vs.90))와 [PopupMenu](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa716251(v=vs.60)), Visual Basic .NET의 `ContextMenuStrip`(같은 출처)에 해당)
- [ ] `Database` (SQLite)와 `Http` + JSON
- [ ] 여러 폼과 플랫폼별 `Form2.Show` 동작 (2-7, 2-8). 이때 폼 하나만 따로 저장하는 기능(Visual Basic 6의 "Form1을 다른 이름으로 저장")을 둘지 정함(그때까지 저장은 프로젝트 전체 저장, D32)
- [ ] `Timer` 컨트롤 (2-9)과 `KeyDown` / `KeyUp` (2-10) (D82)
- [ ] `ByRef`

**완료 기준:** 프로젝트 하나를 웹, macOS, Windows에 출시할 수 있다.

## 3단계 — 생태계

- [ ] 트랜스파일러: GuBASIC → Dart → Flutter 프로젝트. CI에서 변환된 Dart로 동일성 테스트 묶음을 돌림. STAGE2_PLAN §7의 기준이 요구하면 더 일찍 (D79)
- [ ] 트랜스파일러와 함께, 네이티브 빌드를 위한 Flutter SDK 내려받기와 GitHub Actions 템플릿
- [ ] 폰용 Player와 함께 Android 빌드 (D80)
- [ ] iOS 빌드
- [ ] 폰용 **GuBASIC Player**
- [ ] `component.yaml` 어댑터를 통한 pub.dev 추가 컴포넌트
- [ ] `Supabase`, `Firebase` 컴포넌트; 비밀 키 경고
- [ ] 게시 메뉴: Vercel, Firebase Hosting, GitHub Pages, 개인 서버
- [ ] 화면 크기별 레이아웃 덮어쓰기
- [ ] 타입을 아는 자동완성
- [ ] Dart 코드 삽입(비상구)

## 1.0 이후 (아이디어)

아직 계획하지 않은 아이디어는 [IDEAS.ko.md](IDEAS.ko.md)에 따로 둡니다. 그 가운데 [어드벤처 게임 컨트롤](IDEAS.ko.md#어드벤처-게임-컨트롤)이 있습니다.

- 디버거 (중단점, 한 줄씩 실행, 변수 감시)
- 데이터 바인딩 (VB의 Data 컨트롤)
- 패키지 API를 읽어 컴포넌트 어댑터 자동 생성
- 사용자 정의 클래스
- **셀프 호스팅:** GuBASIC IDE의 일부를 GuBASIC으로 다시 그리기

---

## 1.0에서 *하지 않을* 것

이 목록을 적어 두는 것이 사이드 프로젝트를 끝까지 가게 합니다.

- 클래스 상속, 사용자 정의 클래스 없음
- 데이터 바인딩 / Data 컨트롤 없음
- 오류 줄 강조 이상의 디버거 없음
- `On Error`, `GoTo` 없음
- 컨트롤 배열 없음
- `Variant` 없음
- 한글(비ASCII) 식별자 없음
- 플러그인 마켓 없음
