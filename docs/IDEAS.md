# Ideas

[한국어](IDEAS.ko.md)

Ideas worth keeping that no stage has taken on yet. Nothing here is decided or planned: an idea moves into the ROADMAP, with a plan and its decisions, only when the author chooses it.

---

## Adventure game controls

**Goal:** a set of controls for making point-and-click adventure games: a picture of a place, things in it to look at and click, a character who walks there, people to talk to, and a bag of things to use on other things. Visual Basic 6 had nothing like it; with these, anyone could make the kind of game that is drawn and clicked rather than typed.

**When:** a candidate for after stage 3. It changes neither the stage 2 plan nor the project bundle format (STAGE2_PLAN.md).

### Candidates

| Control | What it does |
|---|---|
| **Scene** | A place: a background picture that fills the form, and going from one scene to another (with a fade, say). A game is a set of scenes |
| **Hotspot** | An invisible area of the scene that can be clicked; with the mouse over it, its name shows ("old door"). Events: `Click`, `MouseEnter`, `MouseLeave` |
| **Sprite** | A character drawn from several pictures in turn (walking left, right, towards, away). `WalkTo x, y` makes it walk there, choosing the pictures by direction; `Arrived` comes when it gets there |
| **Dialog** | Speech bubbles over a sprite, and a list of choices for the player, each leading on to the next lines |
| **Inventory** | The player's bag: pictures of the things carried; a thing dragged out of it and dropped on a Hotspot, a Sprite or another thing raises an event that says what was used on what (`UseOn`) |

### What must come first

- **Timer** (STAGE2_PLAN step 2-9): walking, animation and fades move a little every tick.
- **Key events** (step 2-10): moving or skipping dialogue from the keyboard.
- **Several forms, or scenes** (steps 2-7, 2-8): a game moves between places; a Scene could be built on forms or be its own thing, to be decided then.
- **Many pictures:** a sprite's walking needs sets of pictures in order (frames) per direction; the project's pictures today are single images (LANGUAGE §11.3), so a way to group them comes first.

### How an existing tool does it: Adventure Game Studio

Adventure Game Studio (AGS), a tool made for such games, builds them from a few ideas that match the candidates above:

