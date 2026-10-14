# GuBASIC Language (draft)

[한국어](LANGUAGE.ko.md)

GuBASIC is a simplified, VB.NET-flavored BASIC. This is a **draft**: it fixes the decisions that are hard to change later and leaves the rest open.

---

## 1. Lexical rules

| Rule | Decision |
|---|---|
| Case | **Case-insensitive.** The editor rewrites every use to the spelling of its declaration, as VB did. The transpiler emits that spelling. |
| Identifiers | **ASCII only:** a letter, then letters, digits or `_`. Korean (and any non-ASCII) text is allowed in strings and comments. |
| Comments | `'` to end of line. `REM` also accepted, but only as a whole word (`REM note` is a comment; `Remark` is an identifier). It can also follow a statement: `x = 1 REM note`. |
| Line continuation | A `_` that is the last thing on a line (only spaces or tabs may follow) continues the statement on the next line. A `_` anywhere else is an error (L005). `x_` is simply an identifier. |
| Statements per line | One. A `:` separator is an error (L003); the lexer still treats it as the end of a statement so that the rest of the line is checked. |
| Numbers | Integers (`123`) and reals (`1.5`). A real needs digits on **both** sides of the dot: `.5` and `1.` are not numbers (write `0.5` and `1.0`). Exponent notation (`1e5`) is not supported. A minus sign is an operator, not part of the number. |
| String literals | `"..."`; a doubled quote `""` is a literal quote. A string must close on the line where it starts (L001). |
| Statement end | A line break ends a statement. Blank lines and comment-only lines are ignored. |
| Positions | Lines and columns count from 1. A tab counts as one column. |
| Dart reserved words | If an identifier collides with a Dart keyword (`var`, `class`, `is`, `new`, …), the transpiler renames it automatically. Users never see this. |

### 1.1 Keywords

Keywords are case-insensitive (`dim`, `DIM` and `Dim` are the same) and cannot be used as names.

```
Dim As Const Static Public Private Sub Function End Exit Return
If Then ElseIf Else Select Case For To Step Each In Next Do Loop While Until
Try Catch Finally Throw New Nothing True False Not And Or Xor Mod Is Me
Handles ReDim Preserve Optional Of ByVal
```

These Visual Basic keywords are **reserved but not supported**, so that the editor can explain what to write instead:

| Keyword | Status | Use instead |
|---|---|---|
| `ByRef` | planned for stage 2 | see §7.2 |
| `On` (`On Error`) | not supported | `Try … Catch` |
| `GoTo`, `GoSub` | not supported | loops, `Exit`, procedures |
| `Variant` | not supported | `Object` |
| `Class` | not in 1.0 | — |
| `AndAlso`, `OrElse` | not supported | `And`, `Or` (they already short-circuit) |
| `Wend` | not supported | `Do While … Loop` |
| `Call` | not supported | call the procedure directly: `ShowScore("Kim", 90)` |
| `Set`, `Let` | not supported | plain assignment: `x = value` |

Type names (`Integer`, `String`, …) and built-in functions (`MsgBox`, …) are ordinary identifiers, not keywords.

### 1.2 Lexer diagnostics

The lexer never stops at an error: it reports it and keeps reading, so that one mistake does not hide the rest. Codes are stable and never reused.

| Code | Problem | What the lexer does |
|---|---|---|
| L001 | A string has no closing `"` on its line | The rest of the line becomes one error token; the next line is read normally |
| L002 | Non-ASCII text (e.g. Korean) outside a string or comment | The whole word is still read as an identifier, so the statement can be checked |
| L003 | `:` used to put several statements on one line | Treated as the end of a statement |
| L004 | A character with no meaning in GuBASIC (`@`, `#`, `$`, …) | Error token |
| L005 | `_` that is not the last thing on its line | Error token |
| L006 | An integer too large for `Integer` (64-bit) | Integer token with no value |

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
- **To check whether an object is `Nothing`, compare with `Is`:** `If player Is Nothing Then`. For the opposite, write `If Not player Is Nothing Then`. (`=` compares values, not objects.)
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
| Object identity | `Is` (e.g. `x Is Nothing`) |
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
    Case Is > 7
        kind = "Invalid"
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
- **A function returns its result with `Return` only.** Assigning to the function's name (VB6 style: `Average = (a + b) / 2`) is not supported; the analyzer will point out the line and suggest `Return`.
- Optional parameters: `Optional title As String = "Info"`.

### 7.1 Passing arguments: `ByVal`

Parameters are passed **by value**. `ByVal` is the default and may be written or left out; these two mean the same:

```vb
Sub ShowScore(ByVal name As String, ByVal score As Integer)
Sub ShowScore(name As String, score As Integer)
```

When the value is an object (a `List`, a control, …), the procedure receives the **same object**, not a copy. It can change the object's contents, but it cannot make the caller's variable refer to a different object:

```vb
Sub Fill(items As List(Of String))
    items.Add("Kim")                  ' the caller's list changes
    items = New List(Of String)       ' only the local parameter changes
    items.Add("Lee")                  ' goes to the new list, which the caller never sees
End Sub

Sub Form_Load()
    Dim names As New List(Of String)
    Fill(names)
    ' names now contains "Kim" only
End Sub
```

### 7.2 `ByRef` (stage 2)

`ByRef` lets a procedure assign to the caller's variable. It is not available yet; the keyword is reserved so that the editor can say so. Planned implementation:

- **A pair of closures.** A `ByRef` argument is passed as two closures, one that reads the caller's variable and one that writes it. Because every procedure is async (see DESIGN.md §3.1), the procedure may pause at any `await`; the closures keep pointing at the caller's variable across those pauses, and the interpreter and the transpiled Dart use the same scheme.
- **Array elements are fixed at the call.** For `Swap(a(i), a(j))`, the array and the indexes are evaluated once, when the call is made. If `i` changes while the procedure runs, it still reads and writes the element that was originally passed.
- **Properties are copied in and copied out.** For `Clean(txtName.Text)`, the property is read into a temporary before the call, the procedure works on the temporary, and the result is written back to the property when the procedure returns (as in VB.NET).
- **No write-back after an error.** If the procedure ends with an error, the property is **not** written back, so that a failed operation does not leave a half-changed value behind (D22).

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
- User-defined classes (`Class … End Class`) — not in 1.0.
- Exact syntax of the embedded-Dart escape hatch.
