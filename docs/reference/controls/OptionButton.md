# OptionButton

[All of the reference](../README.md)

One of a group of choices, of which one is checked (docs/DESIGN.md D104): the OptionButtons of a form are one group. Checking one, by a click or in code, unchecks the others. Changed runs when it becomes checked, as Visual Basic 6's Click did; the ones it unchecks raise nothing, so one handler for the whole group runs once.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Changed`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Checked` | Boolean | `False` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `120` |  |
| `Height` | Integer | `32` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Tag` | String | `""` |  |

## Events

- `Changed()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `RadioButton` → `OptionButton`
- `index` → `Tag`
- `text` → `Caption`
- `value` → `Checked`
- `checkedchanged` → `Changed`
- `click` → `Changed`
