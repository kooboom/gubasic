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
| Numbers | Integers (`123`) and reals (`1.5`). A real needs digits on **both** sides of the dot: `.5` and `1.` are not numbers (write `0.5` and `1.0`). **Exponent notation** is allowed: `1E+21`, `1.5E-7`, `2e10` — `E` in either case, an optional sign, then digits; such a literal is always a `Double`. It is the same notation the text form uses (§2.2), so printed values can be written back as they are. A literal beyond the `Double` range (`1E400`) is an error (L008); a non-zero literal so small that it becomes exactly 0 (`1E-400`) gets a warning (L009); one that only loses precision but stays non-zero (`4E-324`) does not. A minus sign is an operator, not part of the number. |
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

After a dot, a keyword can be used as a member name: `obj.End`, `list.Next` (as in VB.NET).

### 1.2 Diagnostics

Neither the lexer, the parser nor the analyzer stops at an error: they report it and keep reading, so that one mistake does not hide the rest. Codes are stable and never reused.

Every diagnostic is an **error** unless marked as a **warning** below. Errors must be fixed. Warnings point out something that works but may surprise; they **never stop a program from running or being built** (D23). The code's prefix says who reports it (L lexer, P parser, A analyzer, F form and project files, R run time), not how serious it is.

**Lexer**

| Code | Problem | What the lexer does |
|---|---|---|
| L001 | A string has no closing `"` on its line | The rest of the line becomes one error token; the next line is read normally |
| L002 | Non-ASCII text (e.g. Korean) outside a string or comment | The whole word is still read as an identifier, so the statement can be checked |
| L003 | `:` used to put several statements on one line | Treated as the end of a statement |
| L004 | A character with no meaning in GuBASIC (`@`, `#`, `$`, …) | Error token |
| L005 | `_` that is not the last thing on its line | Error token |
| L006 | An integer too large for `Integer` (64-bit) | Integer token with no value. For exactly 9223372036854775808 the message points to `Integer.MinValue` |
| L007 | **Retired** (D26 made it unnecessary): it warned about integers the web could not store exactly; Integer is now exact on every platform. The code is not reused | — |
| L008 | A `Double` literal beyond the `Double` range (`1E400`) | Double token with no value |
| L009 | **Warning.** A non-zero `Double` literal so small that it becomes exactly 0 (`1E-400`) | Double token with the value 0; the program still runs (D23) |

**Parser**

How the parser recovers:
- A syntax error is reported **once per statement**; the parser then skips to the next line.
- A block that is never closed (`If` without `End If`, …) is reported **where it starts**, when the parser meets the end of an enclosing block, a new `Sub`/`Function`, or the end of the file.
- A line on which the lexer already reported an error gets no syntax diagnostics from the parser.
- Guidance about Visual Basic features (P013–P022) is always reported, and the code is read the GuBASIC way where possible, so that the rest can still be checked.

| Code | Problem | What the parser does |
|---|---|---|
| P001 | A value or expression is missing | Puts an error node in its place |
| P002 | A keyword is missing (`Then`, `To`, `In`, `Case`, …) | Reads on as if it were there |
| P003 | A symbol is missing (`)`, `=`, `(`, `.`) | Reads on as if it were there |
| P004 | A name is missing | Uses an empty name |
| P005 | Something that does not belong here | Skips to the end of the line |
| P006 | A block is not closed | Reported at the line where the block starts |
| P007 | A closing statement with no open block (`End If` without `If`, …) | Skips the line |
| P008 | A statement outside any `Sub` or `Function` | Keeps it in the tree |
| P009 | A declaration that cannot appear here (`Public` inside a procedure, `Static` outside) | Reads it as `Dim` |
| P010 | `Next j` closing `For i` | — |
| P011 | Arguments without parentheses (`MsgBox "Hi"`) | Reads it as `MsgBox("Hi")` |
| P012 | More than one variable in one declaration (`Dim a, b`) | Keeps the first |
| P013 | `On Error` | Skips the line; use `Try … Catch` |
| P014 | `GoTo`, `GoSub` | Skips the line; use loops, `Exit`, procedures |
| P015 | `Variant` | Reads it as a type name; use `Object` |
| P016 | `Class … End Class` | Skips the whole class |
| P017 | `AndAlso`, `OrElse` | Reads them as `And`, `Or` |
| P018 | `While … Wend` / `While … End While` | Reads it as `Do While … Loop` |
| P019 | `Call` | Reads the call without it |
| P020 | `Set`, `Let` | Reads a plain assignment |
| P021 | `ByRef` (not available yet; stage 2) | Reads it normally; the message suggests a `Function` with `Return` |
| P022 | `Handles` (not available yet; stage 2) | Reads it normally; the message suggests a `ControlName_EventName` Sub |
| P023 | A line ends inside an open parenthesis with a value missing (`(1 +`, `f(1,`) | One diagnostic for both the value and `)` |

