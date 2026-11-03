# Room

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

폼에 보이지 않음: 디자이너의 트레이에 둠.

기본 이벤트(더블클릭으로 만듦): `Message`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Server` | String | `""` |  |
| `Nickname` | String | `""` |  |
| `Code` | String |  | 읽기만 함 |
| `Me` | String |  | 읽기만 함 |
| `IsHost` | Boolean |  | 읽기만 함 |
| `Members` | String() |  | 읽기만 함 |
| `Tag` | String | `""` |  |

## 메서드

- `Create()`
- `Join(code As String, nickname As String)`
- `Send(text As String)`
- `SendTo(member As String, text As String)`
- `Leave()`
- `Lock()`
- `NicknameOf(member As String) As String`

## 이벤트

- `Message(e As RoomEventArgs)`
- `Joined(e As RoomEventArgs)`
- `Left(e As RoomEventArgs)`
- `Closed(e As RoomEventArgs)`
- `Error(e As RoomEventArgs)`
