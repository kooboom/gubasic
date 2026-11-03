# TextBox

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

기본 이벤트(더블클릭으로 만듦): `Changed`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Text` | String | `""` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `160` |  |
| `Height` | Integer | `32` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `FontSize` | Double | `(not set)` | 정하지 않으면 Frame이나 폼의 것 |
| `FontBold` | Boolean | `(not set)` | 정하지 않으면 Frame이나 폼의 것 |
| `ForeColor` | Color | `(not set)` | 정하지 않으면 Frame이나 폼의 것 |
| `BackColor` | Color | `(not set)` |  |
| `Tag` | String | `""` |  |

## 이벤트

- `Changed()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## 다른 BASIC에서 쓰는 이름

- `index` → `Tag`
- `textchanged` → `Changed`
- `change` → `Changed`
