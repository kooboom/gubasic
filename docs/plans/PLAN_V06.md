# Plan: v0.6 "Together" — WebSocket, Room, the relay server, a live quiz

[한국어](PLAN_V06.ko.md)

In the shape of [PLAN_TEMPLATE.md](../PLAN_TEMPLATE.md). It rests on DESIGN D121 (no detours), D122 (real-time communication over standard WebSocket, in two layers), D123 (the answers: users' own relay servers first), D124 A (Http waits where it is called), D125 and D126 (the component channel) and IDEAS "Real-time together". This is a plan written before implementation. The author answered the questions of §6 on 2026-11-03: every recommendation is taken, with one addition to Q4: the "Allow devices on the same network" switch is off by default and shows a warning when it is turned on (§3.5). The work goes in the order of Q10, one PR per step, merged after review.

Address rule (CLAUDE.md): in this document and in every file of v0.6, the only server address is the one reserved for documentation, `relay.example.com`; tests and the IDE's local server use `localhost` (`127.0.0.1`). An address on the same network is written only as `<this computer's network address>`.

## 1. What and why

**What the user will be able to do.** Put a `Room` on a form; the TV side calls `rmQuiz.Create()`, the phone side `rmQuiz.Join(code, nickname)`, and programs that share a room code exchange text (JSON) with `Send` and receive it through the `Message`, `Joined` and `Left` events. A standard WebSocket server is spoken to directly with `WebSocket`. This is today's version of what Visual Basic 6 did with the Winsock control (D122).

The smallest example (the TV side):

```vb
Sub Form_Load()
    rmQuiz.Create()                       ' makes a room on the relay server and waits for its code
    lblCode.Caption = "Room code: " & rmQuiz.Code
End Sub

Sub rmQuiz_Joined(e As RoomEventArgs)
    lstPlayers.AddItem(e.Nickname)
End Sub

Sub rmQuiz_Message(e As RoomEventArgs)
    Dim answer As Json = e.Json
    lblLast.Caption = e.Nickname & ": " & answer("choice").AsInteger
End Sub
```

The phone side is `rmQuiz.Join(txtCode.Text, txtNickname.Text)` and then `rmQuiz.Send(answer.Text)`.

**Stage.** ROADMAP v0.6 "Together". When v0.6 is done there is the **LiveQuiz** example: a live quiz answered from phones, with the TV showing the scoreboard and the race. The example and the tests run against **a relay server on this computer (localhost)**, and when a program runs in the IDE the relay server starts by itself (§3.5).

**What changes in D123.** There is no "project's public trial server". Reasons: the burden of running it, and public documents must not point at anyone's personal server (the new rule in CLAUDE.md). Documents and examples use only the address reserved for documentation (`relay.example.com`); tests use `localhost`. A public trial server can be decided again later, under a separate address, if it is needed. This change is recorded as D136 and the sentences in IDEAS, ROADMAP and COMPONENT_CHANNEL are corrected (en, ko).

## 2. How it is used

### 2.1 The `WebSocket` control (the lower layer)

An invisible control placed in the tray like Timer (`visual: false`). It exchanges text messages with any standard WebSocket server ([RFC 6455](https://www.rfc-editor.org/rfc/rfc6455)).

| Member | What it does |
|---|---|
| `Connect(url)` | Connects to `wss://…` or `ws://…` and **waits where it is called until the connection is open** (as Http does, D124 A). R047 if it cannot open |
| `Send(text)` | Sends one text message. R049 when not open |
| `Close()` | Closes |
| `State` | `"Closed"`, `"Open"` (read-only) |
| `Url` | The address last connected to (read-only), `Tag` |
| Event `Message(e As MessageEventArgs)` | A message arrived: `e.Text`, `e.Json` (parsed then; R039 if it is not JSON) |
| Event `Closed(e As CloseEventArgs)` | The server closed or the connection was lost: `e.Reason` |
| Event `Error(e As ErrorEventArgs)` | An error after the connection was open: `e.Message` |

Winsock's names are pointed to GuBASIC's (D50): `SendData` → `Send`, `DataArrival` → `Message`, `GetData` → `e.Text`; for the `Connect` event, a message in the A051 family says that `Connect` waits, so there is no event.

### 2.2 The `Room` control (the upper layer)

A relay server joins programs that share a room code. The message format is published (`docs/ROOM_PROTOCOL.md`).

| Member | What it does |
|---|---|
| `Server` | The relay server's address (`wss://relay.example.com/room`). Set in the property window. Empty: the IDE's local server while developing (§3.5); empty in an exported app: R048 |
| `Nickname` | My nickname. In the property window or in code |
| `Create()` | Makes a room and waits for its code. Then `Code`, `Me` |
| `Join(code, nickname)` | Waits until the program is in the room. A room that does not exist, is full or is locked: R048, with the server's reason |
| `Send(text)`, `SendTo(member, text)` | To everyone, or to one member |
| `Leave()` | Leaves. When the host leaves, the room ends |
| `Lock()` | Host only: nobody else may join |
| `Code`, `Me`, `IsHost`, `Members` (a `String` array of member IDs), `Nickname(member)` | Read-only |
| Events `Joined(e)`, `Left(e)` | Someone else came in or left: `e.Member`, `e.Nickname` |
| Event `Message(e)` | `e.Member`, `e.Nickname`, `e.Text`, `e.Json` |
| Event `Closed(e)` | The room ended: `e.Reason` (`"host left"`, `"idle"`, `"server"`) |
| Event `Error(e)` | An error after joining (a message the server refused, and the like): `e.Message` |

Every `e` is a `RoomEventArgs`. A lost connection keeps its seat for 30 seconds and reconnects by itself (IDEAS 7); meanwhile `Send` queues. If it cannot reconnect within 30 seconds: `Closed`.

### 2.3 Diagnostics (draft)

| Code | English | Korean |
|---|---|---|
| R047 | `No connection to {0} ({1}). Check the address and the network; a page served over https needs wss://.` | `{0} 주소에 연결하지 못했습니다({1}). 주소와 네트워크를 확인해 주세요. https로 열린 페이지는 wss://가 필요합니다.` |
| R048 | `Could not enter the room: {0}. Check the code, and that Room.Server points to a relay server.` | `방에 들어가지 못했습니다: {0}. 코드와, Room.Server가 중계 서버를 가리키는지 확인해 주세요.` |
| R049 | `{0} is not connected, so Send has nowhere to go. Connect or Join first, or wait for Closed to be handled.` | `{0} 컨트롤이 연결되어 있지 않아 Send를 보낼 곳이 없습니다. 먼저 Connect나 Join을 하거나 Closed를 처리해 주세요.` |
| A077 (warning) | `ws:// to {0} is not encrypted and a page served over https cannot open it. Use wss:// for anything but localhost or your own network.` | `{0} 주소로의 ws://는 암호화되지 않고, https로 열린 페이지에서는 열리지 않습니다. localhost나 같은 네트워크가 아니면 wss://를 써 주세요.` |
| A078 (warning, at export) | `Room.Server is empty: the app will have no relay server. Set it to your server's address, as docs/RELAY_SERVER.md says.` | `Room.Server가 비어 있어 앱에 중계 서버가 없습니다. docs/RELAY_SERVER.md대로 자기 서버 주소를 넣어 주세요.` |

### 2.4 The LiveQuiz example

One project, three forms. One exported web app is used by the TV and the phones alike (Q3).

- **FormStart:** two buttons, "Run on the TV" / "Join from a phone".
- **FormTV:** `rmQuiz.Create()` → the room code in large letters, the list of those who joined (`Joined`), a "Start" button. For each question it `Send`s `{"kind":"question","no":1,"text":"…","choices":[…],"seconds":15}` and draws the time left with a Timer. When answers (`{"kind":"answer","no":1,"choice":2}`) arrive it scores them in order of arrival, sends `{"kind":"score","board":[…]}` and draws the scoreboard and the race of characters (several Images whose Left moves in proportion to the score). The questions are the seven of the Quiz example's `Structure Question`, as they are.
- **FormPhone:** code and nickname → `Join` → four choice buttons → sends the answer and shows "Correct!/Not this time" and my rank.
- Uses `Room`, `Json`, `Structure` (Player: Member, Nickname, Score), `Timer`, `List`, `With`.

## 3. Design

### 3.1 Where things go

| Place | What |
|---|---|
| `components/WebSocket/component.yaml`, `components/Room/component.yaml` | `visual: false`, `platforms: [web, macos, windows]`, events with their argument type (`Message(e As MessageEventArgs)`). Hard rule 7 |
| `packages/gubasic_lang/lib/src/components/web_socket_component.dart`, `room_component.dart` | Pure Dart. The protocol's JSON, the state machine, reconnection, the limit checks. The socket itself is left outside through abstract methods, as `Http` does (`open`, `send`, a stream of received messages) |
| The component channel in `packages/gubasic_lang` | **The event path comes into being.** `ComponentInstance` gets an `onEvent(String name, List<Object?> args)` callback. The interpreter queues events like Timer ticks and runs them one at a time, never re-entering (hard rules 4 and 5). `_parameterTypes` gains `MessageEventArgs`, `CloseEventArgs`, `ErrorEventArgs`, `RoomEventArgs` |
| `packages/gubasic_runtime/lib/src/web_socket.dart` | `GbWebSocket` on [web_socket_channel](https://pub.dev/packages/web_socket_channel) (`dart:io` on the desktop, the browser's WebSocket on the web). Tests use a fake |
| `packages/gubasic_player` | Plugs both components into the channel and shares the waiting pointer (D124 A) with Http |
| `packages/gubasic_relay/` (a new pure-Dart package) | The server side of the room protocol: `RoomHub` (the core, which runs without sockets), the relay server on `dart:io`'s `HttpServer`, `bin/gubasic_relay.dart`. The IDE carries it as a library; the install script uses the executable made with `dart compile exe`. The later "GuBASIC server" shares its code (IDEAS) |
| `packages/gubasic_relay/deploy/` | `install.sh`, `relay.yaml.example`, `apache-relay.conf.example`, `gubasic-relay.service` |
| `docs/ROOM_PROTOCOL.md` (+ko), `docs/RELAY_SERVER.md` (+ko) | The message format; the install guide |
| `examples/livequiz/` | §2.4 |

### 3.2 The relay server (`gubasic_relay`)

- **Protocol (v1):** one WebSocket message is one JSON object. The first message is `{"type":"hello","v":1,"key":"…"}` (`key` only when the server asks for one). Then, as IDEAS drafted: `create`, `join`, `send`, `sendTo`, `leave`, `lock`; from the server to the program `created`, `joined`, `left`, `message`, `closed`, `error` (codes: `bad-key`, `room-not-found`, `room-full`, `room-locked`, `too-fast`, `too-big`, `server-full`). `ping`/`pong` are WebSocket's own.
- **Room code:** a secure random choice of 6 characters from 32 that leave out the confusable ones (`23456789ABCDEFGHJKLMNPQRSTUVWXYZ`), accepted regardless of case.
- **Paths:** `GET /room` takes the WebSocket upgrade; `GET /room/health` answers `{"gubasicRelay":"0.6.0","rooms":3}` (no messages, no nicknames).
- **Keeping it from being used by anyone (recommended defaults; all changeable in `relay.yaml`):**

  | Setting | Default | Meaning |
  |---|---|---|
  | `bind`, `port` | `127.0.0.1`, `7071` | Listens only behind Apache |
  | `maxRooms` | 50 | Rooms open at once on the whole server. Beyond: `server-full` |
  | `maxMembers` | 50 | Members in one room |
  | `maxMessageBytes` | 16384 | Message size (UTF-8 bytes). Beyond: `too-big`; three times and the connection is closed |
  | `messagesPerSecond` | 20 | Per member. Beyond: `too-fast`; if it goes on, the connection is closed |
  | `joinAttemptsPerMinute` | 30 | `join` attempts per IP address. Against guessing codes (OWASP) |
  | `idleMinutes`, `maxRoomMinutes` | 30, 360 | Closes quiet rooms and old rooms |
  | `allowedOrigins` | `[]` | Empty: every origin is allowed (for development). Filled: the upgrade is refused when the browser's `Origin` is not in the list. The guide says to put one's own web app's address in |
  | `key` | none | An optional access password. If set, `hello`'s `key` must match. It goes into the web app as it is, so the documents call it a "door that keeps strangers out", not a secret (hard rule 12: no service-key warning for it, but it is explained) |
  | `logMessages` | `false` | Message bodies are not logged (IDEAS, privacy) |

  Nothing is stored (memory only); when a room ends, everything in it is gone.
- **Deployment (on anyone's Linux server):** `install.sh` (1) downloads the release's `gubasic-relay-linux-x64` (or arm64) executable, or builds one with `dart compile exe` if Dart is installed, (2) creates the system user `gubasic-relay`, `/opt/gubasic-relay` and `/etc/gubasic-relay/relay.yaml`, (3) registers and starts the systemd service, and (4) prints the snippet to add to Apache (`ProxyPass /room ws://127.0.0.1:7071/room upgrade=websocket`, `mod_proxy_wstunnel`, a certificate from Let's Encrypt). The guide (`RELAY_SERVER.md`) covers what is needed, the few commands, the check (`curl https://relay.example.com/room/health`), updating and removal. Every address is `relay.example.com`. **Nothing is installed on a real server.** The release workflow builds `gubasic-relay-linux-x64` and `-arm64` and lists them in SHA256SUMS.

### 3.3 Hard rules, and what stays open

- No new syntax: the controls and their events come in through component.yaml, so the AST is unchanged and the way to the transpiler stays open (hard rule 2).
- Events run one handler at a time and never re-enter (4, 5). While `Create`, `Join` and `Connect` wait, the screen keeps drawing and Stop works (the same path as D124 A).
- Form files: tray controls like Timer, so no `formatVersion` change (8).
- Platforms: all three. Not in the playground (R038, in KNOWN_ISSUES next to Http and Database).

### 3.4 The relay server in tests

As IDEAS 9 says (an in-memory relay server for the parity tests), `gubasic_relay`'s `RoomHub` is used inside the process, without sockets. The VM, Chrome and the run window run the same code, so the transcripts match. The event scripts (`.events`) gain lines for the other side:

```
Peer 민지 Join            ' "민지" joins the room the program made
Peer 민지 Send {"kind":"answer","no":1,"choice":2}
Peer 민지 Leave
Room Close idle           ' the server closes the room
```

The transcript records `Room: create K7QPXM` (the code generator is pinned in tests), `Room: send {…}`, `Room: sendTo m2 {…}`. Real sockets are checked in (1) `gubasic_relay`'s own tests (several real WebSockets on localhost), (2) the `GbWebSocket` tests (one `dart:io` server), (3) the IDE's integration test (FormTV runs and a scripted phone connects to the built-in relay server).

### 3.5 Turning it on easily in the IDE (recommended, and decided)

- **Automatic:** when a program whose `Room.Server` is empty runs, the desktop IDE starts the built-in `gubasic_relay` on a free port of `127.0.0.1` and writes `Room server: ws://127.0.0.1:53421/room (this computer only)` to the output window. The port is kept while the IDE is open; running the program again makes a new room.
- **A phone on the same Wi-Fi:** the Run menu's check item **"Allow devices on the same network"**. **Off by default**, and off again whenever the IDE starts. **While it is off, the relay server listens on localhost (`127.0.0.1`) only; only while it is on does it also listen on the computer's network address** (it listens again on every interface and writes `Room server: ws://<this computer's network address>:53421/room (same network)` to the output). Turning it on shows a warning first: "Other devices on the same network will be able to connect to this computer's relay server. Do not turn this on, on a public network." (OK/Cancel; Cancel leaves it off.) The phone-side program puts that address into `Server`. Turning it off goes straight back to localhost only and closes the other devices' connections.
- **Getting the app onto the phone:** the phone needs a web app. Recommended: the same menu's **"Preview on the web"** builds the current project the way Export does (the web player template + project.gbz), serves it at the same address, `http://<this computer's network address>:53421/`, and shows a QR code (with the switch off it is `http://localhost:53421/` only, and the QR code says to turn the switch on). The page is `http`, so `ws://` is not blocked. When `Room.Server` is empty, the previewed app uses `/room` on the host that served it. (Q4. Without this, checking on a phone means uploading an exported web app somewhere.)
- **The web IDE:** a browser cannot open a server, so there is no local relay server. When `Server` is empty, R048's message says to use the desktop IDE or to set Room.Server, and KNOWN_ISSUES records it.

## 4. No detours (D121)

- **Where users would still have to go around:** binary messages (text only; a picture can go as Base64 text, so later), headers on a WebSocket connection (browsers do not allow them, so impossible within the standard; a token goes in the URL's query or the first message), TCP/UDP (not on the web; a component candidate after the transpiler), a direct connection within the same network (IDEAS' "later option"), rules on the server side (the GuBASIC server, the next stage). All in KNOWN_ISSUES.
- **Standards:** WebSocket RFC 6455, wss is TLS, JSON RFC 8259, Origin RFC 6454, the configuration file is YAML.
- **The way in:** both are components of the component channel, and the first **components with events**, which completes the channel (COMPONENT_CHANNEL stage 2).
- **Documents and examples:** LANGUAGE 11.11 WebSocket, 11.12 Room (+ko), ROOM_PROTOCOL.md, RELAY_SERVER.md, the reference's pages for the two controls (generated), llms-full.txt (generated), the LiveQuiz example; nothing in FIRST_APP.

## 5. Tests

- Parity (`test/parity/`): `websocket_basics` (a scripted fake server in a `.ws` file, written like Http's `.http` with the answers to send), `room_basics` (Create, Peer Join/Send/Leave, Closed), `room_errors` (no such room, a full room, a message too big), `room_reconnect` (recovery within 30 seconds after a drop); VM, Chrome, the run window.
- `gubasic_relay`: one test per limit (rooms, members, size, rate, Origin, key, idle), two clients exchanging messages over real sockets, health.
- `gubasic_runtime`: `GbWebSocket` (connect, send, closed, error).
- IDE: the local relay server's automatic start and its output line; the "same network" switch (off by default, localhost only while off, the warning when turning it on with Cancel leaving it off, other addresses only after it is on); A078 at export. Integration test (Windows and macOS, both in CI): FormTV plus a scripted phone.
- By hand (Playwright, web): the built web player runs LiveQuiz in two browser contexts (TV, phone) through the local relay server, one whole round. On the Mac, only in ways that do not use the author's mouse and keyboard.

## 6. Questions and answers (2026-11-03)

The author's answers: **all ten as recommended.** Only Q4 has an addition, below.

**Q1. Waiting.** Should `Connect`, `Create` and `Join` wait where they are called, as Http does (the screen keeps drawing and Stop works), with failure an R error caught by Try? Or return at once and report through `Connected`/`Created` events, as IDEAS 1 first recommended?
Recommended: **wait.** D123 (1) said "follow Http's answer" and D124 A chose waiting. A beginner can write `lblCode.Caption = rmQuiz.Code` on the line after `Create()` in `Form_Load`.
**Answer:** as recommended, waiting.

**Q2. The shape of the controls.** Tray controls only, like Timer, or allow `New Room` too?
Recommended: **tray controls only.** `Server` and `Nickname` are set in the property window and events are made by double-clicking. `New` when a need shows.
**Answer:** as recommended, tray controls only.

**Q3. The shape of the example.** LiveQuiz as one project (a first form that picks the role + the TV form + the phone form), or two projects, TV and phone?
Recommended: **one.** One exported web app serves the TV and the phones, so there is one address and one example.
**Answer:** as recommended, one project.

**Q4. The IDE's local server.** (a) Start it automatically when `Server` is empty and write the address to the output, (b) the "Allow devices on the same network" switch, (c) "Preview on the web" (serve the current project as a web app at the same address and show a QR code). All three in v0.6?
Recommended: **all three.** Without (c), trying it on a phone means putting the web app somewhere, and "it runs on my computer" ends at the TV side. (c) is small, since it reuses the export code and the web template. But (c) goes last in the order, and moves to v0.6.1 if time runs short.
**Answer:** all three. But (b), "Allow devices on the same network", is **off by default.** While it is off, the server listens on localhost only; only while it is on does it listen on the same network's address. Turning it on shows a warning such as "Other devices on the same network will be able to connect to this computer's relay server. Do not turn this on, on a public network." (reflected in §3.5).

**Q5. The relay server's place and name.** `packages/gubasic_relay` (pure Dart, carried by the IDE as a library), the executable `gubasic-relay`, the release assets `gubasic-relay-linux-x64` and `-arm64`?
Recommended: **yes.** `apps/` is for Flutter apps, and as a library the IDE can carry it and the tests can use it without sockets.
**Answer:** as recommended.

**Q6. The limits' defaults.** The table of §3.2 (50 rooms, 50 members, 16 KB, 20 a second, 30 joins a minute per IP address, 30 minutes idle, 6 hours, an Origin list that allows all when empty, an optional key)?
Recommended: **yes.** One server carries a class (30 to 40) and a school event (a few rooms), and on one's own server raising a limit is one line of configuration. The guide says to fill `allowedOrigins` as a first step, because empty means "everyone".
**Answer:** as recommended.

**Q7. The room code.** Six characters from 32 without the confusable ones (case ignored), or six digits, easier to type on a phone?
Recommended: **six from 32.** Six digits give only a million codes, so guessing is realistic even with 30 attempts a minute. The phone's input box turns letters into capitals by itself.
**Answer:** as recommended, six from 32.

**Q8. The ws:// rule.** GuBASIC does not block it and only warns (A077), with no warning for localhost and private-network addresses ([RFC 1918](https://www.rfc-editor.org/rfc/rfc1918))?
Recommended: **warn only.** The same-network switch (Q4 b) uses `ws://` with an address on the same network, and blocking `ws://` from an https page is something browsers already do.
**Answer:** as recommended, warn only.

**Q9. When D136 is recorded.** Record D123's change (no public trial server) and the design of §3.1–3.5 as D136 now, and correct IDEAS, ROADMAP and COMPONENT_CHANNEL (en, ko), as the first commit of v0.6?
Recommended: **yes.** Later PRs then point to D136.
**Answer:** as recommended, the first commit.

**Q10. Order.** (1) D136 and the documents → (2) events in the component channel + `WebSocket` → (3) `gubasic_relay` (RoomHub, the protocol, its own tests) → (4) `Room` + parity tests → (5) the IDE's local server (Q4 a, b) → (6) LiveQuiz + Playwright → (7) the install guide, the scripts, the release assets → (8) preview on the web (Q4 c) → v0.6.0. One PR per step, merged after review.
Recommended: **yes.** (2) proves the channel's events first, and (3) runs without Flutter, so it is checked quickly.
**Answer:** as recommended, in this order.
