/// Shown when the playground opens: a short program that passes every
/// check (no diagnostics).
const starterSample = '''
' Variables, loops, a list and a function. Every check passes.
Sub Main()
    Dim total As Integer = 0
    For i = 1 To 10
        total = total + i
    Next
    Debug.Print("Sum of 1 to 10: " & total)
    Debug.Print("Average of 3 and 4: " & Average(3, 4))

    Dim names As New List(Of String)
    names.Add("Kim")
    names.Add("Lee")
    For Each name In names
        Debug.Print("Hello, " & name)
    Next
End Sub

Function Average(a As Integer, b As Integer) As Double
    Return (a + b) / 2
End Function
''';

/// The "A taste of the language" example from README.md, character for
/// character. A test keeps the two in sync.
const readmeSample = '''
Dim clickCount As Integer

Sub Form_Load()
    lblMessage.Caption = "Press the button"
End Sub

Sub btnHello_Click()
    clickCount = clickCount + 1
    Dim name = InputBox("What is your name?")
    MsgBox("Hello, " & name & "! (" & clickCount & ")")
End Sub
''';

/// One mistake for every lexer diagnostic (L001–L007; L007 is a warning)
/// and a few parser and analyzer ones, followed by a correct procedure to
/// show that reading continues to the end.
const errorSample = r'''
' This example has mistakes on purpose.
' Click a problem to jump to it.
Sub Main()
    Dim 점수 As Integer = 0
    Dim greeting As String = "Hello
    Dim total As Integer = 1 : total = 2
    Dim price As Integer = 100 @ 2
    Dim answer As Integer = 1 + _ 2
    Dim big As Integer = 99999999999999999999
    Dim orderId As Integer = 1234567890123456789
    If total > 0 Then
        MsgBox "Hi"
    Next
    On Error Resume Next
    Dim half As Integer = total / 2
    Debug.Print(점수 & greeting & price & answer & big & orderId & half & totl)
End Sub

Sub Later()
    MsgBox("Reading reached the end")
End Sub
''';