- **Rooms:** "games are made up of several rooms, which the player moves between"; "each room is one screen that has its own background, hotspots, and objects" ([AGS manual, part 2](https://adventuregamestudio.github.io/ags-manual/v3/acintro2.html)). → Scene.
- **Hotspots, objects and characters:** the three kinds of thing the player can interact with. "A hotspot is an area of the background image that the player can look at and interact with", for parts that do not change; an object "can move around the screen, and be switched on and off" ([part 3](https://adventuregamestudio.github.io/ags-manual/v3/acintro3.html), [part 4](https://adventuregamestudio.github.io/ags-manual/v3/acintro4.html)). → Hotspot; an Image already plays the object's part.
- **Inventory:** "each character in the game can carry their own set of inventory items", set up separately from the objects in rooms ([part 5](https://adventuregamestudio.github.io/ags-manual/v3/acintro5.html)). → Inventory.
- **Views and loops:** "a view is a set of one or more loops. A loop is a set of frames which, when played in sequence, give the illusion of movement", used for a character's walking ([part 7](https://adventuregamestudio.github.io/ags-manual/v3/acintro7.html)). → Sprite, and the grouped pictures it needs.
- **Conversations:** from one fixed line to "complete dialog trees through which you could choose your topics" ([part 8](https://adventuregamestudio.github.io/ags-manual/v3/acintro8.html)). → Dialog.
- **Cursor modes:** each mouse cursor is a different way to interact, "Walk to" among them, and "Use inventory" when an item is chosen ([part 9](https://adventuregamestudio.github.io/ags-manual/v3/acintro9.html)). GuBASIC would rather keep one pointer: click to walk or look, drag a thing from the bag to use it.

What GuBASIC would keep of its own: the controls are drawn on a form in the designer, and the game is written as event handlers (`hsDoor_Click`, `sprHero_Arrived`, `invKey_UseOn`), as everything else in GuBASIC is.

---

## Real-time together: WebSocket and Room

**Goal:** apps in which people join from their phones and answer a quiz in real time, while a TV shows the scores and characters racing each other. Visual Basic 6 programs of this kind talked through the Winsock control, whose `DataArrival` event told them a message had come ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa228119(v=vs.60))); this is today's version. The direction is decided (DESIGN D122); this section holds the comparisons, the rules and the open questions.

**When:** v0.6 "Together", after v0.5's Http and JSON ([ROADMAP](ROADMAP.md)).

### The usual way, and why

- **WebSocket** ([RFC 6455](https://www.rfc-editor.org/rfc/rfc6455)) opens a two-way connection, so a server can send a message the moment it has one, without the browser asking again and again ([MDN](https://developer.mozilla.org/en-US/docs/Web/API/WebSockets_API)). Every browser, Dart (`dart:io` and [web_socket_channel](https://pub.dev/packages/web_socket_channel)) and every common server language has it. HTTP polling is kept for what is not real-time (a leaderboard, v0.5).
- **`wss`**, WebSocket over TLS: a web app served over HTTPS may not open a plain `ws://` connection ([MDN, mixed content](https://developer.mozilla.org/en-US/docs/Web/Security/Mixed_content)).
- **JSON** messages ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)): any program can read and write them.

### Two layers

**Lower: `WebSocket`**, for any standard WebSocket server.

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

Members: `Connect(url)`, `Send(text)`, `Close()`, `State`; events `Connected`, `Message`, `Closed`, `Error`. (Candidate syntax; the JSON helpers come with v0.5.)

**Upper: `Room`**, people with the same room code, through a relay server.

```vb
' On the TV
Sub Form_Load()
    rmQuiz.Create()                 ' rmQuiz.Code is now, say, "K7QPXM"
    lblCode.Caption = rmQuiz.Code
End Sub

Sub rmQuiz_Joined(e As RoomEventArgs)
    lstPlayers.AddItem(e.Nickname)
End Sub

Sub rmQuiz_Message(e As RoomEventArgs)
    ' e.From, e.Nickname, e.Text
End Sub

' On a phone
Sub btnJoin_Click()
    rmQuiz.Join(txtCode.Text, txtNickname.Text)
End Sub
```

Members: `Create()`, `Join(code, nickname)`, `Send(text)` (to everyone) and `SendTo(member, text)`, `Leave()`, `Code`, `Members`; events `Joined`, `Left`, `Message`, `Closed`, `Error`.

**The message format is published** (a page of its own when it is built), so that a program not written in GuBASIC can join a room. A draft, one JSON object per WebSocket message:

| Direction | Message |
|---|---|
| program → server | `{"type":"create"}`, `{"type":"join","room":"K7QPXM","nickname":"민지"}`, `{"type":"send","data":"…"}`, `{"type":"sendTo","to":"m3","data":"…"}`, `{"type":"leave"}` |
| server → program | `{"type":"created","room":"K7QPXM","you":"m1"}`, `{"type":"joined","member":"m3","nickname":"민지"}`, `{"type":"left","member":"m3"}`, `{"type":"message","from":"m3","data":"…"}`, `{"type":"closed","reason":"host left"}`, `{"type":"error","code":"room-not-found"}` |

### Where the server runs: three ways compared

| | One person's laptop as the server | An outside service (Firebase and the like) | A relay server we run (recommended) |
|---|---|---|---|
| How | The TV's computer opens a port; phones connect to its address | The apps write to a hosted database that pushes changes ([Firebase Realtime Database](https://firebase.google.com/docs/database)) | A small server, kept in this repository, that passes messages within a room |
| Good | No server, no account, no cost | Nothing to run; scales | Standard WebSocket, so anyone can connect; keeps nothing; anyone may run their own |
| Bad | Networks at offices and schools often block incoming connections and keep devices from seeing each other; phones on mobile data cannot reach a private address. A web app served over HTTPS cannot open `ws://`, and Chrome blocks public pages from reaching private addresses ([Chrome](https://developer.chrome.com/blog/private-network-access-update)); a certificate for a private address is hard to get | An account and keys for every app (no secrets in apps: hard rule 12, so security rules must do the work); the service's own protocol, not WebSocket that others can use; the messages are stored with a third party; costs that grow with use | Someone must run it and pay for it, and limit abuse |
| For | A later option between desktop apps on one network | Users who already use the service: a `Firebase` component is on the ROADMAP | The default for `Room` |

**Recommended:** the relay server. GuBASIC's project runs one public instance, with limits, so that `Room` works out of the box; schools, companies and anyone else can run their own, and `Room.Server` points to it.

**Built with:** Dart (`dart:io`'s `HttpServer` with its WebSocket upgrade, [Dart](https://api.dart.dev/dart-io/HttpServer-class.html)), the language GuBASIC is written in, so that the "GuBASIC server" later can share its code. Node.js with [ws](https://github.com/websockets/ws) is the common alternative.

**Deployed:** on Linux, the relay server listens on `localhost`, run as a service; Apache in front ends TLS (a certificate from [Let's Encrypt](https://letsencrypt.org/getting-started/)) and passes the WebSocket upgrade on as a reverse proxy (`mod_proxy` with `upgrade=websocket`, or `mod_proxy_wstunnel`: [Apache](https://httpd.apache.org/docs/2.4/mod/mod_proxy_wstunnel.html)). A page with the exact configuration comes with the server.

### Privacy

- **Nicknames, not names.** `Join` takes a nickname; the server asks for nothing else.
- **Nothing kept.** Rooms live in the server's memory only; when a room ends (its creator leaves, or no one has sent anything for a while), everything about it is gone. The server logs no messages.
- **Room codes that cannot be guessed:** made by a secure random number generator, six characters from an alphabet without look-alikes (no `0`/`O`, `1`/`I`), so about a billion codes; join attempts limited per address, as against password guessing ([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)); rooms that expire. The creator may also lock a room once everyone is in.

### Questions to decide, with recommendations

1. **Waiting:** `Connect` and `Join` return at once and events say what happened (recommended: the events, as Winsock had), or the program waits for them. This follows v0.5's answer for Http.
2. **Text or objects:** `Send` takes text and v0.5's JSON helpers make it (recommended), or `Send` takes a structure directly.
3. **A tray component or `New`:** a `Room` and a `WebSocket` in the designer's tray, like a Timer, with `Server` and `Nickname` in the Properties window (recommended), and `New` too.
4. **The room code:** six characters as above (recommended), or digits only, easier to type on a phone but far fewer.
5. **The public server's limits:** say 100 members per room, 16 KB per message, 20 messages a second per member, rooms ended after 30 idle minutes (recommended starting points).
6. **When the creator leaves:** the room ends (recommended: nothing left behind), or another member takes over.
7. **A dropped connection:** reconnect by itself for 30 seconds keeping the member's place (recommended), or `Closed` at once.
8. **Plain `ws://`:** only to `localhost`, while developing (recommended).
9. **Tests:** a relay server in memory for parity programs, so that a room's transcript is the same on the VM, in Chrome and in the run window (recommended).

---

## The GuBASIC server

**Goal:** a GuBASIC program with no screen, run on a server, so that the server side of a bulletin board or a quiz can be written in GuBASIC too. ASP.NET Web Forms let people make web pages the way they made VB forms ([Microsoft](https://learn.microsoft.com/en-us/aspnet/web-forms/)); this is today's version, but not by sending whole pages back and forth: the client is a GuBASIC web app, and the server answers standard HTTP (JSON) and WebSocket requests.

**When:** after `Room` (v0.6); a candidate, not planned.

### What to check first

- **Running without Flutter:** `gubasic_lang` is pure Dart (hard rule 1), so the interpreter runs on the Dart VM with `dart:io`'s `HttpServer` ([Dart](https://api.dart.dev/dart-io/HttpServer-class.html)); the server needs a host without forms. To be proved with a small server first.
- **"One handler at a time" on a server:** GuBASIC runs one handler at a time and never re-enters one (D5, D28). Node.js also runs JavaScript on one thread, and stays responsive because it waits for input and output without blocking, handling other requests meanwhile ([Node.js](https://nodejs.org/en/learn/asynchronous-work/overview-of-blocking-vs-non-blocking)). Two choices: one request at a time (simple and safe, slow when many arrive together); or a request handler gives up its turn while it waits for the database or the network, as Node.js does. The second means one `Server_Request` handler runs for several requests at once, which hard rule 5 now forbids: it needs a decision of its own, such as "each request is a handler of its own".

### Candidate syntax

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

- `Request`: `Method`, `Path`, `Query(name)`, `Header(name)`, `Body`; `Response`: `Status`, `Header(name)`, `Text(…)`, `Json(…)`.
- A database for the server: the same `Database` (SQLite, [sqlite3](https://pub.dev/packages/sqlite3)) as v0.5, on a file of the server.
- Rooms on the server side: a `Server_Room…` family of events, so that a quiz's rules can live on the server rather than on the TV.
- Deployment: as the relay server, a service on Linux behind Apache as a reverse proxy.

### Security, which it must cover

- **Input:** every request is checked before use (types, lengths, allowed values); nothing from a request is trusted.
- **SQL injection:** queries take values only as parameters (`?`), never by joining text ([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/SQL_Injection_Prevention_Cheat_Sheet.html)); the analyzer warns when a query is built with `&`.
- **Authentication:** passwords stored only as slow hashes, sessions or tokens that expire, limits on attempts ([OWASP](https://cheatsheetseries.owasp.org/cheatsheets/Authentication_Cheat_Sheet.html)).
- **Transport:** HTTPS only, through Apache; no secrets in client apps (hard rule 12).

---

## UserControl

**Goal:** a control made with GuBASIC, from other controls and code, packed so that other GuBASIC users can put it into their toolbox, as Visual Basic 5 and 6 made ActiveX controls from a `UserControl` and its constituent controls ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa263502(v=vs.60))).

**How it would look:** a designer like a form's, where the author draws the control and declares its properties, methods and events; it is saved as a component (`component.yaml` and GuBASIC code), so that the analyzer, the toolbox and the Properties window treat it as any other.

**Pairs with:** the component channel ([COMPONENT_CHANNEL.md](COMPONENT_CHANNEL.md)): that one brings in Dart, this one is made of GuBASIC; both end in the same toolbox.

**When:** after the component channel.

## Exporting a Flutter package

**Goal:** once the transpiler exists (D79), export forms and UserControls made with GuBASIC as a Dart package of widgets that any Flutter app can use. GuBASIC would then also be a way to draw parts of a Flutter app.

**When:** after the transpiler.
