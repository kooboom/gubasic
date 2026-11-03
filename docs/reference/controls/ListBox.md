# ListBox

[All of the reference](../README.md)

A list the user picks one item from (docs/DESIGN.md D46). The program fills it with AddItem and reads it with List, ListCount, ListIndex and Text. Changed runs whenever ListIndex changes: the user picks an item, the program sets ListIndex, or RemoveItem / Clear changes it. Items are set only in code for now (docs/KNOWN_ISSUES.md).

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Changed`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `160` |  |
| `Height` | Integer | `120` |  |
| `Anchor` | String | `"Left Top"` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `FontSize` | Double | `(not set)` | not set: its Frame's or its form's |
| `FontBold` | Boolean | `(not set)` | not set: its Frame's or its form's |
| `ForeColor` | Color | `(not set)` | not set: its Frame's or its form's |
| `BackColor` | Color | `(not set)` |  |
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
