# Frame

[All of the reference](../README.md)

A box with a Caption on its edge that holds other controls (docs/DESIGN.md D105). The controls in it are placed from its top-left corner, anchored to its edges, and move with it; its OptionButtons are a group of their own, as in Visual Basic 6.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Click`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `200` |  |
| `Height` | Integer | `120` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Tag` | String | `""` |  |

## Events

- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `GroupBox` → `Frame`
- `index` → `Tag`
- `text` → `Caption`
