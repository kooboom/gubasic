# Grid

[All of the reference](../README.md)

A table of text the user reads and edits (docs/DESIGN.md D116), as Visual Basic's grids: named columns, rows and columns counted from 0, the header row not among them. A click chooses a cell (Row, Col) and runs Click; a second click on it, Enter, F2 or typing edits it unless ReadOnly, and Changed runs when the user has changed it, Row and Col on that cell. The program's own changes run nothing. LoadCsv and SaveCsv read and write it as a CSV file, as Csv.Read and Csv.Write do (D114).

Explained in [LANGUAGE.md §11](../../LANGUAGE.md).

Default event (made by a double-click): `Changed`

## Properties

| | Type | At first | Notes |
|---|---|---|---|
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `320` |  |
| `Height` | Integer | `160` |  |
| `Anchor` | String | `"Left Top"` |  |
| `ReadOnly` | Boolean | `False` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `FontSize` | Double | `(not set)` | not set: its Frame's or its form's |
| `FontBold` | Boolean | `(not set)` | not set: its Frame's or its form's |
| `ForeColor` | Color | `(not set)` | not set: its Frame's or its form's |
| `BackColor` | Color | `(not set)` |  |
| `Tag` | String | `""` |  |
| `Row` | Integer | `-1` | set only while the program runs |
| `Col` | Integer | `-1` | set only while the program runs |
| `RowCount` | Integer |  | read only |
| `ColumnCount` | Integer |  | read only |

## Methods

- `Cell(row As Integer, column As number or String) As String` (can be assigned to)
- `Header(column As Integer) As String` (can be assigned to)
- `ColumnWidth(column As Integer) As Integer` (can be assigned to)
- `Column(name As String) As Integer`
- `AddRow() As Integer`
- `AddColumn(name As String)`
- `Clear()`
- `LoadCsv(path As String)`
- `SaveCsv(path As String)`

## Events

- `Changed()`
- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## Names other versions of BASIC use

- `DataGridView` → `Grid`
- `MSFlexGrid` → `Grid`
- `index` → `Tag`
- `textmatrix` → `Cell`
- `rows` → `RowCount`
- `cols` → `ColumnCount`
- `colwidth` → `ColumnWidth`
- `currentrow` → `Row`
- `cellvaluechanged` → `Changed`
- `cellclick` → `Click`
