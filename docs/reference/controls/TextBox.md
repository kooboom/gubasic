# TextBox

[All of the reference](../README.md)

A box the user types a line of text into: its Text. Changed runs after the text changes, also when the program sets Text (changeEvent). Text holds only the characters the input method (IME) has committed, and Changed runs each time it commits one (docs/LANGUAGE.md §11.1).

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Changed`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Text` | String | `""` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `160` |  |
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
- `textchanged` → `Changed`
- `change` → `Changed`
