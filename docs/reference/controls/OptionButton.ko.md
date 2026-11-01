# OptionButton

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

기본 이벤트(더블클릭으로 만듦): `Changed`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Checked` | Boolean | `False` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `120` |  |
| `Height` | Integer | `32` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Tag` | String | `""` |  |

## 이벤트

- `Changed()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## 다른 BASIC에서 쓰는 이름

- `RadioButton` → `OptionButton`
- `index` → `Tag`
- `text` → `Caption`
- `value` → `Checked`
- `checkedchanged` → `Changed`
- `click` → `Changed`
