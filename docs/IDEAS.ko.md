# 아이디어

[English](IDEAS.md)

간직할 만하지만 아직 어느 단계도 맡지 않은 아이디어입니다. 여기 있는 것은 결정된 것도 계획된 것도 아닙니다. 작성자가 고를 때에만 아이디어가 계획과 결정을 갖추고 ROADMAP으로 옮겨 갑니다.

---

## 어드벤처 게임 컨트롤

**목표:** 포인트 앤 클릭 어드벤처 게임을 만들 수 있는 컨트롤 묶음. 어떤 장소의 그림, 그 안에서 살펴보고 누를 것들, 그곳을 걸어 다니는 캐릭터, 말을 거는 사람들, 그리고 다른 것에 쓸 물건이 든 가방이 들어갑니다. Visual Basic 6에는 이런 것이 없었습니다. 이 컨트롤이 있으면 누구나 글자를 치는 대신 그리고 누르는 게임을 만들 수 있습니다.

**시기:** 3단계 이후의 후보입니다. 2단계 계획과 프로젝트 묶음 형식(STAGE2_PLAN.ko.md)은 바꾸지 않습니다.

### 후보

| 컨트롤 | 하는 일 |
|---|---|
| **Scene** | 장소. 폼을 채우는 배경 그림과, 한 장면에서 다른 장면으로 넘어가기(예: 서서히 바뀌기). 게임은 장면의 모음 |
| **Hotspot** | 장면 안의 보이지 않는 누를 곳. 마우스를 올리면 이름이 보임("낡은 문"). 이벤트: `Click`, `MouseEnter`, `MouseLeave` |
| **Sprite** | 여러 장의 그림을 차례로 보여 주는 캐릭터(왼쪽, 오른쪽, 앞, 뒤로 걷기). `WalkTo x, y`로 그곳까지 걸어가며 방향에 맞는 그림을 고르고, 도착하면 `Arrived` 이벤트가 옴 |
| **Dialog** | 스프라이트 위의 말풍선과, 다음 대사로 이어지는 플레이어의 선택지 목록 |
| **Inventory** | 플레이어의 가방. 가지고 있는 물건의 그림. 가방에서 끌어 Hotspot, Sprite, 다른 물건 위에 놓으면 무엇을 무엇에 썼는지 알리는 이벤트(`UseOn`)가 옴 |

### 먼저 있어야 할 것

- **Timer**(STAGE2_PLAN 2-9 단계): 걷기, 애니메이션, 장면 전환은 틱마다 조금씩 움직입니다.
- **키 이벤트**(2-10 단계): 키보드로 움직이거나 대사를 넘깁니다.
- **여러 폼, 또는 장면**(2-7, 2-8 단계): 게임은 장소를 옮겨 다닙니다. Scene을 폼 위에 만들지 따로 둘지는 그때 정합니다.
- **그림 여러 장 다루기:** 스프라이트가 걸으려면 방향마다 차례가 있는 그림 묶음(프레임)이 필요합니다. 지금 프로젝트의 그림은 한 장씩이므로(LANGUAGE §11.3), 그림을 묶는 방법이 먼저입니다.

### 기존 도구는 어떻게 하나: Adventure Game Studio

이런 게임을 만들기 위한 도구인 Adventure Game Studio(AGS)는 위 후보와 맞아떨어지는 몇 가지 개념으로 게임을 짭니다.

