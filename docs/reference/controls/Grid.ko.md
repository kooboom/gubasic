# Grid

[참조 전체](../README.ko.md)

설명은 [LANGUAGE.ko.md 11절](../../LANGUAGE.ko.md)에 있습니다.

기본 이벤트(더블클릭으로 만듦): `Changed`

## 속성

| | 형식 | 처음 값 | 참고 |
|---|---|---|---|
| `Left` | Integer | `0` |  |
| `Top` | Integer | `0` |  |
| `Width` | Integer | `320` |  |
| `Height` | Integer | `160` |  |
| `Anchor` | String | `"Left Top"` |  |
| `ReadOnly` | Boolean | `False` |  |
| `Enabled` | Boolean | `True` |  |
| `Visible` | Boolean | `True` |  |
| `FontSize` | Double | `(not set)` | 정하지 않으면 Frame이나 폼의 것 |
| `FontBold` | Boolean | `(not set)` | 정하지 않으면 Frame이나 폼의 것 |
| `ForeColor` | Color | `(not set)` | 정하지 않으면 Frame이나 폼의 것 |
| `BackColor` | Color | `(not set)` |  |
| `Tag` | String | `""` |  |
| `Row` | Integer | `-1` | 실행 중에만 정함 |
| `Col` | Integer | `-1` | 실행 중에만 정함 |
| `RowCount` | Integer |  | 읽기만 함 |
| `ColumnCount` | Integer |  | 읽기만 함 |

## 메서드

- `Cell(row As Integer, column As number or String) As String` (대입 가능)
- `Header(column As Integer) As String` (대입 가능)
- `ColumnWidth(column As Integer) As Integer` (대입 가능)
- `Column(name As String) As Integer`
- `AddRow() As Integer`
- `AddColumn(name As String)`
- `Clear()`
- `LoadCsv(path As String)`
- `SaveCsv(path As String)`

## 이벤트

- `Changed()`
- `Click()`
- `MouseDown(e As MouseEventArgs)`
- `MouseUp(e As MouseEventArgs)`

## 다른 BASIC에서 쓰는 이름

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