**Analyzer**

The analyzer checks names and types (§2.1, §3.2, §5.2). It runs even when the parser found errors; anything it cannot work out is never checked again, so one mistake gives one diagnostic.

| Code | Problem |
|---|---|
| A001 | A name is not declared |
| A002 | A name is not declared, and a similar visible name exists ("did you mean") |
| A003 | An undeclared name used with `.` (`lblMessage.Caption`), or `Me`, in code without a form (the playground): controls and `Me` need a form (§11) |
| A004 | A type name does not exist |
| A005 | A name is already declared in the same scope or procedure |
| A006 | A local is used above its declaration |
| A007 | A `Dim` with neither a type nor a value; a parameter or `Function` without `As` |
| A008 | A value of one type where another is expected (§2.1) |
| A009 | Text where a number is expected (use `CInt`, `CDbl`, `Val`) |
| A010 | A `Double` where an `Integer` is expected (use `CInt` or `Int`) |
| A011 | Text and a number joined with `+` (use `&`) |
| A012 | A condition that is not `True`/`False` |
| A013 | A binary operator used with types it does not support |
| A014 | A unary operator used with a type it does not support |
| A015 | The wrong number of arguments |
| A016 | Something that is not a `Sub` or `Function`, called |
| A017 | A `Sub` used where a value is needed |
| A018 | `(index)` on something without numbered items |
| A019 | A member the type does not have |
| A020 | Something that cannot be on the left of `=` (a constant, a procedure, a call result) |
| A021 | VB6 style `FunctionName = value` (use `Return value`) |
| A022 | `Return value` in a `Sub` |
| A023 | `Return` without a value in a `Function` |
| A024 | `Exit For` / `Exit Do` / `Exit Sub` / `Exit Function` outside a matching loop or procedure |
| A025 | `For Each` over something that is not a `List` or an array |
| A026 | **Warning.** A local variable that is never used |
| A027 | **Warning.** A `Function` with no `Return` |
| A028 | **Warning.** A local that hides a form-level variable of the same name |
| A029 | `SaveSetting` / `GetSetting`: not available yet (reported before running) |
| A030 | A form-level variable or procedure with the name of a control (§11) |
| A031 | **Warning.** A local with the name of a control, which it hides |
| A032 | An event handler not written as its event expects (§8) |
| A033 | `New` with a control type: controls cannot be created by code yet (stage 2) |

**Form and project files**

Form files and project files (§11.2, §11.3) are checked the same way: a problem is reported at its place in the file, and the rest is still read.

| Code | Problem |
|---|---|
| F001 | The text is not in the expected layout (YAML) from this point on |
| F002 | `formatVersion` is missing or not a whole number (the file is read as version 1) |
| F003 | The file was written by a newer GuBASIC; nothing else in it is read |
| F004 | **Warning.** A key GuBASIC does not know; it is ignored |
| F005 | A value in the wrong form (`controls` that is not a list, a control without `type`, …) |
| F006 | A missing or unusable control or form name |
| F007 | Two controls, or two forms of a project, with the same name (in any case) |
| F008 | A control type that does not exist |
| F009 | A property the control type does not have |
| F010 | A property value of the wrong type |
| F011 | `startup` names a form that is not in `forms` |
| F012 | An `Integer` property value outside its range (§11.1) |

**Run time**

Errors found while a program runs. Each stops the program and points at its line, unless a `Try` catches it (§9).

