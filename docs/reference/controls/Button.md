# Button

[All of the reference](../README.md)

A button the user clicks: its Caption is the text on it, and Click runs when it is clicked.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Click`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `96` |  |
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

- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `CommandButton` → `Button`
- `index` → `Tag`
- `text` → `Caption`
