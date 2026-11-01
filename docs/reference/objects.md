# Objects and types

[All of the reference](README.md)

## Built-in objects

### Debug

- `Debug.Print(value As any value)`

### Integer

- `Integer.MaxValue As Integer`
- `Integer.MinValue As Integer`

### Keys

- `Keys.Back As Integer`
- `Keys.Tab As Integer`
- `Keys.Enter As Integer`
- `Keys.Escape As Integer`
- `Keys.Space As Integer`
- `Keys.PageUp As Integer`
- `Keys.PageDown As Integer`
- `Keys.End As Integer`
- `Keys.Home As Integer`
- `Keys.Left As Integer`
- `Keys.Up As Integer`
- `Keys.Right As Integer`
- `Keys.Down As Integer`
- `Keys.Insert As Integer`
- `Keys.Delete As Integer`
- `Keys.D0 As Integer`
- `Keys.D1 As Integer`
- `Keys.D2 As Integer`
- `Keys.D3 As Integer`
- `Keys.D4 As Integer`
- `Keys.D5 As Integer`
- `Keys.D6 As Integer`
- `Keys.D7 As Integer`
- `Keys.D8 As Integer`
- `Keys.D9 As Integer`
- `Keys.A As Integer`
- `Keys.B As Integer`
- `Keys.C As Integer`
- `Keys.D As Integer`
- `Keys.E As Integer`
- `Keys.F As Integer`
- `Keys.G As Integer`
- `Keys.H As Integer`
- `Keys.I As Integer`
- `Keys.J As Integer`
- `Keys.K As Integer`
- `Keys.L As Integer`
- `Keys.M As Integer`
- `Keys.N As Integer`
- `Keys.O As Integer`
- `Keys.P As Integer`
- `Keys.Q As Integer`
- `Keys.R As Integer`
- `Keys.S As Integer`
- `Keys.T As Integer`
- `Keys.U As Integer`
- `Keys.V As Integer`
- `Keys.W As Integer`
- `Keys.X As Integer`
- `Keys.Y As Integer`
- `Keys.Z As Integer`
- `Keys.NumPad0 As Integer`
- `Keys.NumPad1 As Integer`
- `Keys.NumPad2 As Integer`
- `Keys.NumPad3 As Integer`
- `Keys.NumPad4 As Integer`
- `Keys.NumPad5 As Integer`
- `Keys.NumPad6 As Integer`
- `Keys.NumPad7 As Integer`
- `Keys.NumPad8 As Integer`
- `Keys.NumPad9 As Integer`
- `Keys.F1 As Integer`
- `Keys.F2 As Integer`
- `Keys.F3 As Integer`
- `Keys.F4 As Integer`
- `Keys.F5 As Integer`
- `Keys.F6 As Integer`
- `Keys.F7 As Integer`
- `Keys.F8 As Integer`
- `Keys.F9 As Integer`
- `Keys.F10 As Integer`
- `Keys.F11 As Integer`
- `Keys.F12 As Integer`

### DialogResult

- `DialogResult.None As Integer`
- `DialogResult.OK As Integer`
- `DialogResult.Cancel As Integer`
- `DialogResult.Yes As Integer`
- `DialogResult.No As Integer`

### MouseButtons

- `MouseButtons.Left As Integer`
- `MouseButtons.Right As Integer`
- `MouseButtons.Middle As Integer`

### File

- `File.ReadAllText(path As String) As String`
- `File.ReadAllLines(path As String) As String()`
- `File.WriteAllText(path As String, text As String)`
- `File.AppendAllText(path As String, text As String)`
- `File.Exists(path As String) As Boolean`

### Csv

- `Csv.Read(path As String) As Table`
- `Csv.Write(path As String, table As Table)`

### DateInterval

- `DateInterval.Year As String`
- `DateInterval.Quarter As String`
- `DateInterval.Month As String`
- `DateInterval.DayOfYear As String`
- `DateInterval.Day As String`
- `DateInterval.Weekday As String`
- `DateInterval.WeekOfYear As String`
- `DateInterval.Hour As String`
- `DateInterval.Minute As String`
- `DateInterval.Second As String`

## Members of types

### String

- `Length As Integer`
- `Substring(start As Integer, [length As Integer]) As String`
- `IndexOf(text As String) As Integer`
- `Contains(text As String) As Boolean`
- `StartsWith(text As String) As Boolean`
- `EndsWith(text As String) As Boolean`
- `Replace(find As String, with As String) As String`
- `ToUpper() As String`
- `ToLower() As String`
- `Trim() As String`
- `Split(separator As String) As String()`

### List(Of String)

- `Count As Integer`
- `Add(item As String)`
- `Insert(index As Integer, item As String)`
- `Remove(item As String) As Boolean`
- `RemoveAt(index As Integer)`
- `Clear()`
- `Contains(item As String) As Boolean`
- `IndexOf(item As String) As Integer`

### String()

- `Length As Integer`

### Exception

- `Message As String`

### KeyEventArgs

- `KeyCode As Integer`
- `Shift As Boolean`
- `Control As Boolean`
- `Alt As Boolean`

### MouseEventArgs

- `Button As Integer`
- `X As Integer`
- `Y As Integer`

### Table

- `RowCount As Integer`
- `ColumnCount As Integer`
- `Cell(row As Integer, column As number or String) As String (can be assigned to)`
- `Header(column As Integer) As String (can be assigned to)`
- `Column(name As String) As Integer`
- `AddRow() As Integer`
- `AddColumn(name As String)`
- `Clear()`

### PdfDocument

- `Landscape As Boolean (can be set)`
- `TitleSize As Double (can be set)`
- `TextSize As Double (can be set)`
- `TableSize As Double (can be set)`
- `AddTitle(text As String)`
- `AddText(text As String)`
- `AddTable(table As Table or Grid)`
- `NewPage()`
- `Save(path As String)`

## Constants

- `vbCrLf`: `\r\n`
- `vbNewLine`: `\r\n`
- `vbLf`: `\n`
- `vbCr`: `\r`
- `vbTab`: `\t`
