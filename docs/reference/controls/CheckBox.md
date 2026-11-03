# CheckBox

[All of the reference](../README.md)

A box the user checks and unchecks, with a Caption beside it (docs/DESIGN.md D44). Changed runs after Checked changes, also when the program sets Checked (changeEvent), as TextBox.Changed does.

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
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `FontSize` | Double | `(not set)` | not set: its Frame's or its form's |
| `FontBold` | Boolean | `(not set)` | not set: its Frame's or its form's |
| `ForeColor` | Color | `(not set)` | not set: its Frame's or its form's |
| `BackColor` | Color | `(not set)` |  |
| `Tag` | String | `""` |  |

## Events

- `Changed()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `index` → `Tag`
- `text` → `Caption`
- `value` → `Checked`
- `checkedchanged` → `Changed`
