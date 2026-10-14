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

/// One mistake for every lexer diagnostic (L001–L006) and a few parser
/// ones, followed by a correct procedure to show that reading continues to
/// the end.
const errorSample = r'''
' This example has mistakes on purpose.
' Click a problem to jump to it.
Sub Form_Load()
    Dim 점수 As Integer
    Dim greeting = "Hello
    total = 1 : count = 2
    price = 100 @ 2
    answer = 1 + _ 2
    big = 99999999999999999999
    If total > 0 Then
        MsgBox "Hi"
    Next
    On Error Resume Next
End Sub

Sub Later()
    MsgBox("Reading reached the end")
End Sub
''';
