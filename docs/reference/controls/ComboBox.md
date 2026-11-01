# ComboBox

[All of the reference](../README.md)

A closed list that opens to pick one item (docs/DESIGN.md D104): Visual Basic 6's ComboBox with Style 2, the user picks and does not type. The program fills it and reads it as a ListBox (D46): AddItem, List, ListCount, ListIndex and Text, and Changed runs whenever ListIndex changes.

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Changed`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `160` |  |
| `Height` | Integer | `32` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Tag` | String | `""` |  |
| `ListIndex` | Integer | `-1` | set only while the program runs |
| `ListCount` | Integer |  | read only |
| `Text` | String |  | read only |

## Methods

- `AddItem(item As String)`
- `RemoveItem(index As Integer)`
- `Clear()`
- `List(index As Integer) As String`

## Events

- `Changed()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `index` → `Tag`
- `selectedindex` → `ListIndex`
- `items` → `AddItem`, `List`, `ListCount`
- `selectedindexchanged` → `Changed`
- `click` → `Changed`
