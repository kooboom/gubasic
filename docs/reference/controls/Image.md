# Image

[All of the reference](../README.md)

A picture from the project (docs/DESIGN.md D51). Picture names one of the project's pictures (pictures/ in its folder), in any case; "" shows none. Stretch: True fills the control, maybe changing the picture's proportions; False (the default) fits the whole picture inside, keeping them. Unlike Visual Basic 6, the control never changes its own size to the picture's. Drawn under the other controls, Labels too (D139).

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Click`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Picture` | String | `""` |  |
| `Stretch` | Boolean | `False` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `120` |  |
| `Height` | Integer | `120` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `BackColor` | Color | `(not set)` |  |
| `Tag` | String | `""` |  |

## Methods

- `BringToFront()`
- `SendToBack()`

## Events

- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `PictureBox` → `Image`
- `index` → `Tag`
- `image` → `Picture`
- `sizemode` → `Stretch`
