# 방 프로토콜(버전 1)

[English](ROOM_PROTOCOL.md)

프로그램이 GuBASIC 중계 서버와 이야기하는 방법입니다(DESIGN D122, D136). GuBASIC의 `Room` 컨트롤이 이것으로 말하고, GuBASIC으로 쓰지 않은 프로그램도 방에 들어올 수 있도록 공개합니다. 서버는 `packages/gubasic_relay`이고, 자기 서버에 올리는 방법은 [RELAY_SERVER.ko.md](RELAY_SERVER.ko.md)에 있습니다.

## 연결

- 서버의 `/room`으로 가는 WebSocket([RFC 6455](https://www.rfc-editor.org/rfc/rfc6455)): TLS가 있는 웹 서버 뒤라면 `wss://relay.example.com/room`, 자기 컴퓨터라면 `ws://127.0.0.1:7071/room`.
- WebSocket 글 메시지 하나가 `"type"`이 있는 JSON 객체([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)) 하나입니다. 이진 메시지는 연결을 닫습니다.
- ping과 pong은 WebSocket 자체의 것을 씁니다. 서버는 25초마다 ping을 보냅니다.
- 웹 브라우저가 연 페이지는 `Origin`([RFC 6454](https://www.rfc-editor.org/rfc/rfc6454))을 보냅니다. `allowedOrigins`를 채운 서버는 다른 페이지의 업그레이드를 거부합니다(403).
- `GET /room/health`는 `{"gubasicRelay":"0.6.0","rooms":3}`로 답합니다. 코드, 별명, 메시지는 나오지 않습니다.

## 프로그램 → 서버

| 메시지 | 언제 |
|---|---|
| `{"type":"hello","v":1}` | 언제나 맨 처음. 서버가 요구하면 `"key":"…"`도 |
| `{"type":"create","nickname":"TV"}` | 방을 만듦. 프로그램이 방장. `nickname`은 빼도 됨("host") |
| `{"type":"join","room":"K7QPXM","nickname":"민지"}` | 방에 들어감. 코드는 대소문자를 가리지 않고, 빈칸과 `-`는 빼고 읽음 |
| `{"type":"send","data":"…"}` | 방의 다른 모두에게 |
| `{"type":"sendTo","to":"m3","data":"…"}` | 멤버 한 사람에게 |
| `{"type":"leave"}` | 방에서 나감. 방장이 나가면 방이 끝남 |
| `{"type":"lock"}` | 방장만: 더는 아무도 못 들어옴 |
| `{"type":"resume","room":"K7QPXM","member":"m3","token":"…"}` | 연결이 끊긴 뒤 서버의 `reconnectSeconds`(30) 안에 새 연결로 돌아옴 |

`data`는 글입니다. GuBASIC 프로그램은 그 안에 JSON을 넣지만 서버는 읽지 않습니다. 별명은 1~40자입니다.

## 서버 → 프로그램

| 메시지 | 언제 |
|---|---|
| `{"type":"welcome","v":1}` | `hello`의 답 |
| `{"type":"created","room":"K7QPXM","you":"m1","token":"…"}` | 방이 생김. `you`는 프로그램의 멤버 ID |
| `{"type":"entered","room":"K7QPXM","you":"m3","token":"…","host":"m1","members":[{"member":"m1","nickname":"TV"},…]}` | `join`의 답: 프로그램을 포함한 멤버들 |
| `{"type":"resumed","room":"K7QPXM","you":"m3","host":"m1","members":[…]}` | `resume`의 답. 그동안 온 것이 순서대로 뒤따름 |
| `{"type":"joined","member":"m4","nickname":"Kim"}` | 누가 들어옴 |
| `{"type":"left","member":"m4"}` | 누가 나갔거나, `reconnectSeconds`보다 오래 끊겨 있었음 |
| `{"type":"message","from":"m3","data":"…"}` | 메시지. 이 프로그램에게만 보낸 것이면 `"direct":true` |
| `{"type":"locked"}` | 방장이 방을 잠금 |
| `{"type":"closed","reason":"host left"}` | 방이 끝남: `host left`, `idle`(`idleMinutes` 동안 보낸 것이 없음), `time`(`maxRoomMinutes` 동안 열려 있었음), `server`(서버가 멈춤) |
| `{"type":"error","code":"room-full","message":"…"}` | 무엇이 거부됨. `message`는 사람이 읽는 글이고 빠질 수 있음 |

멤버 ID는 들어온 순서대로 `m1`, `m2`, …이고, 방장은 방을 만든 사람입니다. `token`이 있으면 끊긴 연결 뒤에 돌아올 수 있으니 남에게 주지 않습니다.

## 오류

| 코드 | 이유 |
|---|---|
| `bad-message` | 알려진 `type`이 있는 JSON 객체가 아님, `data`가 글이 아님, 또는 맨 처음이 `hello`가 아님 |
| `bad-version` | 다른 `v`의 `hello`. 연결을 닫음 |
| `bad-key` | 서버의 키 없는 `hello`. 연결을 닫음 |
| `bad-nickname` | 1~40자가 아님 |
| `room-not-found`, `room-full`, `room-locked` | `join`이 들어가지 못함 |
| `server-full` | 서버에 이미 `maxRooms`개의 방이 있음 |
| `too-big` | `maxMessageBytes`(UTF-8 16384바이트)보다 큰 메시지. 세 번째에 연결을 닫음 |
| `too-fast` | 멤버가 `messagesPerSecond`(20)보다 많이 보냄, 또는 한 주소에서 `joinAttemptsPerMinute`(30)보다 많은 `join`. 메시지가 한도의 세 배면 연결을 닫음 |
| `not-in-room`, `already-in-room`, `not-host`, `no-member`, `cannot-resume` | 프로그램이 있는 자리에 맞지 않는 메시지 |

## 서버가 남기는 것

디스크에는 아무것도 남기지 않습니다. 방과 멤버는 메모리에만 있고, 방이 끝나면 그 방의 모든 것이 사라집니다. 서버 주인이 `logMessages`를 켜지 않는 한 메시지 본문은 기록하지 않습니다. 방 코드는 `23456789ABCDEFGHJKLMNPQRSTUVWXYZ` 중 6자이고 안전한 난수 생성기로 만듭니다: 32⁶, 약 10억 7천만 가지.
