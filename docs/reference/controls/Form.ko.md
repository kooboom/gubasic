# Form

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

기본 이벤트(더블클릭으로 만듦): `Load`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Width` | Integer | `480` |  |
| `Height` | Integer | `360` |  |
| `Tag` | String | `""` |  |
| `KeyPreview` | Boolean | `False` |  |
| `DialogResult` | Integer | `0` | 실행 중에만 정함 |

## 메서드

- `Show()`
- `ShowDialog() As Integer`
- `Hide()`
- `Close()`
- `PopupMenu(menu As Menu)`

## 이벤트

- `Load()`
- `Resize()`
- `Closed()`
- `KeyDown(e As KeyEventArgs)`
- `KeyUp(e As KeyEventArgs)`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## 다른 BASIC에서 쓰는 이름

- `text` → `Caption`