| Code | Problem |
|---|---|
| R001 | An `Integer` result outside the 64-bit range (`+ - *`, unary `-`, `\`, `CInt`, `Int`, `Round`, a `For` counter) |
| R002 | Division by zero with `/`, `\` or `Mod` |
| R003 | An item number outside an array, a list or a text (`Substring`, `Insert`, `RemoveAt`) |
| R004 | A member or item of an object that is `Nothing` |
| R005 | Text that cannot be converted (`CInt("abc")`, `CBool("maybe")`) |
| R006 | A member a value does not have, found through an `Object` variable |
| R007 | An argument outside what a built-in function accepts (`Sqr(-1)`, `Mid(s, 0)`, `Round(x, 16)`) |
| R008 | An exception that was thrown and not caught |
| R009 | Procedures calling each other more than 10,000 deep (endless recursion) |
| R010 | An `Integer` property set to a value outside its range (§11.1) |

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

- **`Integer` is an exact 64-bit integer on every platform**, the web included (D26): from `Integer.MinValue` (−9223372036854775808) to `Integer.MaxValue` (9223372036854775807). A result outside this range is a run-time error (R001), never a silently wrong number.
- **`Nothing` (null) exists only for objects.** Value types always have a value, so beginners rarely meet null errors.
- **To check whether an object is `Nothing`, compare with `Is`:** `If player Is Nothing Then`. For the opposite, write `If Not player Is Nothing Then`. (`=` compares values, not objects.)
- There is **no `Variant`**. Use `Object` when a variable really must hold anything.
- **Control types** (`Form`, `Button`, `Label`, `TextBox`; §11.1) can be written after `As`, and controls are objects: `Dim b As Button = btnSave`, `If b Is Nothing Then`. A control cannot be created with `New` yet (A033); the controls are the ones on the form.

### 2.1 Automatic conversions

The same rules apply to assignments, arguments and `Return` values. Anything else needs a conversion function.

| From → to | |
|---|---|
| `Integer` → `Double` | automatic |
| `Integer`, `Double`, `Boolean`, `Date` → `String` | automatic, in the text form of §2.2 (`lblCount.Caption = count`) |
| any value → `Object` | automatic |
| `Nothing` → `Object`, `List`, arrays, `Exception` | automatic. Not to `String` or other value types |
| `String` → a number | **no** (A009): use `CInt`, `CDbl` or `Val` |
| `Double` → `Integer` | **no** (A010): use `CInt` (rounds) or `Int` (rounds down) — the fraction would be lost silently otherwise |
| `Object` → a specific type | **no** (A008): use `CInt`, `CDbl`, `CStr` or `CBool` |
| `Boolean` ↔ numbers | **no** (A008) |

**Rounding.** `CInt` and `Round` round halves **away from zero**, as taught in school and as Excel's ROUND does: `CInt(2.5)` is 3, `CInt(-2.5)` is −3. `Int` rounds **down** to the smaller whole number: `Int(2.5)` is 2, `Int(-2.5)` is −3. This differs from Visual Basic, where `CInt` rounds halves to the nearest even number (2.5 → 2) ([Type Conversion Functions](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/functions/type-conversion-functions)) and `Math.Round` does the same by default ([Math.Round](https://learn.microsoft.com/en-us/dotnet/api/system.math.round)); to a beginner, 2.5 → 2 looks like a bug. Also unlike Visual Basic, where `Int` returns the type it is given ([Type Conversion Functions](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/functions/type-conversion-functions)), GuBASIC's `Int` returns an `Integer`, so `Int(x)` can be stored in an `Integer` directly.

### 2.2 Text form of values

Automatic conversion to `String`, `CStr`, `&` and `Debug.Print` all use one rule, which gives the same text on every platform. The same notation is accepted as a literal, and a printed value written back reads as the same number (a whole-valued `Double` prints without a decimal point, so it reads back as an `Integer` of the same value):

| Type | Text | Examples |
|---|---|---|
| `Integer` | the digits | `42`, `-7` |
| `Double` | whole values without a decimal point; otherwise the shortest text that reads back as exactly the same number. Plain decimal from 1E-6 (inclusive) to 1E+15 (exclusive) in size, `d.dddE±n` outside it | `1`, `0.25`, `0.30000000000000004`, `1E+15`, `2.5E-7`; `-0` prints as `0`; also `NaN`, `Infinity`, `-Infinity` |
| `Boolean` | `True` / `False` | |
| `Date` | `yyyy-MM-dd HH:mm:ss` | `2026-03-07 09:05:02` |

## 3. Variables

### 3.1 Declaration

```vb
Dim score As Integer          ' explicit type
Dim name = "Jekyll"           ' type inferred as String
Dim total As Integer = 100    ' type and initial value
```

**Declaration is always required** (`Option Explicit` is permanently on). Using an undeclared name is a compile error — this catches typos.

**One variable per declaration.** `Dim a, b As Integer` is not allowed (P012): in VB6 it made `a` a `Variant`, in VB.NET an `Integer`. Writing one variable per line removes the doubt.

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

**Name rules** (checked by the analyzer):
- A name is looked up from the innermost block outwards: block locals, the procedure's locals and parameters, form-level names and procedures, then built-ins. Case does not matter.
- **A `Dim` inside a block (`If`, `For`, `Do`, `Select Case`, `Try`) is visible only in that block.** Two sibling blocks may reuse a name.
- Within one procedure, a name can be declared only once, even in different blocks (A005).
- A local may have the same name as a form-level variable, but this is a warning (A028): the form-level one cannot be reached there, a common mistake with counters that should be `Static`.
- A local can be used only below its declaration (A006). Form-level variables and procedures can be used anywhere in the file.
- **A `Dim` starts its variable again every time it runs** (with its initial value, or the type's default). So a `Dim` inside a loop begins each round fresh. Use `Static`, or a `Dim` above the loop, to keep a value between rounds. This differs from Visual Basic, where a variable declared in a block is initialized once, when the procedure starts ([Lifetime](https://learn.microsoft.com/en-us/dotnet/visual-basic/programming-guide/language-features/declared-elements/lifetime)).

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

### 5.1 Precedence

From highest to lowest, as in VB.NET. Operators on the same level are evaluated **left to right**.

| Level | Operators |
|---|---|
| 1 | `^` |
| 2 | unary `-`, unary `+` |
| 3 | `*`, `/` |
| 4 | `\` |
| 5 | `Mod` |
| 6 | `+`, `-` |
| 7 | `&` |
| 8 | `=`, `<>`, `<`, `>`, `<=`, `>=`, `Is` |
| 9 | `Not` |
| 10 | `And` |
| 11 | `Or` |
| 12 | `Xor` |

| Expression | Means | Value |
|---|---|---|
| `1 + 2 * 3 ^ 2` | `1 + (2 * (3 ^ 2))` | 19 |
| `-2 ^ 2` | `-(2 ^ 2)` | -4 |
| `2 ^ 3 ^ 2` | `(2 ^ 3) ^ 2` | **64** |
| `Not a = b And c` | `(Not (a = b)) And c` | |
| `"n=" & n + 1` | `"n=" & (n + 1)` | |

- **`^` is also left to right.** VB and Excel calculate `2 ^ 3 ^ 2` as `(2 ^ 3) ^ 2` = 64, unlike mathematical notation, where 2^3^2 means 2^(3^2) = 512. Write `2 ^ (3 ^ 2)` when you mean 512.
- **`=` at the start of a statement assigns; anywhere else it compares.** `x = y = z` stores in `x` whether `y` equals `z`.

### 5.2 Operand and result types

| Operator | Operands | Result |
|---|---|---|
| `+ - *` | numbers | `Integer` if both are `Integer`, otherwise `Double` |
| `+` | two `String`s | `String` |
| `/`, `^` | numbers | always `Double` |
| `\` | **`Integer`s only** (use `CInt` or `Int` first) | `Integer` |
| `Mod` | numbers | `Integer` if both are `Integer`, otherwise `Double` |
| `&` | any values (§2.2) | `String` |
| `= <> < > <= >=` | two numbers, two `String`s or two `Date`s; `Boolean`s with `=` and `<>` only | `Boolean` |
| `Is` | objects or `Nothing` | `Boolean` |
| `Not`, `And`, `Or`, `Xor` | **`Boolean`s only** | `Boolean` |

- `"1" + 1` is an error (A011): text is never turned into a number automatically, and turning the number into text would silently give `"11"`. Use `&` to join, or `CInt` to add.
- `And`, `Or`, `Xor` and `Not` work only on `True`/`False` in GuBASIC 1.0, so they always mean logic, never bit operations.
- **Conditions** (`If`, `ElseIf`, `Do While`, `Loop Until`, …) must be `True` or `False`. Write `If count <> 0 Then`, not `If count Then` (A012).

### 5.3 Arithmetic at run time

- **Integer overflow is an error (R001).** Visual Basic checks integer overflow by default as well ([-removeintchecks](https://learn.microsoft.com/en-us/dotnet/visual-basic/reference/command-line-compiler/removeintchecks)).
- **Division by zero is an error (R002) for `/`, `\` and `Mod`.** For `\` Visual Basic does the same ([\ Operator](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/operators/integer-division-operator)); for `/` with `Double` values Visual Basic returns infinity or NaN instead ([/ Operator](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/operators/floating-point-division-operator)). GuBASIC reports it, because a beginner rarely means to divide by zero.
- `\` truncates toward zero (`-7 \ 2` is −3); the sign of `Mod` follows the left operand (`-7 Mod 3` is −1).
- A `Double` that grows too large becomes `Infinity`; that is not an error.

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

- **Single-line `If`.** `If x > 0 Then y = 1 Else y = 2` is one statement and needs no `End If`. Only simple statements fit on the line (assignments, calls, `Exit`, `Return`, …); loops and other blocks need the block form.
- **The loop variable may carry its type:** `For i As Integer = 1 To 10`, `For Each name As String In names`.
- **An undeclared loop variable is declared automatically, only for that loop.** `For i = 1 To 10` with no `i` declared creates an `i` that exists only inside the loop. Its type comes from the start, end and step values (`Double` if any of them is a `Double`, otherwise `Integer`); for `For Each`, from the items of the list or array. A variable that is already declared is used as it is. Visual Basic does the same ([For...Next, Counter Argument](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/statements/for-next-statement)).

## 7. Procedures

```vb
Sub ShowScore(name As String, score As Integer)
    MsgBox(name & ": " & score)
End Sub

Function Average(a As Integer, b As Integer) As Double
    Return (a + b) / 2
End Function
```

- Arguments are always written in parentheses: `ShowScore("Kim", 90)`. A call with no arguments may leave them out: `Form2.Show`, `DoEvents`. `MsgBox "Hi"` (VB6 style) is reported (P011).
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

- A handler is a `Sub` named `ControlName_EventName`: `btnSave_Click`, `txtName_Changed`. The form's own events use `Form`, whatever the form is called: `Form_Load`. Case does not matter.
- A procedure is a handler only when the control (or `Form`) has an event of that name; `btnSave_Clicked` is an ordinary procedure. A handler must be a `Sub` with exactly the event's parameters (the events of §11.1 have none). Anything else is reported (A032) instead of being quietly treated as an ordinary procedure that never runs.
- Double-clicking a control in the designer creates the handler for its default event.
- Renaming a control renames its handlers.
- Stage 2: `Handles` lets one procedure handle several events.

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

### 8.1 When handlers run

A program with a form runs **one handler at a time** (D28):

- **A running handler is not started again by its own event.** While `btnSave_Click` runs, another click on `btnSave` is ignored, not saved for later (D5).
- **Another handler waits for its turn.** It starts when the running handler finishes, or while that handler waits in `DoEvents`. Events that arrive in the meantime run in the order they came.
- **`DoEvents` is the only place where another handler can run in the middle of one.** The screen still updates during long loops, and the Stop button works, but no other handler runs until the loop calls `DoEvents` or ends.
- **`MsgBox` and `InputBox` are modal.** While one is open, the form's controls cannot be used, nothing else runs, and the form cannot be closed. Events in the meantime are dropped, not saved for later. Visual Basic .NET's `MsgBox` does the same by default: when `Buttons` is omitted it is 0, `ApplicationModal`, and "the user must respond to the message box before continuing work in the current application" ([Interaction.MsgBox](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.interaction.msgbox)).
- **Form-level variables are shared.** A handler waiting in `DoEvents` sees, when it goes on, the values other handlers stored meanwhile. Its own locals are its own.
- **`Static` belongs to its procedure.** Every call of a procedure, from any handler, uses that procedure's one `Static` variable. Two handlers that each declare a `Static` of the same name have two different variables.
- **`End` ends the whole program.** Handlers waiting in `DoEvents` do not go on, and an open dialog is closed. An error that nothing catches does the same (§9).

```vb
Dim done As Boolean

Sub btnStart_Click()
    done = False
    Do While Not done
        DoEvents          ' btnStop_Click can run here
    Loop
    lblStatus.Caption = "Stopped"
End Sub

Sub btnStop_Click()
    done = True
End Sub
```

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
- **Run-time errors (R codes) can be caught with `Try`** like a thrown exception. `ex.Message` is the error's explanation, in the language chosen when the program started. An exception nobody catches stops the program with R008.

### 9.1 Running a program

- Code without a form starts at `Sub Main()`, or at `Sub Form_Load()` if there is no `Main`, and ends when that procedure returns. Form-level variables get their initial values first.
- A program with a form starts with its form: form-level variables get their initial values, `Form_Load` runs, and then the form is shown and waits for events (§8.1). `Sub Main` is then an ordinary procedure. The program ends when the form is closed, `End` runs, an error is not caught, or the Stop button is pressed.
- A program with errors does not run; one with only warnings does (D23).
- Calls may nest 10,000 deep; one more is R009. The limit is the same on every platform. It catches endless recursion within a fraction of a second; the interpreter itself was measured to stay safe beyond a million calls on the VM and in Chrome.
- While a program runs, the interpreter lets the screen update every 1,000 loop rounds or calls, so that the Stop button works. This never changes what the program computes and never lets another handler run. `DoEvents` updates the screen on request and also lets other handlers run (§8.1).

## 10. Built-in functions (initial set)

String functions follow classic BASIC and **count from 1**. String *methods* (`.Substring`, `.IndexOf`) count from 0, as in VB.NET.

| Group | Functions |
|---|---|
| String | `Len`, `Left`, `Right`, `Mid`, `InStr`, `UCase`, `LCase`, `Trim`, `Replace`, `Split`, `Join` |
| Conversion | `CInt`, `CDbl`, `CStr`, `CBool`, `Val`, `Str` |
| Math | `Abs`, `Int`, `Round`, `Sqr`, `Rnd`, `Randomize`, `Min`, `Max`; constants `Integer.MaxValue`, `Integer.MinValue` |
| Date | `Now`, `Today`, `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second` |
| Dialogs | `MsgBox`, `InputBox` |
| Output for developers | `Debug.Print(value)`: writes a line to the playground's output window (VB6's Immediate window) |
| Program | `DoEvents`, `End` |
| Settings | `SaveSetting(key, value)`, `GetSetting(key, default)` |

- `Debug.Print` needs parentheses like any call with arguments: `Debug.Print("x")`, not `Debug.Print "x"` (P011).
- `CInt`, `Round` and `Int` round as described in §2.1; `Int` returns an `Integer`.
- `Mid(text, start[, length])`, `Left`, `Right`: a start below 1 or a negative length is R007; a length past the end takes what is there. `InStr` gives 0 when the text is not found.
- `CInt(text)` reads whole numbers exactly (also above 2⁵³) and other numbers through `Double`, rounding as §2.1. `CBool` takes numbers (0 is `False`) and the texts `True` / `False` in any case. `Val` reads the number at the start of the text and gives 0 if there is none. `Str` is the text form of a number, with no leading space.
- `Round(x, digits)`: `digits` from 0 to 15. It rounds the shortest decimal text of `x` half away from zero, so `Round(2.675, 2)` is 2.68 as written.
- `Rnd()` gives a `Double` from 0 (inclusive) to 1 (exclusive) and is the same on every platform: the 64-bit state starts at 0 when the program starts, `Randomize(seed)` sets it to `seed`, and `Randomize` without a seed uses the current time. Each `Rnd()` computes, with 64-bit wrapping arithmetic and `>>>` the unsigned right shift (SplitMix64):

  ```
  state = state + 0x9E3779B97F4A7C15
  z = state
  z = (z Xor (z >>> 30)) * 0xBF58476D1CE4E5B9
  z = (z Xor (z >>> 27)) * 0x94D049BB133111EB
  z = z Xor (z >>> 31)
  Rnd = (z >>> 11) / 2^53
  ```

- `Now` and `Today` use the device's local time.
- `SaveSetting` and `GetSetting` are not available yet (A029).

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

- `Me` refers to the current form; its properties are those of `Form` (§11.1).
- The controls are the ones in the form file (§11.2). Their names can be used anywhere in the form's code, like form-level variables. A form-level variable or procedure cannot have a control's name (A030); a local can, but then hides the control (warning A031).
- Code without a form, such as a program in the playground, cannot use controls or `Me` (A003).
- Stage 2: controls can be created at run time.

  ```vb
  Dim b As New Button
  b.Caption = "New"
  Me.Controls.Add(b)
  ```

### 11.1 Built-in controls

| Control | Properties | Events |
|---|---|---|
| `Form` | `Caption` (`String`); `Width`, `Height` (`Integer`) | `Load` |
| `Button` | `Caption` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `Label` | `Caption` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `TextBox` | `Text` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Changed` |

- Each control is a component, defined with its default values in `components/NAME/component.yaml` (DESIGN.md §5). The table above lists the events with the default one first: the one a double-click in the designer creates.
- `Left`, `Top`, `Width` and `Height` are in logical pixels (the same size on screens of different densities), measured from the top-left corner of the inside of the form. A form's `Width` and `Height` are the size of that inside area, without the window's title bar and borders. Later stages add properties (`Anchor`, …) without changing these (D12).
- `Integer` properties are 32-bit: from −2147483648 to 2147483647, the same on every platform. `Width` and `Height` cannot be negative. A value outside the range is a run-time error (R010) when the program sets it, and F012 in a form file.
- **`TextBox.Changed`** runs after `Text` changes, whether the user typed or the program set `Text`. When the program sets `Text`, the handler runs right away, as part of that assignment, so the next line already sees what it did. Setting the same text again does not run it. A handler that sets `Text` of its own TextBox is not started again by that change (§8.1).
- **Typing with an input method (IME).** `Text` holds only the characters the input method has **committed**, and `Changed` runs each time it commits one. What is on the screen may not be committed yet: in Korean, a final consonant can still move to the next syllable. Typing 갈가 shows 갈, then 갉, then 갈가: 갈 is committed only when ㅏ is typed and the ㄱ moves on. A handler therefore never changes the text in the middle of a syllable, which is known to break typing in Flutter on Windows ([flutter/flutter#121376](https://github.com/flutter/flutter/issues/121376)). The cost: code that follows every keystroke, such as a character counter, sees the syllable being typed only once the input method commits it.
- **A click while a character is being composed.** Before a click reaches the program, the characters still being composed in any TextBox are committed. The order is always: the characters are committed, `TextBox.Changed` runs, then `Click` runs. So if the user types 한글 and clicks a button straight away, without a space, `txtName.Text` in the `Click` handler is already 한글.

### 11.2 Form files

Form `Form1` is two files side by side: `Form1.form.yaml` (the form and its controls) and `Form1.gbas` (its code). The form's name comes from the file name.

```yaml
formatVersion: 1
properties:
  Caption: Hello
  Width: 320
  Height: 120
controls:
  - name: lblMessage
    type: Label
    properties:
      Left: 16
      Top: 16
      Width: 288
  - name: btnHello
    type: Button
    properties:
      Caption: Say hello
      Left: 16
      Top: 56
      Width: 120
```

- The file is YAML, so that it is plain text (D13). The designer writes it; it can also be edited by hand, and mistakes are reported with F codes (§1.2).
- `formatVersion` is the version of this layout, 1 for now. A file with a newer version is not read (F003), so that an older GuBASIC never misreads it. A change that would read old files differently gets a new version and a converter (D12).
- `properties` holds only the values that differ from the defaults. Keys and property names are not case-sensitive.
- Each control has a `name`, a `type` and, if needed, `properties`. A name follows the rules for identifiers (§1): an English letter, then letters, digits or `_`. It cannot be a keyword or `Form`, and two controls cannot have the same name in any case.
- A `String` property takes the value as it is written: `Caption: 2026` is the text `2026`. Use quotes for text that YAML would otherwise read differently, such as text starting with a quote, `-`, `[` or `{`, or containing `: ` or ` #`.

### 11.3 Project files

A project is a `.gbproj` file with its forms next to it:

```yaml
formatVersion: 1
name: Hello
startup: Form1
forms:
  - Form1
```

- `forms` lists the forms, each a pair of files as in §11.2. At least one is needed.
- `startup` is the form the program starts with; without it, the first form in `forms`.
- [examples/hello](../examples/hello) is the README example as a project.

## 12. Open questions

- File extension (`.gbas` is provisional).
- User-defined classes (`Class … End Class`) — not in 1.0.
- Exact syntax of the embedded-Dart escape hatch.
