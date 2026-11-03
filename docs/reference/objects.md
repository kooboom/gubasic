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

### Json

- `Json.Parse(text As String) As Json`
- `Json.Array() As Json`

### Color

- `Color.Black As Color`
- `Color.White As Color`
- `Color.Red As Color`
- `Color.Green As Color`
- `Color.Blue As Color`
- `Color.Yellow As Color`
- `Color.Orange As Color`
- `Color.Purple As Color`
- `Color.Pink As Color`
- `Color.Brown As Color`
- `Color.Gray As Color`
- `Color.DarkGray As Color`
- `Color.LightGray As Color`
- `Color.Silver As Color`
- `Color.WhiteSmoke As Color`
- `Color.Navy As Color`
- `Color.DarkBlue As Color`
- `Color.RoyalBlue As Color`
- `Color.SkyBlue As Color`
- `Color.LightBlue As Color`
- `Color.Teal As Color`
- `Color.Cyan As Color`
- `Color.Aqua As Color`
- `Color.Turquoise As Color`
- `Color.Lime As Color`
- `Color.LightGreen As Color`
- `Color.DarkGreen As Color`
- `Color.Olive As Color`
- `Color.Maroon As Color`
- `Color.DarkRed As Color`
- `Color.Crimson As Color`
- `Color.Tomato As Color`
- `Color.Coral As Color`
- `Color.Salmon As Color`
- `Color.Gold As Color`
- `Color.LightYellow As Color`
- `Color.Khaki As Color`
- `Color.Beige As Color`
- `Color.Ivory As Color`
- `Color.Tan As Color`
- `Color.Chocolate As Color`
- `Color.Magenta As Color`
- `Color.Fuchsia As Color`
- `Color.Violet As Color`
- `Color.Lavender As Color`
- `Color.Indigo As Color`
- `Color.Transparent As Color`
- `Color.Empty As Color`
- `Color.FromArgb(red As Integer, green As Integer, blue As Integer) As Color`

### Database

Keeps a program's data in an SQLite database file (docs/DESIGN.md D124, D126), the way Visual Basic 6 kept it in a Jet database through Data Access Objects (https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa227845(v=vs.60)). A built-in object used by its name, not put on a form. Every app has a database of its own, data.db in the app's own data folder, opened when first used; Database.Open(name) opens another file there instead. Execute(sql, values…) runs a statement and gives how many rows it changed; Query(sql, values…) gives the rows as a Table; Scalar(sql, values…) gives the first value of the first row as text, "" for NULL or no row, and LastWasNull says which. A value goes into the SQL as a ?, and after it in the call: Database.Execute("INSERT INTO scores(name, points) VALUES (?, ?)", txtName.Text, points); a quote in the value then cannot break the statement. Integer, Double and String go in as they are, Boolean as 1 or 0, Date as "yyyy-MM-dd HH:mm:ss", Nothing as NULL. LastId is the row ID the last INSERT gave; Path is where the file is; Close() closes it (the next use opens it again). Export(path) writes the database as a file, a backup, where File writes files (on the web, a download); Import(path) replaces the database with such a file, one chosen with OpenFileDialog or exported in this run on the web. SQL the database cannot run is R042; a name that is not a file name is R043; a database that cannot be opened is R044; a file that is not an SQLite database is R045. SQL joined with & is a warning (A060).

- `Database.Path As String`
- `Database.LastWasNull As Boolean`
- `Database.LastId As Integer`
- `Database.Open(name As String)`
- `Database.Execute(sql As String, ParamArray values As number, Boolean, String, Date or Nothing) As Integer`
- `Database.Query(sql As String, ParamArray values As number, Boolean, String, Date or Nothing) As Table`
- `Database.Scalar(sql As String, ParamArray values As number, Boolean, String, Date or Nothing) As String`
- `Database.Close()`
- `Database.Export(path As String)`
- `Database.Import(path As String)`

### Http

Talks to web servers over HTTP (docs/DESIGN.md D124, D125), the way Visual Basic 6's Internet Transfer Control did with OpenURL (https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa733648(v=vs.60)). A built-in object used by its name, not put on a form: Http.Get(url) gives the answer's text, Http.GetJson(url) its JSON, Http.Post(url, body) and Http.PostJson(url, json) send a body and give the answer, and Http.Send(method, url, body) gives the whole answer as an HttpResponse, whatever its status. A call waits where it is, as File.ReadAllText does: the screen keeps drawing, the pointer shows waiting, and clicks made meanwhile run after it, in turn. Header(name) is a header sent with every request from then on, to every server the program calls ("" takes it away), so a key, a token or a password does not belong there (A076): Send takes, after the body, headers for that one request, each written "Name: value", and one named there replaces a Header of the same name for that request (D135). Timeout is how many seconds to wait for an answer. A request that gets no answer is R036; a status from 400 is R037 in all but Send; text that is not JSON is R039; a header for Send that is not written "Name: value" is R046. The first component through the component channel (docs/COMPONENT_CHANNEL.md).

- `Http.Timeout As Integer (can be set)`
- `Http.Get(url As String) As String`
- `Http.Post(url As String, body As String) As String`
- `Http.GetJson(url As String) As Json`
- `Http.PostJson(url As String, body As Json) As Json`
- `Http.Send(method As String, url As String, body As String, ParamArray headers As String) As HttpResponse`
- `Http.Header(name As String) As String (can be assigned to)`

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

### MessageEventArgs

- `Text As String`
- `Json As Json`

### CloseEventArgs

- `Reason As String`

### ErrorEventArgs

- `Message As String`

### RoomEventArgs

- `Member As String`
- `Nickname As String`
- `Text As String`
- `Json As Json`
- `Reason As String`
- `Message As String`

### Color

- `R As Integer`
- `G As Integer`
- `B As Integer`
- `A As Integer`
- `IsEmpty As Boolean`
- `Name As String`

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

### Json

- `Kind As String`
- `Count As Integer`
- `AsString As String`
- `AsInteger As Integer`
- `AsDouble As Double`
- `AsBoolean As Boolean`
- `Keys As String()`
- `Text As String`
- `Has(name As String) As Boolean`
- `Add(value As number, Boolean, String, Json or Nothing)`
- `Remove(member As number or String)`

### HttpResponse

- `Status As Integer`
- `Ok As Boolean`
- `Text As String`
- `Json As Json`
- `Header(name As String) As String`

## Structures

A program's own types: `Structure Student … End Structure`, fields only,
in a module for the whole project or in a form for that form.
Explained in [LANGUAGE.md §4.1](../LANGUAGE.md).

- A Structure is copied when it is stored (assigned, passed, returned, put
  into an array or a List), **its array fields too**. A plain array
  assigned to another variable (`y = x`) is **the same array**.
- A field is changed where the value is: `list(0).Score = 95` changes the
  item of a `List(Of Student)`. Visual Basic .NET refuses this (BC30068).
- For Each gives copies (A066). Not done with a Structure: comparing it
  (A063), text (A064), `Object` (A067).
- A value in one expression: `New Student With {.Name = "Kim", .Score = 90}`.
  Lists of items for arrays: `.Choices = {"a", "b", "c", "d"}`,
  `Dim names() As String = {"Kim", "Lee"}`, `Total({4, 5, 6})`. Inside the
  braces a line may break without `_` (LANGUAGE §1, §4).

## Constants

- `vbCrLf`: `\r\n`
- `vbNewLine`: `\r\n`
- `vbLf`: `\n`
- `vbCr`: `\r`
- `vbTab`: `\t`
