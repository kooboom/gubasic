# GuBASIC 로드맵

[English](ROADMAP.md)

각 단계는 실제로 돌아가는 무언가로 끝납니다. 끝내지 못한 큰 단계보다 끝낸 작은 단계가 낫습니다.

---

## 0단계 — 설계 (현재)

- [x] 설계 결정 ([DESIGN.ko.md](DESIGN.ko.md))
- [x] 언어 초안 ([LANGUAGE.ko.md](LANGUAGE.ko.md))
- [ ] 저장소 준비: 라이선스, `dart test`를 돌리는 CI

## 1단계 — 그리고, 더블클릭하고, 실행하기

IDE 안에서 완결되는 비주얼 베이직의 핵심 경험입니다.

- [ ] 맥용 IDE 뼈대 (윈도우 빌드도 계속 유지)
- [ ] 폼 디자이너: 도구상자, 캔버스, 끌어 놓기·크기 조절, 속성 창
- [ ] 기본 컴포넌트: `Form`, `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`, `Image`
- [ ] `Anchor`가 있는 절대 배치; 폼 크기 프리셋 (폰 / 태블릿 / 데스크톱)
- [ ] 일반 텍스트 프로젝트 파일 (`.gbproj`, `.form.yaml`, `.gbas`)
- [ ] 렉서와 **오류에 강한** 파서
- [ ] 코드 편집기: 구문 강조, 더블클릭 → 처리기 뼈대, 이름을 바꿔도 안전한 처리기
- [ ] 가벼운 자동완성 (키워드, 컨트롤, 멤버, "혹시 이것인가요")
- [ ] **비동기 인터프리터**; F5로 IDE 안에서 앱 실행
- [ ] `MsgBox`, `InputBox`, `DoEvents`, `Settings`, `Try…Catch`
- [ ] 실행 중 오류를 줄 강조와 쉬운 설명으로 표시 (영어 / 한국어)

**완료 기준:** 초보자가 Flutter를 설치하지 않고 작은 퀴즈 앱을 만들어 실행할 수 있다.

## 2단계 — 진짜 앱 만들기

- [ ] 트랜스파일러: GuBASIC → Dart → Flutter 프로젝트
- [ ] macOS, Windows, Android, 웹 빌드
- [ ] CI에서 도는 **동일성 테스트 묶음** (인터프리터 대 트랜스파일러)
- [ ] 첫 빌드 때 Flutter SDK 자동 내려받기
- [ ] 클라우드 빌드용 GitHub Actions 템플릿
- [ ] 레이아웃: `LayoutMode` (세로 / 가로 / 격자), `Dock`
- [ ] `Handles` 절; 실행 중 컨트롤 생성
- [ ] `Database` (SQLite)와 `Http` + JSON
- [ ] 여러 폼과 플랫폼별 `Form2.Show` 동작
- [ ] `ByRef`

**완료 기준:** 프로젝트 하나를 네 플랫폼에 출시할 수 있다.

## 3단계 — 생태계

- [ ] iOS 빌드
- [ ] 폰용 **GuBASIC Player**
- [ ] `component.yaml` 어댑터를 통한 pub.dev 추가 컴포넌트
- [ ] `Supabase`, `Firebase` 컴포넌트; 비밀 키 경고
- [ ] 게시 메뉴: Vercel, Firebase Hosting, GitHub Pages, 개인 서버
- [ ] 화면 크기별 레이아웃 덮어쓰기
- [ ] 타입을 아는 자동완성
- [ ] Dart 코드 삽입(비상구)

## 1.0 이후 (아이디어)

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
