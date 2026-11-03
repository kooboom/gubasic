# The room protocol (version 1)

[한국어](ROOM_PROTOCOL.ko.md)

How a program talks to a GuBASIC relay server (DESIGN D122, D136). GuBASIC's `Room` control speaks it; it is published so that a program not written in GuBASIC can join a room too. The server is `packages/gubasic_relay`; how to put it on a server of your own is in [RELAY_SERVER.md](RELAY_SERVER.md).

## The connection

- A WebSocket ([RFC 6455](https://www.rfc-editor.org/rfc/rfc6455)) to the server's `/room`: `wss://relay.example.com/room` behind a web server with TLS, `ws://127.0.0.1:7071/room` on one's own computer.
- One WebSocket text message is one JSON object ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)) with a `"type"`. Binary messages close the connection.
- Ping and pong are WebSocket's own; the server pings every 25 seconds.
- A page served by a web browser sends its `Origin` ([RFC 6454](https://www.rfc-editor.org/rfc/rfc6454)); a server whose `allowedOrigins` is filled refuses the upgrade (403) for any other page.
- `GET /room/health` answers `{"gubasicRelay":"0.6.0","rooms":3}`: no codes, no nicknames, no messages.

## From the program to the server

| Message | When |
|---|---|
| `{"type":"hello","v":1}` | First, always. `"key":"…"` too when the server asks for one |
| `{"type":"create","nickname":"TV"}` | Makes a room; the program is its host. `nickname` may be left out ("host") |
| `{"type":"join","room":"K7QPXM","nickname":"민지"}` | Enters a room. The code is read in any case, spaces and `-` left out |
| `{"type":"send","data":"…"}` | To everyone else in the room |
| `{"type":"sendTo","to":"m3","data":"…"}` | To one member |
| `{"type":"leave"}` | Leaves the room; the host leaving ends it |
| `{"type":"lock"}` | The host only: no one else may enter |
| `{"type":"resume","room":"K7QPXM","member":"m3","token":"…"}` | Comes back on a new connection after the old one was lost, within the server's `reconnectSeconds` (30) |

`data` is text; GuBASIC programs put JSON in it, but the server does not read it. A nickname is 1 to 40 characters.

## From the server to the program

| Message | When |
|---|---|
| `{"type":"welcome","v":1}` | The answer to `hello` |
| `{"type":"created","room":"K7QPXM","you":"m1","token":"…"}` | The room is made; `you` is the program's member ID |
| `{"type":"entered","room":"K7QPXM","you":"m3","token":"…","host":"m1","members":[{"member":"m1","nickname":"TV"},…]}` | The answer to `join`: the members, the program among them |
| `{"type":"resumed","room":"K7QPXM","you":"m3","host":"m1","members":[…]}` | The answer to `resume`; what came meanwhile follows, in order |
| `{"type":"joined","member":"m4","nickname":"Kim"}` | Someone entered |
| `{"type":"left","member":"m4"}` | Someone left, or was away longer than `reconnectSeconds` |
| `{"type":"message","from":"m3","data":"…"}` | A message; `"direct":true` when it was sent to this program alone |
| `{"type":"locked"}` | The host locked the room |
| `{"type":"closed","reason":"host left"}` | The room ended: `host left`, `idle` (nothing sent for `idleMinutes`), `time` (open for `maxRoomMinutes`), `server` (the server stopped) |
| `{"type":"error","code":"room-full","message":"…"}` | Something was refused; `message` is for people and may be left out |

Member IDs are `m1`, `m2`, … in the order members came; the host is the one who made the room. The `token` lets a member come back after a lost connection: keep it to yourself.

## Errors

| Code | Why |
|---|---|
| `bad-message` | Not a JSON object with a known `type`, `data` that is not text, or not `hello` first |
| `bad-version` | `hello` with another `v`; the connection is closed |
| `bad-key` | `hello` without the server's key; the connection is closed |
| `bad-nickname` | Not 1 to 40 characters |
| `room-not-found`, `room-full`, `room-locked` | `join` could not enter |
| `server-full` | The server has `maxRooms` rooms already |
| `too-big` | A message over `maxMessageBytes` (16384 UTF-8 bytes); the third time the connection is closed |
| `too-fast` | Over `messagesPerSecond` (20) a member, or over `joinAttemptsPerMinute` (30) `join`s from one address; three times the message rate closes the connection |
| `not-in-room`, `already-in-room`, `not-host`, `no-member`, `cannot-resume` | A message that does not fit where the program is |

## What the server keeps

Nothing on disk: rooms and members live in memory, and when a room ends everything about it is gone. Message bodies are not logged unless the server's owner turns `logMessages` on. Room codes are 6 characters from `23456789ABCDEFGHJKLMNPQRSTUVWXYZ`, made by a secure random number generator: 32⁶, about 1.07 billion codes.
