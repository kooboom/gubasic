# GuBASIC Language (draft)

[한국어](LANGUAGE.ko.md)

GuBASIC is a simplified, VB.NET-flavored BASIC. This is a **draft**: it fixes the decisions that are hard to change later and leaves the rest open.

---

## 1. Lexical rules

| Rule | Decision |
|---|---|
| Case | **Case-insensitive.** The editor rewrites every use to the spelling of its declaration, as VB did. The transpiler emits that spelling. |
| Identifiers | **ASCII only:** a letter, then letters, digits or `_`. Korean (and any non-ASCII) text is allowed in strings and comments. |
| Comments | `'` to end of line. `REM` also accepted. |
| Line continuation | A line ending with `_` continues on the next line. |
| Statements per line | One. (`:` separators are not supported.) |
| String literals | `"..."`; a doubled quote `""` is a literal quote. |
| Dart reserved words | If an identifier collides with a Dart keyword (`var`, `class`, `is`, `new`, …), the transpiler renames it automatically. Users never see this. |

## 2. Types

| GuBASIC | Dart | Default value |
|---|---|---|
| `Integer` | `int` | `0` |
| `Double` | `double` | `0.0` |
| `Boolean` | `bool` | `False` |
| `String` | `String` | `""` |
| `Date` | `DateTime` | 0001-01-01 |
| `Object` | `Object?` | `Nothing` |
| `List(Of T)` | `List<T>` | empty list (when declared with `New`) |
| Control / component types (`Button`, `Label`, …) | runtime classes | `Nothing` |

- **`Integer` is 64-bit** on native platforms. On the web it is a JavaScript number, exact only up to 2⁵³ (about 9 × 10¹⁵). Ordinary apps never reach this.
- **`Nothing` (null) exists only for objects.** Value types always have a value, so beginners rarely meet null errors.
- There is **no `Variant`**. Use `Object` when a variable really must hold anything.

## 3. Variables

### 3.1 Declaration

```vb
Dim score As Integer          ' explicit type
Dim name = "Jekyll"           ' type inferred as String
Dim total As Integer = 100    ' type and initial value
```

**Declaration is always required** (`Option Explicit` is permanently on). Using an undeclared name is a compile error — this catches typos.

### 3.2 Scope and lifetime

| Kind | Where / how | Visible in | Lives until |
|---|---|---|---|
| Local | `Dim` inside a `Sub` / `Function` | that procedure | the call returns |
| Form-level | `Dim` (or `Private`) at the top of a form's code | every procedure of that form | the form closes |
| Global | `Public` in a module file (`Module1.gbas`) | the whole app | the app exits |
| Static | `Static` inside a procedure | that procedure | the app exits (value kept between calls) |

```vb
Sub btnCount_Click()
    Static count As Integer
    count = count + 1
    lblCount.Caption = count
End Sub
```

Dart has no static locals; the transpiler turns each `Static` into a hidden form-level field.

### 3.3 Constants

```vb
Const MaxScore As Integer = 100
```

## 4. Arrays and lists

- **Arrays are zero-based, and the number in `Dim` is the upper bound** (as in VB.NET). `Dim a(5)` has six elements, `a(0)` to `a(5)`.
- Dynamic arrays:

  ```vb
  Dim a() As Integer
  ReDim a(9)              ' 10 elements, cleared
  ReDim Preserve a(19)    ' 20 elements, old values kept
  ```

- `UBound(a)` returns the upper bound.
- New code is encouraged to use lists:

  ```vb
  Dim names As New List(Of String)
  names.Add("Kim")
  For Each n In names
      lstNames.AddItem(n)
  Next
  ```

## 5. Operators

| Kind | Operators |
|---|---|
| Arithmetic | `+ - * /` (`/` always gives `Double`), `\` integer division, `Mod`, `^` power |
| String concatenation | `&` (recommended); `+` also works for two strings |
| Comparison | `= <> < > <= >=` |
| Logical | `Not`, `And`, `Or`, `Xor` |
| Assignment | `=` (as a statement) |

- **`And` and `Or` short-circuit.** There is no `AndAlso` / `OrElse`.
- `&` converts numbers to strings automatically: `"Score: " & 90`.

## 6. Control flow

```vb
If score >= 90 Then
    grade = "A"
ElseIf score >= 80 Then
    grade = "B"
Else
    grade = "C"
End If

Select Case day
    Case 1, 7
        kind = "Weekend"
    Case 2 To 6
        kind = "Weekday"
    Case Else
        kind = "?"
End Select

For i = 1 To 10 Step 2
Next

For Each item In items
Next

Do While running
    DoEvents
Loop

Do
Loop Until done
```

`Exit For`, `Exit Do`, `Exit Sub`, `Exit Function` are supported. `GoTo` is not.

## 7. Procedures

```vb
Sub ShowScore(name As String, score As Integer)
    MsgBox(name & ": " & score)
End Sub

Function Average(a As Integer, b As Integer) As Double
    Return (a + b) / 2
End Function
```

- Parentheses are always used in calls: `ShowScore("Kim", 90)`.
- Parameters are passed **by value**. `ByRef` is planned for stage 2.
- Optional parameters: `Optional title As String = "Info"`.

## 8. Events

- A handler is a `Sub` named `ControlName_EventName`: `btnSave_Click`, `txtName_Changed`, `Form_Load`.
- Double-clicking a control in the designer creates the handler for its default event.
- Renaming a control renames its handlers.
- Stage 2: `Handles` lets one procedure handle several events.

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

- While a handler is still running (for example waiting on `MsgBox` or `Http.Get`), the same event will not start it again.

## 9. Error handling

```vb
Try
    Dim text = File.ReadAll("data.txt")
    lblInfo.Caption = Len(text) & " characters"
Catch ex As Exception
    MsgBox("Could not open the file: " & ex.Message)
Finally
    lblStatus.Caption = "Done"
End Try
```

- `Throw New Exception("message")` raises an error.
- `On Error GoTo` and `On Error Resume Next` are **not** supported.
- An unhandled error stops the program and highlights the line in the IDE with a plain-language explanation.

## 10. Built-in functions (initial set)

String functions follow classic BASIC and **count from 1**. String *methods* (`.Substring`, `.IndexOf`) count from 0, as in VB.NET.

| Group | Functions |
|---|---|
| String | `Len`, `Left`, `Right`, `Mid`, `InStr`, `UCase`, `LCase`, `Trim`, `Replace`, `Split`, `Join` |
| Conversion | `CInt`, `CDbl`, `CStr`, `CBool`, `Val`, `Str` |
| Math | `Abs`, `Int`, `Round`, `Sqr`, `Rnd`, `Randomize`, `Min`, `Max` |
| Date | `Now`, `Today`, `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second` |
| Dialogs | `MsgBox`, `InputBox` |
| Program | `DoEvents`, `End` |
| Settings | `SaveSetting(key, value)`, `GetSetting(key, default)` |

## 11. Forms and controls

```vb
Sub Form_Load()
    Me.Caption = "Score Book"
    lblTitle.Caption = "Welcome"
End Sub

Sub btnNext_Click()
    Form2.Show
End Sub
```

- `Me` refers to the current form.
- Stage 2: controls can be created at run time.

  ```vb
  Dim b As New Button
  b.Caption = "New"
  Me.Controls.Add(b)
  ```

## 12. Open questions

- File extension (`.gbas` is provisional).
- `ByRef` semantics on top of async procedures.
- User-defined classes (`Class … End Class`) — not in 1.0.
- Exact syntax of the embedded-Dart escape hatch.
