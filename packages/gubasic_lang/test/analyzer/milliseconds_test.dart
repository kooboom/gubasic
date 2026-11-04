import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// `Milliseconds()` and the names other versions of BASIC used for the
/// time (docs/DESIGN.md D138).
void main() {
  test('Milliseconds() is an Integer', () {
    final program = compile('''
Sub Main()
    Dim t As Integer = Milliseconds()
    Dim d As Double = t / 1000
    Debug.Print(d)
End Sub
''');
    expect(program.diagnostics, isEmpty);
  });

  test("Visual Basic 6's Timer function points to Milliseconds (A080)", () {
    final d = compile('''
Sub Main()
    Dim t As Double = Timer()
    Debug.Print(t)
End Sub
''').diagnostics.single;
    expect(d.code.code, 'A080');
    expect(
        d.message,
        'Timer is not in GuBASIC, where Timer is a control. The milliseconds '
        'since the program started are Milliseconds().');
    expect(d.replacements, ['Milliseconds()']);
  });

  test("Visual Basic .NET's Environment.TickCount points to it too (A080)", () {
    final d = compile('''
Sub Main()
    Dim t As Integer = Environment.TickCount
    Debug.Print(t)
End Sub
''').diagnostics.single;
    expect(d.code.code, 'A080');
    expect(d.message, startsWith('Environment.TickCount is not in GuBASIC'));
    expect(koreanMessages[d.code], startsWith('{0} 표기는 GuBASIC에 없습니다.'));
  });

  test('Wait in an event script moves the clock Milliseconds() reads', () {
    final steps = parseEventScript('Wait 16\nbtnA.Click\nwait 500\n');
    expect(steps, hasLength(3));
    expect((steps[0] as WaitStep).milliseconds, 16);
    expect((steps[2] as WaitStep).milliseconds, 500);
    expect(() => parseEventScript('Wait soon\n'), throwsFormatException);
  });
}
