# Room

[All of the reference](../README.md)

Puts programs with the same room code together through a relay server (docs/DESIGN.md D122, D136; the protocol: docs/ROOM_PROTOCOL.md): the TV's program calls Create() and shows Code, the phones' call Join(code, nickname), and each Send reaches the others as Message. Like a Timer it is not seen on the form: the designer keeps it in the tray. Create and Join wait where they are called until the program is in the room, as Http waits (D124 A); a room that cannot be entered is R048, with the server's reason. Server is the relay server's address (wss://relay.example.com/room); empty, the desktop IDE's own relay server while developing. Send while not in a room is R049. A lost connection comes back by itself within 30 seconds, keeping the program's place; Sends meanwhile wait. Events run in turn, as a WebSocket's do; every e is a RoomEventArgs.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Not seen on the form: kept in the designer's tray.

Default event (made by a double-click): `Message`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Server` | String | `""` |  |
| `Nickname` | String | `""` |  |
| `Code` | String |  | read only |
| `Me` | String |  | read only |
| `IsHost` | Boolean |  | read only |
| `Members` | String() |  | read only |
| `Tag` | String | `""` |  |

## Methods

- `Create()`
- `Join(code As String, nickname As String)`
- `Send(text As String)`
- `SendTo(member As String, text As String)`
- `Leave()`
- `Lock()`
- `NicknameOf(member As String) As String`

## Events

- `Message(e As RoomEventArgs)`
- `Joined(e As RoomEventArgs)`
- `Left(e As RoomEventArgs)`
- `Closed(e As RoomEventArgs)`
- `Error(e As RoomEventArgs)`