- **방(Room):** "게임은 여러 개의 방으로 이루어지고, 플레이어는 그 사이를 옮겨 다닌다", "방 하나는 자기 배경, 핫스팟, 오브젝트를 가진 화면 하나다"([AGS 매뉴얼 2부](https://adventuregamestudio.github.io/ags-manual/v3/acintro2.html)). → Scene
- **핫스팟, 오브젝트, 캐릭터:** 플레이어가 상호작용할 수 있는 세 가지입니다. "핫스팟은 플레이어가 살펴보고 상호작용할 수 있는 배경 그림의 한 영역"이고, 바뀌지 않는 부분에 씁니다. 오브젝트는 "화면에서 움직이고, 켜고 끌 수 있다"([3부](https://adventuregamestudio.github.io/ags-manual/v3/acintro3.html), [4부](https://adventuregamestudio.github.io/ags-manual/v3/acintro4.html)). → Hotspot. 오브젝트 역할은 이미 Image가 합니다.
- **인벤토리:** "게임의 캐릭터마다 자기 인벤토리 물건을 가지고 다닐 수 있다". 방 안의 오브젝트와는 따로 만듭니다([5부](https://adventuregamestudio.github.io/ags-manual/v3/acintro5.html)). → Inventory
- **뷰와 루프:** "뷰는 하나 이상의 루프의 모음이다. 루프는 차례로 보여 주면 움직이는 것처럼 보이는 프레임의 모음이다". 캐릭터가 걷는 데 씁니다([7부](https://adventuregamestudio.github.io/ags-manual/v3/acintro7.html)). → Sprite와, 그것이 필요로 하는 그림 묶음
- **대화:** 고정된 대사 한 줄부터 "이야기할 주제를 고를 수 있는 완전한 대화 트리"까지([8부](https://adventuregamestudio.github.io/ags-manual/v3/acintro8.html)). → Dialog
- **커서 모드:** 마우스 커서마다 상호작용하는 방식이 다르고, 그 가운데 "걸어가기"가 있으며, 물건을 고르면 "인벤토리 쓰기"가 됩니다([9부](https://adventuregamestudio.github.io/ags-manual/v3/acintro9.html)). GuBASIC은 포인터를 하나로 두는 쪽이 낫습니다: 누르면 걸어가거나 살펴보고, 가방에서 물건을 끌어 씁니다.

GuBASIC답게 지킬 것: 컨트롤은 디자이너에서 폼 위에 그리고, 게임은 GuBASIC의 다른 모든 것처럼 이벤트 처리기로 씁니다(`hsDoor_Click`, `sprHero_Arrived`, `invKey_UseOn`).

---

## 실시간으로 함께: WebSocket과 Room

**목표:** 사용자들이 폰으로 들어와 실시간으로 퀴즈를 풀고, TV 화면에 점수와 캐릭터가 경쟁하듯 움직이는 앱. 이런 Visual Basic 6 프로그램은 Winsock 컨트롤로 이야기했고, 메시지가 오면 `DataArrival` 이벤트가 알려 주었습니다([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa228119(v=vs.60))). 이것은 그 요즘 판입니다. 방향은 정했고(DESIGN D122), 이 절에는 비교, 규칙, 열린 질문을 둡니다.

**언제:** v0.5의 Http와 JSON 다음, v0.6 "함께 쓰기"([로드맵](ROADMAP.ko.md)).

### 보편적인 방식, 그리고 그 까닭

- **WebSocket**([RFC 6455](https://www.rfc-editor.org/rfc/rfc6455))은 양방향 연결을 열어, 브라우저가 계속 묻지 않아도 서버가 메시지가 생기는 즉시 보낼 수 있게 합니다([MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)). 모든 브라우저, Dart(`dart:io`와 [web_socket_channel](https://pub.dev/packages/web_socket_channel)), 흔히 쓰는 모든 서버 언어에 있습니다. HTTP 폴링은 실시간이 아닌 일(순위판, v0.5)에만 씁니다.
- **`wss`**, TLS 위의 WebSocket: HTTPS로 받은 웹 앱은 그냥 `ws://` 연결을 열 수 없습니다([MDN, 혼합 콘텐츠](https://developer.mozilla.org/en-US/docs/Web/Security/Mixed_content)).
- **JSON** 메시지([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)): 어떤 프로그램이든 읽고 쓸 수 있습니다.

### 두 층

**아래층: `WebSocket`.** 어떤 표준 WebSocket 서버에도 연결합니다.

```vb
Sub Form_Load()
    wsQuiz.Connect("wss://example.org/quiz")
End Sub

Sub wsQuiz_Connected()
    wsQuiz.Send(Json.Text(answer))
End Sub

Sub wsQuiz_Message(e As MessageEventArgs)
    lblLast.Caption = e.Text
End Sub
```

멤버: `Connect(url)`, `Send(text)`, `Close()`, `State`. 이벤트: `Connected`, `Message`, `Closed`, `Error`. (후보 문법이며, JSON 도우미는 v0.5에서 옵니다.)

**위층: `Room`.** 같은 방 코드를 가진 사람끼리, 중계 서버를 거쳐 이야기합니다.

```vb
' TV에서
Sub Form_Load()
    rmQuiz.Create()                 ' 이제 rmQuiz.Code는 예를 들어 "K7QPXM"
    lblCode.Caption = rmQuiz.Code
End Sub

Sub rmQuiz_Joined(e As RoomEventArgs)
    lstPlayers.AddItem(e.Nickname)
End Sub

Sub rmQuiz_Message(e As RoomEventArgs)
    ' e.From, e.Nickname, e.Text
End Sub

' 폰에서
Sub btnJoin_Click()
    rmQuiz.Join(txtCode.Text, txtNickname.Text)
End Sub
```

멤버: `Create()`, `Join(code, nickname)`, `Send(text)`(모두에게), `SendTo(member, text)`, `Leave()`, `Code`, `Members`. 이벤트: `Joined`, `Left`, `Message`, `Closed`, `Error`.

**메시지 형식은 공개합니다.** 만들 때 따로 한 쪽으로 써서, GuBASIC이 아닌 프로그램도 같은 방에 들어올 수 있게 합니다. 초안은 이렇습니다(WebSocket 메시지 하나에 JSON 객체 하나).

| 방향 | 메시지 |
|---|---|
| 프로그램 → 서버 | `{"type":"create"}`, `{"type":"join","room":"K7QPXM","nickname":"민지"}`, `{"type":"send","data":"…"}`, `{"type":"sendTo","to":"m3","data":"…"}`, `{"type":"leave"}` |
| 서버 → 프로그램 | `{"type":"created","room":"K7QPXM","you":"m1"}`, `{"type":"joined","member":"m3","nickname":"민지"}`, `{"type":"left","member":"m3"}`, `{"type":"message","from":"m3","data":"…"}`, `{"type":"closed","reason":"host left"}`, `{"type":"error","code":"room-not-found"}` |

### 서버를 어디서 돌리나: 세 방식 비교

| | 한 사람의 노트북을 서버로 | 외부 서비스(Firebase 등) | 직접 운영하는 중계 서버(권장) |
|---|---|---|---|
| 방법 | TV 쪽 컴퓨터가 포트를 열고, 폰이 그 주소로 연결 | 앱이 호스팅된 데이터베이스에 쓰고, 그것이 바뀐 것을 밀어 줌([Firebase Realtime Database](https://firebase.google.com/docs/database)) | 이 저장소에 둔 작은 서버가 방 안에서 메시지를 전달 |
| 좋은 점 | 서버도, 계정도, 비용도 없음 | 운영할 것이 없고, 규모가 커져도 됨 | 표준 WebSocket이라 누구나 연결할 수 있음. 아무것도 남기지 않음. 누구나 직접 돌릴 수 있음 |
| 나쁜 점 | 회사나 학교 네트워크는 들어오는 연결을 막거나 기기끼리 서로 못 보게 하는 경우가 많고, 모바일 데이터의 폰은 내부 주소에 닿지 못함. HTTPS로 받은 웹 앱은 `ws://`를 열 수 없고, Chrome은 공개 페이지가 내부 주소에 닿는 것을 막음([Chrome](https://developer.chrome.com/blog/private-network-access-update)). 내부 주소용 인증서는 얻기 어려움 | 앱마다 계정과 키가 필요함(앱에 비밀을 넣지 않으므로(하드 규칙 12) 보안 규칙이 그 일을 해야 함). 서비스 고유의 프로토콜이라 남이 쓸 수 있는 WebSocket이 아님. 메시지가 제3자에게 저장됨. 쓸수록 비용이 늘어남 | 누군가 운영하고 비용을 내야 하며, 남용을 막아야 함 |
| 맞는 경우 | 나중에, 한 네트워크 안의 데스크톱 앱끼리의 선택지 | 이미 그 서비스를 쓰는 사용자: `Firebase` 컴포넌트가 로드맵에 있음 | `Room`의 기본 |

**결정(D123):** 중계 서버, 그리고 무엇보다 사용자의 자기 서버에서. 안내, 설치 스크립트, 그대로 쓰는 Apache 설정 예와 함께 와서 Linux 서버에 명령 몇 줄로 올릴 수 있게 하고, `Room.Server`로 그 서버를 가리킵니다. ~~프로젝트도 공개 서버를 두지만 `Room`을 시험해 보는 용도로만 둡니다.~~ D136에서 바뀜: 공개 시험 서버는 두지 않습니다. 문서는 `relay.example.com`을, 테스트는 `localhost`를 쓰고, 데스크톱 IDE가 그 컴퓨터에 자기 중계 서버를 켭니다.

**만드는 기술:** Dart(`dart:io`의 `HttpServer`와 그 WebSocket 업그레이드, [Dart](https://api.dart.dev/dart-io/HttpServer-class.html)). GuBASIC을 쓴 언어라서 나중의 "GuBASIC 서버"와 코드를 나눌 수 있습니다. 흔한 다른 선택은 Node.js와 [ws](https://github.com/websockets/ws)입니다.

**배치:** Linux에서 중계 서버는 서비스로 돌며 `localhost`에서만 듣습니다. 앞에 둔 Apache가 TLS를 맡고([Let's Encrypt](https://letsencrypt.org/getting-started/) 인증서), 리버스 프록시로 WebSocket 업그레이드를 넘깁니다(`upgrade=websocket`을 쓴 `mod_proxy`, 또는 `mod_proxy_wstunnel`: [Apache](https://httpd.apache.org/docs/2.4/mod/mod_proxy_wstunnel.html)). 정확한 설정을 적은 쪽은 서버와 함께 씁니다.

### 개인 정보

- **이름 대신 별명.** `Join`은 별명을 받고, 서버는 다른 것을 묻지 않습니다.
- **아무것도 남기지 않음.** 방은 서버 메모리에만 있고, 방이 끝나면(만든 사람이 나가거나, 한동안 아무도 보내지 않으면) 그 방의 모든 것이 사라집니다. 서버는 메시지를 기록하지 않습니다.
- **추측할 수 없는 방 코드:** 안전한 난수 생성기로, 헷갈리는 글자(`0`/`O`, `1`/`I`)를 뺀 알파벳에서 여섯 글자를 골라 약 10억 가지입니다. 비밀번호 추측을 막듯 주소마다 들어오기 시도를 제한하고([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)), 방은 시간이 지나면 끝납니다. 모두 들어온 뒤 만든 사람이 방을 잠글 수도 있습니다.

### 질문: 권장안대로 결정함(D123), 그 뒤 D136이 바꿈

D136(v0.6 계획서)이 답 셋을 바꿨습니다: `Connect`, `Create`, `Join`은 `Http`처럼 기다림(1). 트레이 컨트롤만, `New`는 아직 없음(3). `ws://`는 막지 않고 경고(8). 5의 제한은 D136의 것으로 바뀝니다(방 하나에 50명, 공개 서버 없음).

1. **기다리기:** `Connect`와 `Join`은 바로 돌아오고 이벤트가 결과를 알려 줄까요(권장: Winsock처럼 이벤트), 아니면 프로그램이 기다릴까요? v0.5에서 Http에 내린 답을 따릅니다.
2. **글 또는 객체:** `Send`는 글을 받고 v0.5의 JSON 도우미가 그 글을 만들까요(권장), 아니면 `Send`가 구조를 바로 받을까요?
3. **트레이 컴포넌트 또는 `New`:** `Room`과 `WebSocket`을 Timer처럼 디자이너의 트레이에 두고 속성 창에서 `Server`, `Nickname`을 정하게 할까요(권장)? `New`로도 만들 수 있게 합니다.
4. **방 코드:** 위와 같은 여섯 글자(권장), 또는 폰에서 치기 쉬운 숫자만(대신 가짓수가 훨씬 적음).
5. **제한.** 중계 서버의 기본값(서버 주인이 바꿀 수 있음): 방 하나에 100명, 메시지 하나에 16KB, 한 사람이 1초에 20개, 30분 동안 조용하면 방을 끝냄. 시험용인 프로젝트의 공개 서버(D123): 동시에 방 20개, 방 하나에 10명, 메시지 하나에 4KB, 방은 15분 뒤에 끝남.
6. **만든 사람이 나가면:** 방이 끝날까요(권장: 아무것도 남지 않음), 아니면 다른 사람이 이어받을까요?
7. **연결이 끊기면:** 30초 동안 저절로 다시 연결하며 자리를 지킬까요(권장), 아니면 바로 `Closed`일까요?
8. **그냥 `ws://`:** 개발하는 동안 `localhost`에만 허용(권장).
9. **테스트:** 동일성 프로그램용 메모리 안의 중계 서버를 두어, 방의 기록이 VM, Chrome, 실행 창에서 같게 할까요(권장)?

---

## GuBASIC 서버

**목표:** 화면 없는 GuBASIC 프로그램을 서버에서 돌려, 게시판이나 퀴즈 서버 같은 서버 쪽 프로그램도 GuBASIC으로 쓰기. ASP.NET Web Forms는 VB에서 폼을 만들듯 웹 페이지를 만들게 했습니다([Microsoft](https://learn.microsoft.com/en-us/aspnet/web-forms/)). 이것은 그 요즘 판입니다. 다만 페이지를 통째로 주고받는 방식이 아니라, 클라이언트는 GuBASIC 웹 앱이고 서버는 표준 HTTP(JSON)와 WebSocket 요청에 답합니다.

**언제:** `Room`(v0.6) 다음의 후보이며, 아직 계획은 아닙니다.

### 먼저 검토할 것

- **Flutter 없이 돌리기:** `gubasic_lang`은 순수 Dart(하드 규칙 1)라서, 인터프리터는 Dart VM에서 `dart:io`의 `HttpServer`([Dart](https://api.dart.dev/dart-io/HttpServer-class.html))와 함께 돕니다. 서버에는 폼이 없는 호스트가 필요합니다. 먼저 작은 서버로 증명합니다.
- **서버에서의 "한 번에 한 처리기":** GuBASIC은 한 번에 처리기 하나만 돌리고, 처리기를 다시 들어가지 않습니다(D5, D28). Node.js도 JavaScript를 스레드 하나로 돌리는데, 입출력을 막히지 않게 기다리며 그동안 다른 요청을 처리해서 응답을 유지합니다([Node.js](https://nodejs.org/en/learn/asynchronous-work/overview-of-blocking-vs-non-blocking)). 선택은 둘입니다. 요청을 하나씩 처리하거나(단순하고 안전하지만 한꺼번에 많이 오면 느림), Node.js처럼 데이터베이스나 네트워크를 기다리는 동안 요청 처리기가 차례를 내주는 것입니다. 뒤의 것은 `Server_Request` 처리기 하나가 여러 요청을 위해 동시에 돈다는 뜻이고, 지금의 하드 규칙 5가 막는 일입니다. "요청마다 따로인 처리기" 같은 별도의 결정이 필요합니다.

### 후보 문법

```vb
Sub Server_Request(req As Request, res As Response)
    If req.Path = "/scores" And req.Method = "POST" Then
        Dim score = Json.Parse(req.Body)
        db.Execute("INSERT INTO scores (nickname, points) VALUES (?, ?)", score("nickname"), score("points"))
        res.Json(db.Query("SELECT nickname, points FROM scores ORDER BY points DESC LIMIT 10"))
    Else
        res.Status = 404
    End If
End Sub
```

- `Request`: `Method`, `Path`, `Query(name)`, `Header(name)`, `Body`. `Response`: `Status`, `Header(name)`, `Text(…)`, `Json(…)`.
- 서버용 데이터베이스: v0.5와 같은 `Database`(SQLite, [sqlite3](https://pub.dev/packages/sqlite3))를 서버의 파일에.
- 서버 쪽 방: `Server_Room…` 이벤트들로, 퀴즈의 규칙을 TV가 아니라 서버에 둘 수 있게.
- 배치: 중계 서버처럼, Linux의 서비스로 Apache 리버스 프록시 뒤에.

### 꼭 다룰 보안

- **입력:** 모든 요청은 쓰기 전에 검사합니다(형식, 길이, 허용된 값). 요청에서 온 것은 아무것도 믿지 않습니다.
- **SQL 주입:** 질의는 값을 매개변수(`?`)로만 받고, 글을 이어 붙여 만들지 않습니다([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)). `&`로 만든 질의는 분석기가 경고합니다.
- **인증:** 비밀번호는 느린 해시로만 저장하고, 세션이나 토큰은 시간이 지나면 끝나며, 시도 횟수를 제한합니다([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)).
- **전송:** Apache를 거쳐 HTTPS로만. 클라이언트 앱에는 비밀을 넣지 않습니다(하드 규칙 12).

---

## UserControl

**목표:** GuBASIC으로 다른 컨트롤과 코드를 묶어 만든 컨트롤을, 다른 GuBASIC 사용자가 자기 도구 상자에 넣어 쓰게 하기. Visual Basic 5와 6이 `UserControl`과 그 위의 컨트롤로 ActiveX 컨트롤을 만든 것과 같습니다([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa263502(v=vs.60))).

**모습:** 폼 디자이너 같은 화면에서 컨트롤을 그리고, 그 속성·메서드·이벤트를 선언합니다. 컴포넌트(`component.yaml`과 GuBASIC 코드)로 저장되어, 분석기와 도구 상자, 속성 창이 다른 컨트롤과 똑같이 다룹니다.

**짝:** 컴포넌트 통로([COMPONENT_CHANNEL.ko.md](COMPONENT_CHANNEL.ko.md)). 그쪽은 Dart를 받아들이고 이쪽은 GuBASIC으로 만들며, 둘 다 같은 도구 상자에 들어갑니다.

**언제:** 컴포넌트 통로 다음.

## Flutter 패키지로 내보내기

**목표:** 트랜스파일러가 생긴 뒤(D79), GuBASIC으로 만든 폼과 UserControl을 어떤 Flutter 앱이든 쓸 수 있는 Dart 위젯 패키지로 내보내기. 그러면 GuBASIC은 Flutter 앱의 한 부분을 그리는 방법도 됩니다.

**언제:** 트랜스파일러 다음.
