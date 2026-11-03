# WebSocket

[All of the reference](../README.md)

Talks to any standard WebSocket server (RFC 6455) in text messages (docs/DESIGN.md D122, D136), today's version of what Visual Basic 6 programs did with the Winsock control (https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa228119(v=vs.60)). Like a Timer it is not seen on the form: the designer keeps it in the tray. Connect(url) waits where it is called until the connection is open, as Http does (D124 A): the screen keeps drawing and the pointer shows waiting; a connection that cannot be opened is R047. Send(text) sends one message; while the connection is not open it is R049. Close() closes it. Message runs for each message that comes, in order, one at a time (e.Text, and e.Json read from it); Closed when the server closes the connection or it is lost (e.Reason); Error for a problem after it was open (e.Message). Through the component channel (docs/COMPONENT_CHANNEL.md): the first component with events.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Not seen on the form: kept in the designer's tray.

Default event (made by a double-click): `Message`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `State` | String |  | read only |
| `Url` | String |  | read only |
| `Tag` | String | `""` |  |

## Methods

- `Connect(url As String)`
- `Send(text As String)`
- `Close()`

## Events

- `Message(e As MessageEventArgs)`
- `Closed(e As CloseEventArgs)`
- `Error(e As ErrorEventArgs)`

## Names other versions of BASIC use

- `senddata` → `Send`
- `remotehost` → `Connect`
- `dataarrival` → `Message`
