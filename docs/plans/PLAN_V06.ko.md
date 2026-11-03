# 계획: v0.6 "함께 쓰기" — WebSocket, Room, 중계 서버, 실시간 퀴즈

[English](PLAN_V06.md)

[PLAN_TEMPLATE.ko.md](../PLAN_TEMPLATE.ko.md)의 틀을 따릅니다. 바탕: DESIGN D121(우회 없음), D122(실시간 통신은 표준 WebSocket, 두 층), D123(답: 중계 서버는 사용자의 서버가 먼저), D124 A(Http는 부른 자리에서 기다림), D125·D126(컴포넌트 통로), IDEAS "Real-time together". 구현 전 계획서입니다. 6절의 질문에 작성자가 2026-11-03에 답했습니다: 모두 권장안대로 하되, Q4의 "같은 네트워크의 기기 허용"은 기본을 꺼 두고 켤 때 경고를 보입니다(3.5절). 구현은 Q10의 순서로 하며, 단계마다 PR 하나씩 확인 후 병합합니다.

주소 규칙(CLAUDE.md): 이 문서와 v0.6의 모든 파일에서 서버 주소는 문서용 예약 주소 `relay.example.com`만 쓰고, 테스트와 IDE의 로컬 서버는 `localhost`(`127.0.0.1`)를 씁니다. 같은 네트워크의 주소는 `<이 컴퓨터의 네트워크 주소>`로만 적습니다.

## 1. 무엇을, 왜

**사용자가 할 수 있게 되는 것.** 폼에 `Room`을 놓고 TV 쪽은 `rmQuiz.Create()`, 폰 쪽은 `rmQuiz.Join(code, nickname)`을 부르면, 같은 방 코드를 가진 프로그램끼리 `Send`로 글(JSON)을 주고받고 `Message`, `Joined`, `Left` 이벤트로 받습니다. 표준 WebSocket 서버와는 `WebSocket`으로 직접 이야기합니다. Visual Basic 6이 Winsock 컨트롤로 하던 일의 오늘 판입니다(D122).

가장 작은 예(TV 쪽):

```vb
Sub Form_Load()
    rmQuiz.Create()                       ' 중계 서버에 방을 만들고, 코드가 생길 때까지 기다림
    lblCode.Caption = "방 코드: " & rmQuiz.Code
End Sub

Sub rmQuiz_Joined(e As RoomEventArgs)
    lstPlayers.AddItem(e.Nickname)
End Sub

Sub rmQuiz_Message(e As RoomEventArgs)
    Dim answer As Json = e.Json
    lblLast.Caption = e.Nickname & ": " & answer("choice").AsInteger
End Sub
```

폰 쪽은 `rmQuiz.Join(txtCode.Text, txtNickname.Text)` 뒤 `rmQuiz.Send(answer.Text)`입니다.

**단계.** ROADMAP v0.6 "Together". v0.6이 끝나면 **LiveQuiz** 예제가 있습니다: 폰으로 접속해 푸는 실시간 퀴즈와 TV의 점수판·달리기 화면. 예제와 테스트는 **내 컴퓨터 안의 중계 서버(localhost)** 로 돌고, IDE에서 실행하면 중계 서버가 저절로 켜집니다(3.5절).

**D123에서 바꾸는 것.** "프로젝트의 공개 시험 서버"는 두지 않습니다. 이유: 운영 부담, 그리고 공개 문서가 특정 개인 서버를 가리키지 않게 하기 위함(CLAUDE.md의 새 규칙). 문서와 예제의 주소는 RFC 2606의 예약 주소(`relay.example.com`)뿐이고, 테스트는 `localhost`입니다. 공개 시험 서버는 나중에 필요하면 별도 주소로 다시 정합니다. 이 변경을 D136으로 기록하고 IDEAS·ROADMAP·COMPONENT_CHANNEL의 해당 문장을 고칩니다(en, ko).

## 2. 어떻게 쓰나

### 2.1 `WebSocket` 컨트롤(아래층)

