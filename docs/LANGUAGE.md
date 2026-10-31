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
TypeOf CType AddHandler AddressOf
```

These Visual Basic keywords are **reserved but not supported**, so that the editor can explain what to write instead:

| Keyword | Status | Use instead |
|---|---|---|
| `ByRef` | planned (D96) | see §7.2 |
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
- Guidance about Visual Basic features (P013–P026) is always reported, and the code is read the GuBASIC way where possible, so that the rest can still be checked.

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
| P021 | `ByRef` (not available yet) | Reads it normally; the message suggests a `Function` with `Return` |
| P022 | Retired: `Handles` works since DESIGN.md D98 | — |
| P023 | A line ends inside an open parenthesis with a value missing (`(1 +`, `f(1,`) | One diagnostic for both the value and `)` |
| P024 | `Unload Form2` (Visual Basic 6) | GuBASIC closes a form with `Form2.Close` (§11) |
| P025 | `Load Form2` (Visual Basic 6) | GuBASIC shows a form with `Form2.Show` (§11) |
| P026 | `DirectCast`, `TryCast` (Visual Basic .NET) | Reads it as `CType` (§11.4) |
| P027 | `Load Command1(1)` (Visual Basic 6's control array) | Make a control with `New` and `Me.Controls.Add` (§11.4) |
| P028 | `Unload Command1(1)` | Take a control off with `Me.Controls.Remove` (§11.4) |
| P029 | `PopupMenu mnuEdit` | `Me.PopupMenu(mnuEdit)` (§11.1) |

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
| A029 | **Retired** (D48 made it unnecessary): it said `SaveSetting` and `GetSetting` were not available yet. The code is not reused |
| A030 | A form-level variable or procedure with the name of a control (§11) |
| A031 | **Warning.** A local with the name of a control, which it hides |
| A032 | An event handler not written as its event expects (§8) |
| A033 | Retired: controls are made with `New` since DESIGN.md D98 (a form with `New` is A047) |
| A034 | A value given to a property the program can only read (`lstNames.ListCount = 3`, `names.Count = 0`) |
| A035 | A member the type does not have, and a similar member it has (`lstCity.ListIndx`: "did you mean ListIndex") |
| A036 | A member the type does not have, under the name other versions of BASIC use for a member GuBASIC calls differently (`btnOK.Text`: use `Caption`; DESIGN.md D50) |
| A037 | **Warning.** Text given to a picture property that is not one of the project's pictures (`imgShape.Picture = "tri.png"`); the program would stop there (R013) (§11.1) |
| A038 | **Warning.** Text given to `Anchor` with a word that is not an edge (`btnOk.Anchor = "Rihgt"`); the program would stop there (R014) (§11.1) |
| A039 | `Form2.Show vbModal`: `Show` takes no argument; a form the code waits for is shown with `ShowDialog` (§11) |
| A040 | An event the control does not have, in `Handles` or `AddHandler` (§8) |
| A041 | Two procedures handle the same event: an event has one handler (§8) |
| A042 | (warning) A procedure named as one event's handler whose `Handles` does not list that event: it handles only what `Handles` lists (§8) |
| A043 | A handler's `sender` cannot hold one of the controls it handles (§8) |
| A044 | A handler written as in Visual Basic .NET, `(sender As Object, e As EventArgs)` (§8) |
| A045 | `CType` or `TypeOf … Is` with a type that is not a control's (§11.4) |
| A046 | A `Control` where a particular control type is expected: write `CType` (§11.4) |
| A047 | `New` with a form, or with `Control` (§11.4) |
| A048 | `AddressOf` names something that is not a `Sub` of this code (§8) |
| A049 | `Sub Command1_Click(Index As Integer)`: a control array's handler; list the controls after `Handles` and take a `sender` (§8) |
| A050 | `Command1(0)`: a control used as a control array; give each control its name, or go through `Me.Controls` (§11.4) |
| A051 | An event under another version of BASIC's name, as `otherEvents` in its component.yaml lists them: `Timer1_Timer` for `Tick`, `txtName_TextChanged` for `Changed` (§8, §11.1) |
| A052 | `New Timer`: a control not seen on the form is put on it in the designer (§11.1) |
| A053 | `Sub Form_KeyDown(KeyCode As Integer, Shift As Integer)` (Visual Basic 6): GuBASIC's key events take `e As KeyEventArgs` (§11.1) |
| A054 | A name two modules make `Public`, written without its module's name (§11.5) |
| A055 | `Sub Main` in two modules (§11.5) |
| A056 | A type under another version of BASIC's name: `RadioButton` for `OptionButton` (§11.1) |
| A057 | Text that is not a shortcut given to a `Shortcut` (warning, §11.1) |
| A058 | A method of the form called without `Me.`: `Hide`, `PopupMenu(mnuEdit)` for `Me.Hide`, `Me.PopupMenu(mnuEdit)` (§11.1) |
| A059 | Visual Basic 6's `MouseDown(Button, Shift, X, Y)`: GuBASIC's is `MouseDown(e As MouseEventArgs)` (§11.1) |

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
| F013 | A property the form file cannot set: the program sets it while it runs (`ListIndex`) or only reads it (§11.1) |
| F014 | A picture of the project with a name a picture cannot have (§11.3) |
| F015 | Two pictures of the project whose names differ only in case (§11.3) |
| F016 | A picture property in a form file naming a picture the project does not have (§11.1) |
| F017 | `Anchor` in a form file with a word that is not an edge (§11.1) |
| F018 | **Warning.** A project file's `id` that is not an app ID (§11.3); it is ignored |
| F019 | `startup: Sub Main`, but no module has a `Sub Main()` (§11.5) |
| F020 | A control type under another version of BASIC's name: `type: RadioButton` (§11.1) |
| F021 | `controls:` under a control that is not a Frame (§11.2) |
| F022 | A `Shortcut` that is not a shortcut (§11.1) |

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
| R011 | `SaveSetting` would make the program's settings longer than 65536 characters (§10) |
| R012 | `SaveSetting` could not keep the settings, for example because the browser's storage is full (§10) |
| R013 | A picture property set to a name the project has no picture of (§11.1) |
| R014 | `Anchor` set to text with a word that is not an edge (§11.1) |
| R015 | `ShowDialog` of a form that is already shown (§11) |
| R016 | `Controls.Add` of a control whose name the form already has (§11.4) |
| R017 | `Controls.Add` of a control that is on a form already (§11.4) |
| R018 | `Controls.Remove` of a control that is not on that form (§11.4) |
| R019 | `Name` set on a control that is on a form (§11.4) |
| R020 | `Name` set to text that is not a name (§11.4) |
| R021 | `AddHandler` for an event that already has a handler (§8) |
| R022 | `CType` of a control of another type (§11.4) |
| R023 | `Me.Controls.Remove` of a Frame that holds controls (§11.1) |
| R024 | A `Shortcut` set to text that is not a shortcut (§11.1) |
| R025 | `PopupMenu` of a menu item that has no items (§11.1) |
| R026 | `PopupMenu` of another form's menu (§11.1) |

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
- **Control types** (`Form`, `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`; §11.1) can be written after `As`, and controls are objects: `Dim b As Button = btnSave`, `If b Is Nothing Then`. `Control` is the type of any control (§11.4), and a control can be made with `New` and added to a form (§11.4).

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
| Form-level | `Dim` (or `Private`) at the top of a form's code | every procedure of that form | the form is shown again after `Close` (DESIGN.md D88) |
| Form-level, public | `Public` at the top of a form's code | that form, and the project's other forms as `Form2.Score` (§11) | the same |
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

### 7.2 `ByRef` (planned)

`ByRef` lets a procedure assign to the caller's variable. It is not available yet; the keyword is reserved so that the editor can say so. Planned implementation:

- **A pair of closures.** A `ByRef` argument is passed as two closures, one that reads the caller's variable and one that writes it. Because every procedure is async (see DESIGN.md §3.1), the procedure may pause at any `await`; the closures keep pointing at the caller's variable across those pauses, and the interpreter and the transpiled Dart use the same scheme.
- **Array elements are fixed at the call.** For `Swap(a(i), a(j))`, the array and the indexes are evaluated once, when the call is made. If `i` changes while the procedure runs, it still reads and writes the element that was originally passed.
- **Properties are copied in and copied out.** For `Clean(txtName.Text)`, the property is read into a temporary before the call, the procedure works on the temporary, and the result is written back to the property when the procedure returns (as in VB.NET).
- **No write-back after an error.** If the procedure ends with an error, the property is **not** written back, so that a failed operation does not leave a half-changed value behind (D22).

## 8. Events

- A handler is a `Sub` named `ControlName_EventName`: `btnSave_Click`, `txtName_Changed`. The form's own events use `Form`, whatever the form is called: `Form_Load`. Case does not matter.
- A procedure is a handler only when the control (or `Form`) has an event of that name; `btnSave_Clicked` is an ordinary procedure. A handler must be a `Sub` with exactly the event's parameters (the events of §11.1 have none). Anything else is reported (A032) instead of being quietly treated as an ordinary procedure that never runs.
- Double-clicking a control in the designer creates the handler for its default event.
- Renaming a control renames its handlers, and its name in `Handles` and `AddHandler`.
- **`Handles`** (DESIGN.md D98): a procedure handles exactly the events it lists, whatever its name; `Me.Load` names the form's own. A procedure named as another event's handler that `Handles` does not list is warned about (A042). A control or event that does not exist is reported (A001, A040).

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

- **`sender`**: a handler of an event without parameters may take one parameter, the control (or form) that raised it, of its type, or `Control` for controls of different types (§11.4). A sender that cannot hold one of them is A043. Visual Basic .NET's `(sender As Object, e As EventArgs)` is A044. A handler by name may take a sender too: `Sub btnClear_Click(sender As Button)`. A handler of an event with parameters may put the sender before them, as Visual Basic .NET does: `Sub Any_MouseUp(sender As Label, e As MouseEventArgs) Handles lblA.MouseUp, lblB.MouseUp` (DESIGN.md D112).

  ```vb
  Sub Digit_Click(sender As Button) Handles btn1.Click, btn2.Click, btn3.Click
      lblShow.Caption = lblShow.Caption & sender.Caption
  End Sub
  ```

- **One event has one handler**: two procedures handling the same event are A041. A handler handles its events one at a time: while `Digit_Click` runs, a click on any of its buttons is ignored, not only on the one that started it (§8.1).
- **`AddHandler control.Event, AddressOf Procedure`** gives an event a handler while the program runs, typically for a control made with `New` (§11.4). The procedure is a `Sub` of the same code written as the event's handler (A048, A032, A043). An event that already has another handler stops the program (R021); the same handler again changes nothing.

### 8.1 When handlers run

A program with a form runs **one handler at a time** (D28):

- **A running handler is not started again by its own event.** While `btnSave_Click` runs, another click on `btnSave` is ignored, not saved for later (D5).
- **Another handler waits for its turn.** It starts when the running handler finishes, or while that handler waits in `DoEvents`. Events that arrive in the meantime run in the order they came.
- **`DoEvents` is the only place where another handler can run in the middle of one.** The screen still updates during long loops, and the Stop button works, but no other handler runs until the loop calls `DoEvents` or ends.
- **`MsgBox` and `InputBox` are modal.** While one is open, the form's controls cannot be used, nothing else runs, and the form cannot be closed. Events in the meantime are dropped, not saved for later. Visual Basic .NET's `MsgBox` does the same by default: when `Buttons` is omitted it is 0, `ApplicationModal`, and "the user must respond to the message box before continuing work in the current application" ([Interaction.MsgBox](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.interaction.msgbox)).
- **A dialog without a title shows the project's name** in its title bar, as Visual Basic puts the application's name there when the title is omitted ([Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/msgbox-function), [Microsoft](https://learn.microsoft.com/en-us/office/vba/language/reference/user-interface-help/inputbox-function)); the program still sees `""` as the title it gave (DESIGN.md D68).
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
- A program with a form starts with its form: form-level variables get their initial values, `Form_Load` runs, and then the form is shown and waits for events (§8.1). `Sub Main` of a form is then an ordinary procedure. With several forms, every form's variables get their initial values first, the startup form's first, and the startup form starts (§11). A project that starts with `Sub Main` of a module runs it instead, after every module's and form's variables got their initial values; it shows the forms it wants, and when it returns with no form shown the program ends (§11.5). The program ends when no form is shown any more, the window is closed, `End` runs, an error is not caught, or the Stop button is pressed.
- A program with errors does not run; one with only warnings does (D23).
- Calls may nest 10,000 deep; one more is R009. The limit is the same on every platform. It catches endless recursion within a fraction of a second; the interpreter itself was measured to stay safe beyond a million calls on the VM and in Chrome.
- While a program runs, the interpreter lets the screen update once about 10 ms have passed since it last did, looking at the clock every 256 loop rounds or calls, so that the Stop button works. This never changes what the program computes and never lets another handler run. `DoEvents` updates the screen on request and also lets other handlers run (§8.1).

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
- **`SaveSetting(key, value)` and `GetSetting(key, default)`** keep text from one run of a program to the next. `GetSetting` gives what was saved under `key`, or `default` if nothing was. Keys do not tell case apart (`best` and `Best` are one key); an empty key is R007. Values are text: a number is saved as its text (§2.2), so read it back with a conversion: `CInt(GetSetting("best", "0"))`.
- **Each project has its own settings, by its name** (the `name` in its `.gbproj`, §11.3): two projects with the same name share them, and a project saved under a new name starts without them. They are not part of the project's files or its `.zip`. In the IDE, **File → Clear Saved Settings** forgets the open project's settings. The playground, which has no projects, keeps one set for all its programs.
- A program's settings are at most 65536 characters of text in all (R011), so that a program cannot fill the browser's storage, where the web IDE keeps its projects too. Settings are kept as plain text: do not save passwords in them (DESIGN.md D48).

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
- **Where controls overlap**, a `Label` is always under the other controls (`Button`, `TextBox`, `CheckBox`, `ListBox`), whatever their order in the form file, and the control on top takes the click. Among controls of the same kind of layer, the one later in the form file is on top (DESIGN.md D41).
- Code without a form, such as a program in the playground, cannot use controls or `Me` (A003).
- **Several forms** (DESIGN.md D88). A project's forms are used by their names, each one object: `Form2.Show`, `Form2.txtName.Text`.
  - The forms shown are a stack in one window. `Form2.Show` puts Form2 on top, and the forms under it keep their values; a form shown already comes to the top. `Form2.ShowDialog` puts it on top as a dialog, over the form behind, which is dimmed, and the code waits until it goes. `Me.Hide` goes back to the form under, keeping this one's values; `Me.Close` goes back too, runs `Form_Closed`, and the next `Show` starts the form again: its variables and controls as at the start, and `Form_Load` again. With no form shown, the program has ended.
  - Only the form on top takes clicks and typing. The window's close button ends the program; each form shown first gets its `Form_Closed`, from the top down. `End` runs none.
  - `Form_Load` runs when a form is shown (the first time, and after `Close`), `Form_Resize` once after that, `Form_Closed` after `Close`. Every form's variables get their initial values when the program starts, so another form's members can be used before it is shown.
  - Another form's members are its controls, its `Public` variables and constants, and its procedures that are not `Private`: `Form2.Score = 5`, `lblName.Caption = Form2.Hello("Kim")`. A `Dim` at the top of a form's code stays its own. A dialog's answer is a `Public` variable, which keeps its value after `Close` until the form is shown again:

    ```vb
    ' Form1
    Sub btnAsk_Click()
        Form2.ShowDialog
        lblAnswer.Caption = Form2.Answer
    End Sub

    ' Form2
    Public Answer As String

    Sub btnOK_Click()
        Answer = txtAnswer.Text
        Me.Close
    End Sub
    ```

  - **`DialogResult`** (DESIGN.md D103): `Form2.ShowDialog()` gives how the dialog was closed, compared with `DialogResult.OK`, `.Cancel`, `.Yes`, `.No` or `.None`. Setting `Me.DialogResult` while the form is shown by `ShowDialog` closes it at once, as `Close` does (its handler goes on to its end); closed without one, it gives `Cancel`. A dialog hidden and shown again starts with `None`.

    ```vb
    If Form2.ShowDialog() = DialogResult.OK Then
        lblName.Caption = Form2.txtName.Text
    End If
    ```

  - A variable whose type comes from another form's member is not known to the other forms (`Public n = Form2.Score`): give it a type, `Public n As Integer = Form2.Score`.
  - Visual Basic 6's `Unload Form2` and `Load Form2` are `Form2.Close` and `Form2.Show` (P024, P025), and `Show vbModal` is `ShowDialog` (A039). `ShowDialog` of a form shown already stops the program (R015).
- **Controls as objects** — the type `Control`, `Me.Controls`, `TypeOf`, `CType` and controls made with `New` — are in §11.4.

### 11.1 Built-in controls

| Control | Properties | Events |
|---|---|---|
| `Form` | `Caption` (`String`); `Width`, `Height` (`Integer`); `KeyPreview` (`Boolean`); `DialogResult` (`Integer`, set only in code); `Controls` (§11.4). Methods: `Show()`, `ShowDialog()` (gives a `DialogResult`), `Hide()`, `Close()`, `PopupMenu(menu)` | `Load`, `Resize`, `Closed`, `KeyDown(e As KeyEventArgs)`, `KeyUp(e As KeyEventArgs)`; every control seen on the form and the form: `MouseDown(e As MouseEventArgs)`, `MouseUp(e As MouseEventArgs)` |
| `Button` | `Caption` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `Label` | `Caption` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `TextBox` | `Text` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Changed` |
| `CheckBox` | `Caption` (`String`); `Checked` (`Boolean`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Changed` |
| `Image` | `Picture` (`String`, the name of one of the project's pictures); `Stretch` (`Boolean`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `OptionButton` | `Caption` (`String`); `Checked` (`Boolean`); `Left`, `Top`, `Width`, `Height` (`Integer`) | `Changed` |
| `ComboBox` | as a `ListBox`: `ListIndex`, `ListCount`, `Text`; `AddItem(item)`, `RemoveItem(index)`, `Clear()`, `List(index)` | `Changed` |
| `Frame` | `Caption` (`String`); `Left`, `Top`, `Width`, `Height` (`Integer`); holds other controls | `Click` |
| `Menu` | `Caption` (`String`); `Checked`, `Enabled`, `Visible` (`Boolean`); `Shortcut` (`String`); made in the menu editor | `Click` |
| `Timer` | `Interval` (`Integer`, milliseconds, at least 1; 100 at first); `Enabled` (`Boolean`, `False` at first). Methods: `Start()`, `Stop()`. Not seen on the form (below) | `Tick` |
| `ListBox` | `ListIndex` (`Integer`, set only in code); `ListCount` (`Integer`), `Text` (`String`), both read only; `Left`, `Top`, `Width`, `Height` (`Integer`). Methods: `AddItem(item)`, `RemoveItem(index)`, `Clear()`, `List(index)` | `Changed` |

- Every control and form also has `Name` and `Tag` (`String`; §11.4).
- Each control is a component, defined with its default values in `components/NAME/component.yaml` (DESIGN.md §5). The table above lists the events with the default one first: the one a double-click in the designer creates.
- `Left`, `Top`, `Width` and `Height` are in logical pixels (the same size on screens of different densities), measured from the top-left corner of the inside of the form. A form's `Width` and `Height` are the size of that inside area, without the window's title bar and borders. `Anchor` (below) moves controls when the form changes size; it does not change what these mean (D12).
- `Integer` properties are 32-bit: from −2147483648 to 2147483647, the same on every platform. `Width` and `Height` cannot be negative. A value outside the range is a run-time error (R010) when the program sets it, and F012 in a form file.
- **`TextBox.Changed`** runs after `Text` changes, whether the user typed or the program set `Text`. When the program sets `Text`, the handler runs right away, as part of that assignment, so the next line already sees what it did. Setting the same text again does not run it. A handler that sets `Text` of its own TextBox is not started again by that change (§8.1).
- **Typing with an input method (IME).** `Text` holds only the characters the input method has **committed**, and `Changed` runs each time it commits one. What is on the screen may not be committed yet: in Korean, a final consonant can still move to the next syllable. Typing 갈가 shows 갈, then 갉, then 갈가: 갈 is committed only when ㅏ is typed and the ㄱ moves on. A handler therefore never changes the text in the middle of a syllable, which is known to break typing in Flutter on Windows ([flutter/flutter#121376](https://github.com/flutter/flutter/issues/121376)). The cost: code that follows every keystroke, such as a character counter, sees the syllable being typed only once the input method commits it. Where the platform does not say which characters are still being composed (the macOS app; D37), the runtime tells it from how the text changes, with the same result.
- **`CheckBox.Changed`** runs after `Checked` changes: when the user clicks the box or its `Caption`, or when the program sets `Checked`. As with `TextBox.Changed`, a change by the program runs the handler right away, setting the same value again does not run it, and a handler that sets its own `Checked` is not started again by that. While a CheckBox's `Changed` is running, a click on that CheckBox is ignored and leaves it as it was, so the box shows what the handler is dealing with (§8.1). A CheckBox has two states; Visual Basic 6's third, grayed state is left out (DESIGN.md D44).
- **An OptionButton** (DESIGN.md D104) is one of a group of choices: the OptionButtons on a form are one group, and those in each Frame another (D105), of which one is checked. Checking one, by a click or by setting `Checked = True`, unchecks the others; a click on the checked one does nothing; `Checked = False` leaves none checked. `Changed` runs for the one that becomes checked, as Visual Basic 6's Click did, and not for the ones it unchecks, so one handler for the group runs once. In the designer, checking one in the Properties window unchecks the others. Visual Basic .NET calls it [RadioButton](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.radiobutton) (A056, F020).
- **A ComboBox** (D104) is a closed box showing the chosen item, which a click opens as a list to pick one; the user picks and does not type (Visual Basic 6's Style 2). The program fills it and reads it exactly as a ListBox: `AddItem`, `RemoveItem`, `Clear`, `List`, `ListCount`, `ListIndex`, `Text`, and `Changed` when `ListIndex` changes. A ComboBox the user types in is left for later.
- **A Frame** (DESIGN.md D105) is a box with its `Caption` on its top edge that holds other controls. A control in it is placed from the Frame's top-left corner: its `Left` and `Top` are from there, and its Anchor keeps distances to the Frame's edges, so that a Frame anchored to grow with the form moves the controls anchored to its right or bottom. The Frame cuts off what reaches past its edges. Its OptionButtons are a group of their own, as in Visual Basic 6 ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa241737(v=vs.60))). A Frame can hold Frames. In the designer, a control drawn or dropped on a Frame goes into it; moving a Frame moves what is in it; deleting, copying or pasting a Frame takes what is in it along; and a control pasted while one Frame is chosen goes into it. A control does not leave its Frame when dragged: to take it out, or into another Frame, cut it and paste it. `Me.Controls` has the controls in Frames too; `Me.Controls.Remove` of a Frame that holds controls is R023, and a control removed from a Frame and added again is on the form itself. Visual Basic .NET calls it [GroupBox](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.groupbox) (A056, F020).
- **A form's menu bar** (DESIGN.md D106) is made in the designer's menu editor (⌘E, Ctrl+E), as in Visual Basic 6's [Menu Editor](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/62aawczc(v=vs.90)): each item has a `Caption`, a `Name` and a level, and may have a `Shortcut`, be `Checked`, not `Enabled` or not `Visible`. An item is a `Menu` control: its handler is `mnuFileOpen_Click`, and code sets its properties (`mnuViewBig.Checked = True`). An item with items opens them and raises nothing; an item without is chosen and raises `Click`; a `Caption` of `-` alone is a line between items. An item that is not `Enabled`, or is in a menu that is not, is grey and cannot be chosen; one that is not `Visible` is not shown. A `Shortcut` is Ctrl, Shift and Alt and one key, joined by `+` (`Ctrl+O`, `Ctrl+Shift+S`, `F5`); a letter or digit needs Ctrl or Alt (A057, F022, R024). On macOS, in the IDE's run window and in an exported app, the menus are on the system's menu bar, between the app's own menu and the Window menu, and Ctrl in a Shortcut is the Command key; on the web and on Windows they are in the window, above the form, which they do not make smaller. They choose the same items and run the same handlers everywhere. The designer shows the menu bar above the form; choosing an item there opens its `Click`. Menus are not among `Me.Controls`.
- **`Me.PopupMenu(mnuEdit)`** (D106) shows the items of one of the form's menus where the mouse last went down on the form, as Visual Basic 6's [PopupMenu](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa716251(v=vs.60)) does; a menu that is not `Visible` on the menu bar is the usual one to show. It waits, as a MsgBox does, until an item is chosen, or the menu is closed with none by Escape or a click outside it; the chosen item's `Click` runs before `PopupMenu` returns. GuBASIC writes the call with `Me.` and parentheses, as for every form method: `PopupMenu mnuEdit` is P029, and a form method without `Me.` (`Hide`, `PopupMenu(mnuEdit)`) A058, each saying what to write. A menu with no items is R025; another form's menu is R026.
- **Other names of control types**, as other versions of BASIC give them (D104): `RadioButton` is `OptionButton`, `CommandButton` is `Button`, `PictureBox` is `Image`, `GroupBox` is `Frame`, in code (A056) and in form files (F020).
- **Mouse buttons** (DESIGN.md D111). Every control seen on the form, and the form where no control is, has `MouseDown(e As MouseEventArgs)` when a button goes down on it and `MouseUp(e As MouseEventArgs)` when it goes up, as Visual Basic .NET's ([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.mouseeventargs)). `e.Button` is the button, compared with `MouseButtons.Left`, `MouseButtons.Right` and `MouseButtons.Middle`, with Visual Basic .NET's numbers ([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.mousebuttons)); `e.X` and `e.Y` are the place in pixels from the top left corner of the control (of the form for the form's), the same control for MouseUp as for its MouseDown. The innermost control under the pointer gets them: a control in a Frame, not the Frame. A click is a left button: MouseDown, MouseUp, then Click. On a touch screen a press is the left button, told when the finger is lifted, and a long press the right button, told when it has been held, which then makes no Click: so `If e.Button = MouseButtons.Right Then Me.PopupMenu(mnuEdit)` in a MouseUp opens a menu where the user right-clicks or long-presses. Like other events they wait for the running handler, do not re-enter, and are blocked while a dialog is open. Visual Basic 6's `(Button As Integer, Shift As Integer, X As Single, Y As Single)` is A059.
- **The form's keys** (DESIGN.md D101). `Form_KeyDown(e As KeyEventArgs)` runs when a key is pressed, and again while it is held; `Form_KeyUp(e As KeyEventArgs)` when it is let go. `e.KeyCode` is the key's number, compared with `Keys`: `Keys.Left`, `Keys.Right`, `Keys.Up`, `Keys.Down`, `Keys.Space`, `Keys.Enter`, `Keys.Escape`, `Keys.Back`, `Keys.Tab`, `Keys.Delete`, `Keys.Insert`, `Keys.Home`, `Keys.End`, `Keys.PageUp`, `Keys.PageDown`, `Keys.A` to `Keys.Z`, `Keys.D0` to `Keys.D9`, `Keys.NumPad0` to `Keys.NumPad9`, `Keys.F1` to `Keys.F12`, with Visual Basic .NET's numbers ([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.keys)). `e.Shift`, `e.Control` and `e.Alt` say which modifiers are held; they raise no event alone. Letters and digits are told by where they are on the keyboard, whatever the input method types. The form in front gets the keys while it or a control other than a TextBox has the focus, from when it is shown; while a TextBox is typed in, only when its **`KeyPreview`** is `True` (`False` at first, as in Visual Basic .NET: [Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.form.keypreview)), and the TextBox still gets the key. A key event waits for the running handler, does not re-enter, and is blocked while a dialog is open. Visual Basic 6's `(KeyCode As Integer, Shift As Integer)` is A053. On phones (stage 3) key events do not come.

  ```vb
  Sub Form_KeyDown(e As KeyEventArgs)
      If e.KeyCode = Keys.Left Then picShip.Left = picShip.Left - 8
  End Sub
  ```

- **A Timer** (DESIGN.md D100) runs its `Tick` every `Interval` milliseconds while `Enabled`; `Start` and `Stop` set `Enabled`. It is off at first, as in Visual Basic .NET ([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.timer.enabled)), so that no tick comes before `Form_Load` has set things up. It is not seen on the form: the designer keeps it in a tray under the form, it has no place or size, and it is not one of `Me.Controls`. It is put on a form in the designer, not made with `New` (A052). Its form's Timers tick from `Form_Load` until `Close`, also while the form is hidden or behind another; a tick is an event like a click: it does not start its handler again while that runs (D5), waits for the running handler, and is dropped while a `MsgBox` or `InputBox` is open (§8.1). Visual Basic 6's `Timer1_Timer` is `Timer1_Tick` (A051).
- **A ListBox's items** are added in code, numbered from 0: `AddItem(item)` adds one at the end, `RemoveItem(index)` removes one, `Clear()` removes them all, and `List(index)` gives the text of one. `ListCount` is how many there are, `ListIndex` the number of the chosen one (−1 when nothing is chosen), and `Text` the chosen item's text (`""` when nothing is chosen). `ListCount` and `Text` can only be read (A034); `ListIndex` is set only in code, not in the form file (F013). A number that is not an item is a run-time error (R003); `ListIndex = -1` chooses nothing. Items cannot be entered in the designer yet (DESIGN.md D46).
- **`ListBox.Changed`** runs whenever `ListIndex` changes: when the user picks another item, when the program sets `ListIndex` (right away, as part of the assignment, as for `TextBox.Changed`), and when `RemoveItem` or `Clear` moves or removes the chosen item, as part of that call. Removing an item above the chosen one moves the choice up by one, so the same item stays chosen; removing the chosen one, or `Clear`, leaves nothing chosen. Picking the chosen item again, or setting the same `ListIndex`, does not run it. While a ListBox's `Changed` is running, a pick in that ListBox is ignored and changes nothing (§8.1).
- **An Image** shows one of the project's pictures (§11.3): `imgShape.Picture = "triangle.png"` shows it, `""` shows none. The name is compared as names in code are, without case (`"Triangle.PNG"` is `triangle.png`), and reads back with the project's spelling. A name the project has no picture of stops the program (R013); written as text in the code, the analyzer warns first (A037), and in a form file it is F016. With `Stretch = False` (the default) the whole picture is fitted inside the control, keeping its proportions; with `True` it fills the control and may look squeezed. Unlike Visual Basic 6, whose Image grows or shrinks to its picture when `Stretch` is False ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa242027(v=vs.60))), the control keeps the size it was drawn at. An Image is drawn under the other controls, as a Label is (DESIGN.md D41), and takes clicks over its whole area, picture or not.
- **`Anchor`**, which every control has, names the edges of the form whose distance the control keeps when the form changes size: when the user resizes the window, or the program sets the form's `Width` or `Height` (DESIGN.md D57). It is text: `"Left Top"` (the default: the control stays where it was drawn), `"Right Bottom"` (it stays in the bottom-right corner), `"Left Right"` (it stretches with the form's width), or `""` (no edge: it stays as near the middle). The words may come in any order and case, separated by spaces or commas, and read back in the order `Left Top Right Bottom`. Anchored to two opposite edges, a control stretches, but never below 0; anchored to neither, it moves half as much as the form grows, rounded down. These are Visual Basic .NET's rules ([Microsoft](https://learn.microsoft.com/en-us/dotnet/api/system.windows.forms.anchorstyles)); in Visual Basic 6 a program moves its controls itself, in `Form_Resize` ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa445540(v=vs.60))). `Left`, `Top`, `Width` and `Height` read where the control is now. A control the program places, or gives another `Anchor`, stays where it is and follows its `Anchor` from there. Text with another word stops the program (R014); written as text in the code, the analyzer warns first (A038), and in a form file it is F017.
- **`Form_Resize`** runs when the inside of the form changes size: when the user resizes the window, and when the program sets the form's `Width` or `Height` (right away, as part of the assignment, as for `TextBox.Changed`). It also runs once when the form is first shown, after `Form_Load`, as in Visual Basic 6 ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-basic-6/aa445540(v=vs.60))). The controls have moved as their `Anchor` says by then, so the handler sees where they are and can place the others itself. A handler that sets the form's size is not started again by that change (§8.1). While a dialog is open, the form cannot be resized (DESIGN.md D58).
- **A click while a character is being composed.** Before a click reaches the program, the characters still being composed in any TextBox are committed. The order is always: the characters are committed, `TextBox.Changed` runs, then `Click` runs (or, for a click on a CheckBox or a ListBox, its `Changed`). So if the user types 한글 and clicks a button straight away, without a space, `txtName.Text` in the `Click` handler is already 한글.

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
- `formatVersion` is the version of this layout. A file with a newer version is not read (F003), so that an older GuBASIC never misreads it. A change that would read old files differently gets a new version and a converter (D12). A form with controls inside a Frame is written as version 2; any other form is still version 1, which version 2 reads unchanged, so that it needs no converter (DESIGN.md D105).
- A Frame's `controls` lists the controls inside it, written as the form's own (D105). Only a Frame holds controls (F021), and names are unique across the whole form.
- `menus` lists the menu bar's items (D106), each with a `name`, `properties` and, for a menu, its own `menus`; they have no `type`. A form with a menu bar is written as version 3.
- `properties` holds only the values that differ from the defaults. Keys and property names are not case-sensitive.
- Each control has a `name`, a `type` and, if needed, `properties`. A name follows the rules for identifiers (§1): an English letter, then letters, digits or `_`. It cannot be a keyword or `Form`, and two controls cannot have the same name in any case.
- A `String` property takes the value as it is written: `Caption: 2026` is the text `2026`. Use quotes for text that YAML would otherwise read differently, such as text starting with a quote, `-`, `[` or `{`, or containing `: ` or ` #`.
- The IDE always writes a form file the same way (D31): properties in the order of the component's `component.yaml`, only values that differ from the defaults, and quotes only where YAML would read the text differently (`Caption: "2026"`). Saving a form that did not change gives the same file, and Git shows only the lines that changed. Comments and the layout of a hand-written file are not kept when the IDE saves it.

### 11.3 Project files

A project is a `.gbproj` file with its forms next to it:

```yaml
formatVersion: 2
name: Shapes
startup: Form1
forms:
  - Form1
pictures:
  - triangle.png
  - circle.png
```

- `forms` lists the forms, each a pair of files as in §11.2. At least one is needed.
- `startup` is the form the program starts with; without it, the first form in `forms`. `startup: Sub Main` starts with `Sub Main` of a module (§11.5); a module cannot be `startup` (F011).
- `modules` lists the modules (§11.5), each a file `MODULE.gbas`. A name is a form's or a module's, not both (F007). A project with modules, or starting with `Sub Main`, is written as `formatVersion: 3`, which an older GuBASIC refuses to open rather than lose its modules (DESIGN.md D102).
- `pictures` lists the project's pictures, which are files in its `pictures/` folder: `pictures/triangle.png`. Only PNG, JPEG and GIF pictures are taken (`.png`, `.jpg`, `.jpeg`, `.gif`), and a name cannot have `/ \ : * ? " < > |` (F014). Names are compared without the case of English letters, and Hangul as syllables, the same on every platform: so a project cannot have two pictures whose names differ only in case (F015), as Windows and macOS could not keep both in one folder. A project with pictures is written as `formatVersion: 2`, which an older GuBASIC refuses to open rather than lose its pictures; one without is still version 1 (DESIGN.md D51).
- `id` is the app ID (DESIGN.md D83): 8 to 32 lowercase letters and digits, made the first time the project is exported as an app and kept, so that the app exported again is the same app and keeps its settings. A copy of the project made with a new name gets a new one. One that is not an app ID is ignored (F018), and the next export makes a new one. Older GuBASICs ignore the key with F004 and drop it when they save the project.
- [examples/hello](../examples/hello) is the README example as a project.

### 11.4 Controls as objects

GuBASIC has no control arrays (DESIGN.md D95); what Visual Basic 6 did with them is done as Visual Basic .NET does it ([Microsoft](https://learn.microsoft.com/en-us/previous-versions/visualstudio/visual-studio-2008/kxt4418a(v=vs.90))): one handler for several controls (§8), and the following (DESIGN.md D98).

- **`Control`** is the type of any control on a form. Any control can be stored in it; its members are what every control has: `Name`, `Left`, `Top`, `Width`, `Height`, `Anchor` and `Tag`. A `Control` is a particular control again only through `CType` (A046). A form is not a `Control`.
- **`Name`** gives a control's name, or a form's. It can be set only on a control made with `New` that is on no form yet (A034, R019); it starts with an English letter, then letters, digits or `_` (R020).
- **`Tag`**, a `String` every control and form has, keeps any text the program wants with it, such as a number in place of a control array's index. GuBASIC does nothing with it. Written `Index`, as in Visual Basic 6, it is pointed to (A036).
- **Code written for control arrays** is told what to write instead (DESIGN.md D99): a handler taking `Index As Integer` (A049), `Command1(0)` (A050), `Load Command1(1)` and `Unload Command1(1)` (P027, P028). `On Error` says how to write `Try … Catch` (P013).
- **`Me.Controls`** (or `Form2.Controls`) are the controls on the form: in the form file's order, then in the order they were added. `Me.Controls.Count` counts them, `Me.Controls(0)` is the first, and `For Each c As Control In Me.Controls` goes through them (a snapshot: adding or removing in the loop does not disturb it).
- **`TypeOf value Is Type`** tells whether a value is a control of that type; `Nothing` is not. **`CType(value, Type)`** gives the same control as that type, and stops the program when it is another (R022); `Nothing` stays `Nothing`. Both take a control type (A045). Visual Basic .NET's `DirectCast` and `TryCast` are read as `CType` (P026).

  ```vb
  For Each c As Control In Me.Controls
      If TypeOf c Is TextBox Then
          CType(c, TextBox).Text = ""
      End If
  Next
  ```

- **`New Button`** (any control type, without arguments) makes a control on no form. Its properties start as its component's defaults and can be set at once. `Me.Controls.Add(b)` puts it on the form, on top of the others of its layer; without a `Name` it is named as the designer names one, `Button1`, `Button2`, …, by the smallest number no control of the form has or had in its form file. A name the form has stops the program (R016), as does adding a control that is on a form (R017). `Me.Controls.Remove(b)` takes a control off the form (R018 when it is not there); it keeps its name, properties and handlers, and can be added again. A form, and `Control` itself, are not made with `New` (A047).
- A control made with `New` gets its handlers with `AddHandler` (§8), not by its name. A form shown again after `Close` starts with the controls of its form file only, each with the handlers its code gives it.

  ```vb
  Dim b As New Button
  b.Caption = "No. " & count
  b.Top = 40 * count
  Me.Controls.Add(b)
  AddHandler b.Click, AddressOf Added_Click
  ```

### 11.5 Modules and `Sub Main`

A **module** (DESIGN.md D102) is code without a form, shared by the project: the file `Module1.gbas`, listed under `modules` in the project file (§11.3). File → Add Module adds one; the project explorer lists them under Modules.

- Its `Public` variables and constants, and its `Sub`s and `Function`s that are not `Private`, can be used in every form and module by their names, `Total`, or with the module's, `Module1.Total`. A name two modules make `Public` is written with its module's name (A054). A form's or module's own name of that spelling comes first.
- What it declares with `Dim` or `Private` stays its own.
- Its code cannot use `Me` or controls by themselves; it uses forms by their names: `Form1.Show`, `Form1.lblTotal.Caption`.
- Its variables get their initial values when the program starts, before the forms'.
- **`Sub Main`**: with `startup: Sub Main` (in the IDE: ⋮ next to the module, Start with Sub Main), the program starts with `Sub Main()` of a module instead of a form. It shows the forms it wants (`Form1.Show`, or `Form1.ShowDialog` to wait); when it returns, the program goes on while a form is shown, and ends when none is. `Sub Main` is in one module only (A055), and a project starting with it needs one (F019). A form's `Sub Main` is an ordinary procedure.

  ```vb
  ' Module1.gbas
  Public UserName As String

  Sub Main()
      UserName = GetSetting("user", "")
      If UserName = "" Then
          frmLogin.ShowDialog
      End If
      frmMain.Show
  End Sub
  ```

## 12. Open questions

- File extension (`.gbas` is provisional).
- User-defined classes (`Class … End Class`) — not in 1.0.
- Exact syntax of the embedded-Dart escape hatch.
