import 'dart:async';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// The Immediate window (docs/DESIGN.md D128): while the program is
/// paused, an expression is evaluated in the paused procedure's frame,
/// with its locals, the form's variables, its controls and its procedures,
/// and what is wrong with the expression is said in the program's words.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnA, type: Button, properties: { Caption: Go } }
''', name: 'Form1').form;

const _source = '''
Dim total As Integer
Dim names(1) As String
Sub btnA_Click()
    Dim n As Integer = 2
    names(0) = "Kim"
    total = Add(n, 3)
    Debug.Print("done " & total)
End Sub
Function Add(a As Integer, b As Integer) As Integer
    Return a + b
End Function
''';

Future<void> _until(bool Function() condition) async {
  for (var n = 0; n < 10000 && !condition(); n++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue, reason: 'did not happen');
}

void main() {
  late Debugger d;
  late ScriptedHost host;
  late Interpreter i;

  setUp(() async {
    d = Debugger();
    host = ScriptedHost(_form);
    final program = compile(_source, form: _form);
    expect(program.diagnostics.where((x) => x.isError), isEmpty);
    i = Interpreter(program, host, debugger: d);
    unawaited(i.run());
    await _until(() => i.isWaitingForUser);
    d.toggleBreakpoint('Form1.gbas', 6);
    i.raiseEvent('btnA', 'Click');
    await _until(() => d.isPaused);
  });

  test('values of locals, fields, controls, calls and literals', () async {
    expect(await d.evaluate('n'), '2');
    expect(await d.evaluate('n + 1'), '3');
    expect(await d.evaluate('total'), '0');
    expect(await d.evaluate('names'), '("Kim", "")');
    expect(await d.evaluate('names(0) & "!"'), '"Kim!"');
    expect(await d.evaluate('btnA.Caption'), '"Go"');
    expect(await d.evaluate('Add(n, 40)'), '42');
    expect(await d.evaluate('n > 1 And total = 0'), 'True');
    expect(await d.evaluate('2.5 * 2'), '5');
    expect(await d.evaluate('Nothing'), 'Nothing');
    expect(await d.evaluate('Len("abc")'), '3');
    // Nothing changed, and the program is still paused where it was.
    expect(await d.evaluate('total'), '0');
    expect(d.paused!.line, 6);
    expect(host.transcript, isEmpty);
  });

  test('what is wrong is said in the program\'s words', () async {
    expect(await d.evaluate('nope'), contains('nope'));
    expect(await d.evaluate('1 +'), isNotEmpty);
    expect(await d.evaluate('n n'), contains('does not belong here'));
    expect(await d.evaluate('"a" + 1'), isNotEmpty);
    expect(await d.evaluate('names(5)'), contains('5'));
    expect(await d.evaluate('CInt("x")'), isNotEmpty);
    expect(await d.evaluate(''), isNotEmpty);
    expect(d.paused!.line, 6, reason: 'still paused');
  });

  test(
      'a call in the expression runs without pausing, then the program '
      'goes on as before', () async {
    d.toggleBreakpoint('Form1.gbas', 10);
    expect(await d.evaluate('Add(1, 1)'), '2');
    expect(d.paused!.line, 6);
    d.resume();
    await _until(() => d.isPaused);
    expect(d.paused!.line, 10, reason: 'the program\'s own call pauses');
    d.resume();
    await _until(() => i.isWaitingForUser);
    expect(host.transcript, ['Debug.Print: done 5']);
  });

  test('not while the program runs', () async {
    d.resume();
    await _until(() => i.isWaitingForUser);
    expect(() => d.evaluate('n'), throwsStateError);
  });
}
