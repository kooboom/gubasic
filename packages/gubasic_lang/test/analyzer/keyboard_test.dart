import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// `Keyboard.IsDown` and the keys it alone knows (docs/DESIGN.md D138).
void main() {
  test('Keyboard.IsDown takes a Keys value and gives a Boolean', () {
    final program = compile('''
Sub Main()
    Dim held As Boolean = Keyboard.IsDown(Keys.Left)
    If Keyboard.IsDown(Keys.ShiftKey) And Keyboard.IsDown(Keys.Menu) Then
        held = Keyboard.IsDown(Keys.ControlKey)
    End If
    Debug.Print(held)
End Sub
''');
    expect(program.diagnostics, isEmpty);
  });

  test('Shift, Control and Alt have Visual Basic .NET\'s numbers', () {
    expect(keyCodes['ShiftKey'], 16);
    expect(keyCodes['ControlKey'], 17);
    expect(keyCodes['Menu'], 18);
    expect(modifierKeyCodes, {16, 17, 18});
  });

  test('IsDown wants a key', () {
    final d = compile('''
Sub Main()
    Debug.Print(Keyboard.IsDown("Left"))
End Sub
''').diagnostics;
    expect(d, isNotEmpty);
    expect(d.every((d) => d.isError), isTrue);
  });

  test("Visual Basic 6's Declare is P042, of a key state P043", () {
    final d = compile('''
Declare Function GetAsyncKeyState Lib "user32" (ByVal key As Integer) As Integer
Declare Sub Sleep Lib "kernel32" (ByVal ms As Integer)

Sub Main()
    Debug.Print("hi")
End Sub
''').diagnostics;
    expect(d.map((d) => '${d.code.code}@${d.line}'), ['P043@1', 'P042@2']);
    expect(
        d.first.message,
        'GuBASIC has no Declare (GetAsyncKeyState). The keys held right now '
        'are asked with Keyboard.IsDown(Keys.Left).');
    expect(
        d.last.message,
        'GuBASIC has no Declare (Sleep): what is outside the language comes '
        'in as a component.');
  });
}
