# ComboBox

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

기본 이벤트(더블클릭으로 만듦): `Changed`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `160` |  |
| `Height` | Integer | `32` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Tag` | String | `""` |  |
| `ListIndex` | Integer | `-1` | 실행 중에만 정함 |
| `ListCount` | Integer |  | 읽기만 함 |
| `Text` | String |  | 읽기만 함 |

## 메서드

- `AddItem(item As String)`
- `RemoveItem(index As Integer)`
- `Clear()`
- `List(index As Integer) As String`

## 이벤트

- `Changed()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## 다른 BASIC에서 쓰는 이름

- `index` → `Tag`
- `selectedindex` → `ListIndex`
- `items` → `AddItem`, `List`, `ListCount`
- `selectedindexchanged` → `Changed`
- `click` → `Changed`
