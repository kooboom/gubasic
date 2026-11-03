# WebSocket

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

폼에 보이지 않음: 디자이너의 트레이에 둠.

기본 이벤트(더블클릭으로 만듦): `Message`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `State` | String |  | 읽기만 함 |
| `Url` | String |  | 읽기만 함 |
| `Tag` | String | `""` |  |

## 메서드

- `Connect(url As String)`
- `Send(text As String)`
- `Close()`

## 이벤트

- `Message(e As MessageEventArgs)`
- `Closed(e As CloseEventArgs)`
- `Error(e As ErrorEventArgs)`

## 다른 BASIC에서 쓰는 이름

- `senddata` → `Send`
- `remotehost` → `Connect`
- `dataarrival` → `Message`
