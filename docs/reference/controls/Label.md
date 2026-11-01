# Label

[All of the reference](../README.md)

Text on the form that the user reads but does not type into: its Caption. Click runs when it is clicked.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Click`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Caption` | String | `""` |  |
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `120` |  |
| `Height` | Integer | `24` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Tag` | String | `""` |  |

## Events

- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `index` → `Tag`
- `text` → `Caption`
