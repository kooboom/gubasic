# Functions

[All of the reference](README.md)

## Text

- `Len(text As String) As Integer`: The number of characters in text.
- `Left(text As String, length As Integer) As String`: The first length characters of text.
- `Right(text As String, length As Integer) As String`: The last length characters of text.
- `Mid(text As String, start As Integer, [length As Integer]) As String`: Characters of text from start (counted from 1), length of them or to the end.
- `InStr(text As String, find As String) As Integer`: Where find first comes in text, counted from 1; 0 when it does not.
- `UCase(text As String) As String`: text in capital letters.
- `LCase(text As String) As String`: text in small letters.
- `Trim(text As String) As String`: text without spaces at either end.
- `Replace(text As String, find As String, with As String) As String`: text with every find replaced by with.
- `Split(text As String, separator As String) As String()`: text cut at each separator, as an array.
- `Join(items As String(), separator As String) As String`: The items of an array joined with separator.

## Conversion

- `CInt(value As number or String) As Integer`: value as an Integer, rounding halves away from zero; text is read as a number.
- `CDbl(value As number or String) As Double`: value as a Double; text is read as a number.
- `CStr(value As any value) As String`: value as text.
- `CBool(value As number, Boolean or String) As Boolean`: value as a Boolean.
- `Val(text As String) As Double`: The number at the start of text, 0 when there is none.
- `Str(value As Integer or Double) As String`: A number as text.

## Math

- `Abs(value As Integer or Double) As Double`: The size of a number, without its sign.
- `Int(value As Double) As Integer`: The largest Integer not above value.
- `Round(value As Double, [digits As Integer]) As Double`: value rounded to digits decimals (0 when left out), halves away from zero.
- `Sqr(value As Double) As Double`: The square root.
- `Rnd() As Double`: A random Double from 0 up to, not including, 1.
- `Randomize([seed As Integer])`: Starts the random numbers again, from seed when given.
- `Min(a As Integer or Double, b As Integer or Double) As Double`: The smaller of two numbers.
- `Max(a As Integer or Double, b As Integer or Double) As Double`: The larger of two numbers.

## Arrays

- `UBound(items As array) As Integer`: The largest index of an array.

## Date and time

- `Now() As Date`: The date and time now, on this device.
- `Today() As Date`: Today's date, at midnight.
- `Milliseconds() As Integer`: The milliseconds since the program started, from a clock that only goes forward (for a game loop).
- `Year(date As Date) As Integer`: The year of a date.
- `Month(date As Date) As Integer`: The month of a date, 1 to 12.
- `Day(date As Date) As Integer`: The day of a date.
- `Hour(date As Date) As Integer`: The hour of a date, 0 to 23.
- `Minute(date As Date) As Integer`: The minute of a date.
- `Second(date As Date) As Integer`: The second of a date.
- `DateAdd(interval As String, number As Integer, date As Date) As Date`: date with number intervals added: "yyyy", "q", "m", "d", "ww", "h", "n", "s", or DateInterval.
- `DateDiff(interval As String, date1 As Date, date2 As Date) As Integer`: How many intervals from date1 to date2.
- `Format(value As any value, format As String) As String`: A date or a number written with a .NET format string: custom ("yyyy-MM-dd", "#,##0") or standard ("d", "N2", "C").

## Dialogs

- `MsgBox(prompt As String, [title As String])`: Shows a message and waits for OK.
- `InputBox(prompt As String, [title As String], [default As String]) As String`: Asks for a line of text; "" when cancelled.

## Program

- `DoEvents()`: Lets the screen draw and other events run, then goes on.

## Settings

- `SaveSetting(key As String, value As String)`: Keeps a value under key for this app.
- `GetSetting(key As String, default As String) As String`: The value kept under key, or default.