Timer처럼 트레이에 놓는 보이지 않는 컨트롤(`visual: false`). 어떤 표준 WebSocket 서버([RFC 6455](https://www.rfc-editor.org/rfc/rfc6455))와도 글 메시지를 주고받습니다.

| 멤버 | 하는 일 |
|---|---|
| `Connect(url)` | `wss://…` 또는 `ws://…`에 연결하고 **열릴 때까지 부른 자리에서 기다림**(Http처럼, D124 A). 못 열면 R047 |
| `Send(text)` | 글 한 메시지를 보냄. 열려 있지 않으면 R049 |
| `Close()` | 닫음 |
| `State` | `"Closed"`, `"Open"` (읽기만) |
| `Url` | 마지막으로 연결한 주소(읽기만), `Tag` |
| 이벤트 `Message(e As MessageEventArgs)` | 메시지가 옴: `e.Text`, `e.Json`(그때 파싱, JSON이 아니면 R039) |
| 이벤트 `Closed(e As CloseEventArgs)` | 서버가 닫았거나 연결이 끊김: `e.Reason` |
| 이벤트 `Error(e As ErrorEventArgs)` | 연결된 뒤의 오류: `e.Message` |

Winsock의 이름은 GuBASIC의 것으로 안내(D50): `SendData`→`Send`, `DataArrival`→`Message`, `GetData`→`e.Text`, 이벤트 `Connect`는 "Connect는 기다리므로 이벤트가 없다"는 A051 계열 안내.

### 2.2 `Room` 컨트롤(위층)

같은 방 코드를 가진 프로그램들을 중계 서버가 이어 줍니다. 메시지 형식은 공개합니다(`docs/ROOM_PROTOCOL.md`).

| 멤버 | 하는 일 |
|---|---|
| `Server` | 중계 서버 주소(`wss://relay.example.com/room`). 속성 창에서 정함. 비어 있으면 개발 중 IDE의 로컬 서버(3.5절); 내보낸 앱에서 비어 있으면 R048 |
| `Nickname` | 내 별명. 속성 창이나 코드에서 |
| `Create()` | 방을 만들고 코드가 생길 때까지 기다림. 그 뒤 `Code`, `Me` |
| `Join(code, nickname)` | 방에 들어갈 때까지 기다림. 없는 방·꽉 찬 방·잠긴 방은 R048(서버가 말한 이유와 함께) |
| `Send(text)`, `SendTo(member, text)` | 모두에게, 또는 한 사람에게 |
| `Leave()` | 나감. 방장이 나가면 방이 끝남 |
| `Lock()` | 방장만: 더는 못 들어오게 |
| `Code`, `Me`, `IsHost`, `Members`(멤버 ID의 `String` 배열), `Nickname(member)` | 읽기만 |
| 이벤트 `Joined(e)`, `Left(e)` | 다른 사람이 들어오고 나감: `e.Member`, `e.Nickname` |
| 이벤트 `Message(e)` | `e.Member`, `e.Nickname`, `e.Text`, `e.Json` |
| 이벤트 `Closed(e)` | 방이 끝남: `e.Reason`(`"host left"`, `"idle"`, `"server"`) |
| 이벤트 `Error(e)` | 들어간 뒤의 오류(서버가 거부한 메시지 등): `e.Message` |

`e`는 모두 `RoomEventArgs`. 끊긴 연결은 30초 동안 자리를 지키며 스스로 다시 잇고(IDEAS 7), 그동안 `Send`는 줄을 섭니다. 30초 안에 못 이으면 `Closed`.

### 2.3 진단 메시지(초안)

| 코드 | 영어 | 한국어 |
|---|---|---|
| R047 | `No connection to {0} ({1}). Check the address and the network; a page served over https needs wss://.` | `{0} 주소에 연결하지 못했습니다({1}). 주소와 네트워크를 확인해 주세요. https로 열린 페이지는 wss://가 필요합니다.` |
| R048 | `Could not enter the room: {0}. Check the code, and that Room.Server points to a relay server.` | `방에 들어가지 못했습니다: {0}. 코드와, Room.Server가 중계 서버를 가리키는지 확인해 주세요.` |
| R049 | `{0} is not connected, so Send has nowhere to go. Connect or Join first, or wait for Closed to be handled.` | `{0} 컨트롤이 연결되어 있지 않아 Send를 보낼 곳이 없습니다. 먼저 Connect나 Join을 하거나 Closed를 처리해 주세요.` |
| A077(경고) | `ws:// to {0} is not encrypted and a page served over https cannot open it. Use wss:// for anything but localhost or your own network.` | `{0} 주소로의 ws://는 암호화되지 않고, https로 열린 페이지에서는 열리지 않습니다. localhost나 같은 네트워크가 아니면 wss://를 써 주세요.` |
| A078(경고, 내보내기 때) | `Room.Server is empty: the app will have no relay server. Set it to your server's address, as docs/RELAY_SERVER.md says.` | `Room.Server가 비어 있어 앱에 중계 서버가 없습니다. docs/RELAY_SERVER.md대로 자기 서버 주소를 넣어 주세요.` |

### 2.4 LiveQuiz 예제

프로젝트 하나, 폼 셋. 내보낸 웹 앱 하나를 TV와 폰이 함께 씁니다(질문 Q3).

- **FormStart:** "TV로 진행" / "폰으로 참여" 두 버튼.
- **FormTV:** `rmQuiz.Create()` → 큰 글씨의 방 코드, 들어온 사람 목록(`Joined`), "시작" 버튼. 문제마다 `{"kind":"question","no":1,"text":"…","choices":[…],"seconds":15}`를 `Send`하고 Timer로 남은 시간을 그립니다. 답(`{"kind":"answer","no":1,"choice":2}`)이 오면 빠른 순서대로 점수를 주고, `{"kind":"score","board":[…]}`를 보내며, 점수판과 캐릭터 달리기(Image 여러 개의 Left를 점수에 비례해 옮김)를 그립니다. 문제는 Quiz 예제의 `Structure Question` 일곱 문제를 그대로 씁니다.
- **FormPhone:** 코드·별명 입력 → `Join` → 보기 네 개 버튼 → 답을 보내고 "정답!/아쉽네요"와 내 순위를 보여 줍니다.
- 쓰는 것: `Room`, `Json`, `Structure`(Player: Member, Nickname, Score), `Timer`, `List`, `With`.

## 3. 설계

### 3.1 어디에 무엇이

| 곳 | 내용 |
|---|---|
| `components/WebSocket/component.yaml`, `components/Room/component.yaml` | `visual: false`, `platforms: [web, macos, windows]`, 이벤트에 인수 형식(`Message(e As MessageEventArgs)`). 하드 규칙 7 |
| `packages/gubasic_lang/lib/src/components/web_socket_component.dart`, `room_component.dart` | 순수 Dart. 프로토콜 JSON, 상태 기계, 재접속, 제한 검사. 소켓 자체는 `Http`처럼 추상 메서드(`open`, `send`, 받은 메시지 스트림)로 밖에 맡김 |
| `packages/gubasic_lang` 컴포넌트 통로 | **이벤트 경로가 처음 생김.** `ComponentInstance`에 `onEvent(String name, List<Object?> args)` 콜백. 인터프리터는 Timer 틱처럼 줄을 세워 한 번에 하나씩, 다시 들어가지 않게 실행(하드 규칙 4·5). `_parameterTypes`에 `MessageEventArgs`, `CloseEventArgs`, `ErrorEventArgs`, `RoomEventArgs` |
| `packages/gubasic_runtime/lib/src/web_socket.dart` | `GbWebSocket`: [web_socket_channel](https://pub.dev/packages/web_socket_channel)(데스크톱은 `dart:io`, 웹은 브라우저의 WebSocket). 테스트는 가짜 |
| `packages/gubasic_player` | 두 컴포넌트를 통로에 꽂고, 기다리는 포인터(D124 A)를 Http와 같이 씀 |
| `packages/gubasic_relay/` (새 순수 Dart 패키지) | 방 프로토콜의 서버 쪽 `RoomHub`(소켓 없이도 도는 핵심), `dart:io` `HttpServer` 위의 중계 서버, `bin/gubasic_relay.dart`. IDE가 라이브러리로 품고, 설치 스크립트는 `dart compile exe`로 만든 실행 파일을 씀. 나중의 "GuBASIC 서버"가 코드를 나눠 씀(IDEAS) |
| `packages/gubasic_relay/deploy/` | `install.sh`, `relay.yaml.example`, `apache-relay.conf.example`, `gubasic-relay.service` |
| `docs/ROOM_PROTOCOL.md`(+ko), `docs/RELAY_SERVER.md`(+ko) | 메시지 형식, 설치 안내 |
| `examples/livequiz/` | 2.4절 |

### 3.2 중계 서버(`gubasic_relay`)

- **프로토콜(v1):** WebSocket 메시지 하나가 JSON 객체 하나. 첫 메시지는 `{"type":"hello","v":1,"key":"…"}`(key는 서버가 요구할 때만). 그 뒤 IDEAS의 초안대로 `create`, `join`, `send`, `sendTo`, `leave`, `lock`; 서버→프로그램 `created`, `joined`, `left`, `message`, `closed`, `error`(코드: `bad-key`, `room-not-found`, `room-full`, `room-locked`, `too-fast`, `too-big`, `server-full`). `ping`/`pong`은 WebSocket 자체의 것을 씀.
- **방 코드:** 보안 난수, 혼동 글자를 뺀 32자(`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`) 중 6자, 대소문자 구분 없이 받음.
- **경로:** `GET /room`에 WebSocket 업그레이드, `GET /room/health`는 `{"gubasicRelay":"0.6.0","rooms":3}`(메시지·별명은 안 나옴).
- **아무나 못 쓰게 하는 방법(권장 기본값, 모두 `relay.yaml`로 바꿀 수 있음):**

  | 설정 | 기본값 | 뜻 |
  |---|---|---|
  | `bind`, `port` | `127.0.0.1`, `7071` | Apache 뒤에서만 들음 |
  | `maxRooms` | 50 | 서버 전체 동시 방 수. 넘으면 `server-full` |
  | `maxMembers` | 50 | 방 하나의 인원 |
  | `maxMessageBytes` | 16384 | 메시지 크기(UTF-8 바이트). 넘으면 `too-big`, 세 번이면 끊음 |
  | `messagesPerSecond` | 20 | 멤버당. 넘으면 `too-fast`, 계속되면 끊음 |
  | `joinAttemptsPerMinute` | 30 | IP당 `join` 시도. 코드 추측 방지(OWASP) |
  | `idleMinutes`, `maxRoomMinutes` | 30, 360 | 조용한 방·오래된 방을 닫음 |
  | `allowedOrigins` | `[]` | 비어 있으면 모두 허용(개발용). 채우면 브라우저가 보낸 `Origin`이 목록에 없을 때 업그레이드를 거부. 안내서는 자기 웹 앱 주소를 넣으라고 함 |
  | `key` | 없음 | 선택적 접속 암호. 있으면 `hello`의 `key`가 맞아야 함. 웹 앱 안에 그대로 들어가므로 비밀이 아니라 "아무나 못 쓰게 하는 문"이라고 문서에 적음(하드 규칙 12: 서비스 키 경고는 내지 않되, 설명함) |
  | `logMessages` | `false` | 메시지 본문은 기록하지 않음(IDEAS 개인정보) |

  저장하는 것은 없고(메모리뿐), 방이 끝나면 모두 사라집니다.
- **배포(누구의 Linux 서버에나):** `install.sh`가 (1) 릴리스의 `gubasic-relay-linux-x64`(또는 arm64) 실행 파일을 받거나 Dart가 있으면 `dart compile exe`로 만들고, (2) 시스템 사용자 `gubasic-relay`와 `/opt/gubasic-relay`, `/etc/gubasic-relay/relay.yaml`을 만들고, (3) systemd 서비스를 등록해 켜고, (4) Apache에 붙일 조각을 화면에 보여 줍니다(`ProxyPass /room ws://127.0.0.1:7071/room upgrade=websocket`, `mod_proxy_wstunnel`, Let's Encrypt로 받은 인증서). 안내서(`RELAY_SERVER.md`)는 필요한 것, 명령 몇 줄, 확인(`curl https://relay.example.com/room/health`), 업데이트, 제거를 적습니다. 주소는 모두 `relay.example.com`. **실제 서버에 설치하지 않습니다.** 릴리스 워크플로가 `gubasic-relay-linux-x64`와 `-arm64`를 만들어 SHA256SUMS에 넣습니다.

### 3.3 하드 규칙과 열어 두는 것

- 새 문법 없음: 컨트롤과 이벤트는 component.yaml로 들어오므로 AST는 그대로이고 트랜스파일러의 길이 닫히지 않음(하드 규칙 2).
- 이벤트는 핸들러 하나씩, 다시 들어가지 않음(4·5). `Create`/`Join`/`Connect`가 기다리는 동안 화면은 그려지고 중지가 됨(D124 A와 같은 길).
- 폼 파일: Timer처럼 트레이 컨트롤이라 `formatVersion` 변경 없음(8).
- 플랫폼: 셋 다. 놀이터는 없음(R038, KNOWN_ISSUES에 Http·Database와 함께).

### 3.4 테스트에서 중계 서버

IDEAS 9번(동일성 테스트용 메모리 안 중계 서버)대로, `gubasic_relay`의 `RoomHub`를 소켓 없이 프로세스 안에서 씁니다. VM·Chrome·실행 창 세 곳이 같은 코드를 돌리므로 transcript가 같습니다. 이벤트 스크립트(`.events`)에 상대편 줄을 더합니다.

```
Peer 민지 Join            ' 프로그램이 만든 방에 "민지"가 들어옴
Peer 민지 Send {"kind":"answer","no":1,"choice":2}
Peer 민지 Leave
Room Close idle           ' 서버가 방을 닫음
```

transcript에는 `Room: create K7QPXM`(테스트에서는 코드 생성기를 고정), `Room: send {…}`, `Room: sendTo m2 {…}`가 남습니다. 실제 소켓은 (1) `gubasic_relay`의 자체 테스트(localhost에 진짜 WebSocket 여러 개), (2) `GbWebSocket` 테스트(`dart:io` 서버 하나), (3) IDE 통합 테스트(FormTV를 실행하고 스크립트 폰이 내장 중계 서버에 접속)에서 확인합니다.

### 3.5 IDE에서 쉽게 켜기(권장안)

- **자동:** 데스크톱 IDE는 `Room.Server`가 빈 프로그램이 실행되면 내장 `gubasic_relay`를 `127.0.0.1`의 빈 포트에 켜고 출력 창에 `Room 서버: ws://127.0.0.1:53421/room (이 컴퓨터만)`을 적습니다. IDE가 켜져 있는 동안 포트를 유지하고, 프로그램을 다시 실행해도 방은 새로 만듭니다.
- **같은 Wi-Fi의 폰:** 실행 메뉴의 체크 항목 **"같은 네트워크의 기기 허용"**. **기본은 꺼짐**이고 IDE를 다시 켜도 꺼진 채 시작합니다. **꺼져 있으면 중계 서버는 localhost(`127.0.0.1`)에서만 받고, 켰을 때만 같은 네트워크 주소에서도 받습니다**(모든 인터페이스에 다시 듣고, 출력 창에 `Room 서버: ws://<이 컴퓨터의 네트워크 주소>:53421/room (같은 네트워크)`를 적음). 켜는 순간 경고를 보입니다: "같은 네트워크의 다른 기기가 이 컴퓨터의 중계 서버에 접속할 수 있습니다. 공용 네트워크에서는 켜지 마세요." (확인/취소. 취소하면 켜지지 않음). 폰 쪽 프로그램은 그 주소를 `Server`에 넣습니다. 끄면 바로 localhost만 다시 듣고, 다른 기기의 연결은 끊습니다.
- **폰에 앱을 주는 길:** 폰에는 웹 앱이 필요합니다. 권장: 같은 메뉴의 **"웹으로 미리 보기"** 가 현재 프로젝트를 내보내기와 같은 방법(웹 플레이어 틀 + project.gbz)으로 만들어 같은 주소에서 `http://<이 컴퓨터의 네트워크 주소>:53421/`로 서비스하고 QR 코드를 보여 줍니다(토글이 꺼져 있으면 `http://localhost:53421/`뿐이고, QR 코드는 토글을 켜라고 안내함). 페이지가 `http`이므로 `ws://`가 막히지 않습니다. `Room.Server`가 비어 있으면 미리 보기 앱은 자기를 서비스한 호스트의 `/room`을 씁니다. (Q4. 이것이 없으면 폰 확인은 내보낸 웹 앱을 따로 올려야 합니다.)
- **웹 IDE:** 브라우저는 서버를 열 수 없으므로 로컬 중계 서버가 없습니다. `Server`가 비면 R048 메시지가 "데스크톱 IDE를 쓰거나 Room.Server를 정하라"고 말하고, KNOWN_ISSUES에 적습니다.

## 4. 우회 없음(D121)

- **아직 돌아가야 하는 곳:** 이진 메시지(글만. 그림은 Base64 글로 가능하므로 나중), WebSocket에 보낼 헤더(브라우저가 허용하지 않아 표준 안에서 불가능. 토큰은 URL의 쿼리나 첫 메시지로), TCP/UDP(웹에 없음. 트랜스파일러 뒤의 컴포넌트 후보), 같은 네트워크 안 직접 연결(IDEAS의 "나중 선택지"), 서버 쪽 규칙(GuBASIC 서버, 다음 단계). 모두 KNOWN_ISSUES.
- **표준:** WebSocket RFC 6455, wss는 TLS, JSON RFC 8259, Origin은 RFC 6454, 설정 파일은 YAML.
- **들어오는 길:** 둘 다 컴포넌트 통로의 컴포넌트이고, 처음으로 **이벤트가 있는 컴포넌트**라 통로가 완성됩니다(COMPONENT_CHANNEL 2단계).
- **문서와 예제:** LANGUAGE 11.11 WebSocket, 11.12 Room(+ko), ROOM_PROTOCOL.md, RELAY_SERVER.md, 레퍼런스의 두 컨트롤 페이지(생성), llms-full.txt(생성), 예제 LiveQuiz, FIRST_APP에는 넣지 않음.

## 5. 테스트

- 동일성(`test/parity/`): `websocket_basics`(가짜 서버 스크립트 `.ws`: Http의 `.http`처럼 보낼 답을 적음), `room_basics`(Create, Peer Join/Send/Leave, Closed), `room_errors`(없는 방, 꽉 찬 방, 너무 큰 메시지), `room_reconnect`(끊김 뒤 30초 안 복구), VM·Chrome·실행 창.
- `gubasic_relay`: 제한마다 하나씩(방 수, 인원, 크기, 속도, Origin, key, idle), 두 클라이언트가 실제 소켓으로 주고받기, health.
- `gubasic_runtime`: `GbWebSocket`(연결·보내기·닫힘·오류).
- IDE: 로컬 중계 서버 자동 시작과 출력 줄, "같은 네트워크" 토글(기본 꺼짐, 꺼진 동안은 localhost에서만 받음, 켤 때 경고가 보이고 취소하면 켜지지 않음, 켠 뒤에만 다른 주소에서 받음), 내보내기 때 A078. 통합 테스트(Windows·macOS 둘 다 CI에서): FormTV + 스크립트 폰.
- 손으로(Playwright, 웹): 빌드한 웹 플레이어로 LiveQuiz를 브라우저 컨텍스트 둘(TV, 폰)에 띄우고 로컬 중계 서버로 한 판을 끝까지 돕니다. 맥은 저자의 마우스·키보드를 쓰지 않는 방법만.

## 6. 질문과 답(2026-11-03)

작성자의 답: **열 질문 모두 권장안대로.** Q4만 아래와 같이 덧붙였습니다.

**Q1. 기다림.** `Connect`, `Create`, `Join`이 Http처럼 부른 자리에서 기다리고(화면은 그려지고 중지가 됨), 실패는 Try로 잡는 R 오류로 할까요? 아니면 IDEAS 1번의 원래 권장대로 바로 돌아오고 `Connected`/`Created` 이벤트로 알릴까요?
권장: **기다림.** D123(1)이 "Http의 답을 따른다"고 했고 D124 A가 기다림을 골랐습니다. 초보자가 `Form_Load`에서 `Create()` 다음 줄에 `lblCode.Caption = rmQuiz.Code`를 쓸 수 있습니다.
**답:** 권장안대로, 기다림.

**Q2. 컨트롤의 모양.** Timer처럼 트레이 컨트롤로만 둘까요, `New Room`도 허용할까요?
권장: **트레이 컨트롤만.** 속성 창에서 `Server`·`Nickname`을 정하고 이벤트는 더블클릭으로 만듭니다. `New`는 필요가 보일 때.
**답:** 권장안대로, 트레이 컨트롤만.

**Q3. 예제의 꼴.** LiveQuiz를 프로젝트 하나(역할 고르는 첫 폼 + TV 폼 + 폰 폼)로 할까요, TV와 폰 프로젝트 둘로 나눌까요?
권장: **하나.** 내보낸 웹 앱 하나를 TV와 폰이 함께 쓰므로 주소가 하나이고, 예제도 하나입니다.
**답:** 권장안대로, 프로젝트 하나.

**Q4. IDE의 로컬 서버.** (a) `Server`가 비면 자동으로 켜고 출력에 주소를 적기, (b) "같은 네트워크의 기기 허용" 토글, (c) "웹으로 미리 보기"(현재 프로젝트를 웹 앱으로 같은 주소에서 서비스하고 QR 코드). 셋 다 v0.6에 넣을까요?
권장: **셋 다.** (c)가 없으면 폰으로 해 보려면 웹 앱을 어딘가에 올려야 해서, "내 컴퓨터 안에서 돈다"가 TV 쪽에서 끝납니다. (c)는 내보내기 코드와 웹 템플릿을 그대로 쓰므로 크기가 작습니다. 다만 (c)는 순서의 맨 뒤에 두고, 시간이 모자라면 v0.6.1로 미룹니다.
**답:** 셋 다. 다만 (b) "같은 네트워크의 기기 허용"은 **기본을 꺼 둔다.** 꺼져 있으면 localhost에서만 받고, 켰을 때만 같은 네트워크 주소에서 받는다. 켤 때 "같은 네트워크의 다른 기기가 이 컴퓨터의 중계 서버에 접속할 수 있습니다. 공용 네트워크에서는 켜지 마세요." 같은 경고를 보인다(3.5절에 반영).

**Q5. 중계 서버의 자리와 이름.** `packages/gubasic_relay`(순수 Dart, IDE가 라이브러리로 품음)와 실행 파일 `gubasic-relay`, 릴리스 자산 `gubasic-relay-linux-x64`·`-arm64`로 할까요?
권장: **예.** `apps/`는 Flutter 앱의 자리이고, 라이브러리여야 IDE가 품고 테스트가 소켓 없이 씁니다.
**답:** 권장안대로.

**Q6. 제한의 기본값.** 3.2절의 표(방 50, 인원 50, 16 KB, 초당 20, IP당 분당 30회 join, 30분 idle, 6시간, Origin 목록은 비면 모두 허용, key는 선택)로 할까요?
권장: **예.** 교실 한 반(30~40명)과 학년 행사(방 몇 개)를 서버 하나가 감당하고, 자기 서버이니 더 올리는 것은 설정 한 줄입니다. `allowedOrigins`가 비어 있을 때의 "모두 허용"은 안내서가 첫 단계에서 채우라고 말합니다.
**답:** 권장안대로.

**Q7. 방 코드.** 혼동 글자를 뺀 32자 중 6자(대소문자 무시)로 할까요, 폰에서 치기 쉬운 숫자 6자리로 할까요?
권장: **32자 중 6자.** 숫자 6자리는 백만 가지뿐이라 분당 30회 제한이 있어도 코드 추측이 현실적입니다. 폰 입력 칸은 자동으로 대문자로 바꿉니다.
**답:** 권장안대로, 32자 중 6자.

**Q8. ws:// 규칙.** GuBASIC이 막지 않고 분석기 경고(A077)만 낼까요(localhost와 사설 네트워크의 주소([RFC 1918](https://www.rfc-editor.org/rfc/rfc1918))는 경고 없음)?
권장: **경고만.** 같은 네트워크 토글(Q4 b)이 `ws://`로 같은 네트워크의 주소를 쓰고, https 페이지에서 `ws://`를 막는 것은 브라우저가 이미 합니다.
**답:** 권장안대로, 경고만.

**Q9. D136 기록 시점.** D123의 변경(공개 시험 서버 없음)과 3.1~3.5의 설계를 D136으로 지금 기록하고 IDEAS·ROADMAP·COMPONENT_CHANNEL(en, ko)을 고치는 것을 v0.6의 첫 커밋으로 할까요?
권장: **예.** 이후 PR들이 D136을 가리키면 됩니다.
**답:** 권장안대로, 첫 커밋.

**Q10. 순서.** (1) D136과 문서 → (2) 컴포넌트 통로의 이벤트 + `WebSocket` → (3) `gubasic_relay`(RoomHub, 프로토콜, 자체 테스트) → (4) `Room` + 동일성 테스트 → (5) IDE 로컬 서버(Q4 a·b) → (6) LiveQuiz + Playwright → (7) 설치 안내서·스크립트·릴리스 자산 → (8) 웹 미리 보기(Q4 c) → v0.6.0. 이 순서로 할까요? 단계마다 PR 하나씩, 확인 후 병합.
권장: **예.** (2)에서 통로의 이벤트가 먼저 증명되고, (3)은 Flutter 없이 돌아 빨리 확인됩니다.
**답:** 권장안대로, 이 순서.
