import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

import 'fake_host.dart';

/// Event handling that event scripts cannot express (docs/LANGUAGE.md
/// §8.1, D28). The rest is covered by the parity programs events_*.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnA, type: Button }
  - { name: btnB, type: Button }
  - { name: btnC, type: Button }
''', name: 'Form1').form;

Interpreter _interpreter(String source, ScriptedHost host) {
  final program = compile(source, form: _form);
  expect(program.diagnostics.where((d) => d.isError), isEmpty);
  return Interpreter(program, host);
}

Future<void> _idle(Interpreter i) async {
  for (var n = 0; n < 10000 && !i.isWaitingForUser; n++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  test('events while a handler is busy wait for it, in order', () async {
    final host = ScriptedHost(_form);
    final i = _interpreter('''
Sub btnA_Click()
    Dim n As Integer
    For k = 1 To 5000
        n = n + 1
    Next
    Debug.Print("A done " & n)
End Sub
Sub btnB_Click()
    Debug.Print("B")
End Sub
Sub btnC_Click()
    Debug.Print("C")
End Sub
''', host);
    final run = i.run();
    await _idle(i);
    expect(i.raiseEvent('btnA', 'Click'), EventOutcome.started);
    // A loops without DoEvents: the screen updates, but B and C wait.
    await Future<void>.delayed(Duration.zero);
    expect(i.isWaitingForUser, isFalse);
    expect(i.raiseEvent('btnC', 'Click'), EventOutcome.started);
    expect(i.raiseEvent('btnB', 'Click'), EventOutcome.started);
    expect(i.raiseEvent('btnB', 'Click'), EventOutcome.ignored,
        reason: 'B is already waiting for its turn (D5)');
    await _idle(i);
    i.closeForm();
    expect(await run, isA<RunCompleted>());
    expect(host.transcript,
        ['Debug.Print: A done 5000', 'Debug.Print: C', 'Debug.Print: B']);
  });

  test('stop ends a program with a form at once', () async {
    final host = ScriptedHost(_form);
    final i = _interpreter('''
Sub btnA_Click()
    Do While True
        DoEvents
    Loop
End Sub
''', host);
    final run = i.run();
    await _idle(i);
    i.raiseEvent('btnA', 'Click');
    await _idle(i);
    i.stop();
    expect(await run, isA<RunStopped>());
    expect(i.raiseEvent('btnB', 'Click'), EventOutcome.notRunning);
  });

  test('closing the form closes an open dialog; its handler stops', () async {
    final host = ScriptedHost(_form);
    final i = _interpreter('''
Sub btnA_Click()
    MsgBox("open")
    Debug.Print("never")
End Sub
''', host);
    final run = i.run();
    await _idle(i);
    i.raiseEvent('btnA', 'Click');
    await _idle(i);
    expect(i.hasOpenDialog, isTrue);
    i.closeForm();
    expect(await run, isA<RunCompleted>());
    await Future<void>.delayed(Duration.zero);
    expect(host.transcript, ['MsgBox: open']);
  });

  test('with a form, Sub Main is an ordinary procedure', () async {
    final out = await runEventScript('''
Sub Main()
    Debug.Print("Main")
End Sub
Sub btnA_Click()
    Main()
End Sub
''', _form, 'btnA.Click\nClose\n');
    expect(out, ['> btnA.Click', 'Debug.Print: Main', '> Close', 'Closed']);
  });

  test('events without a handler do nothing', () async {
    final out = await runEventScript('', _form, 'btnA.Click\nClose\n');
    expect(out, ['> btnA.Click', '> Close', 'Closed']);
  });

  test('a program with a form needs a FormHost', () async {
    final program = compile('', form: _form);
    expect(() => Interpreter(program, FakeHost()).run(), throwsArgumentError);
  });

  test('event scripts: steps and comments', () {
    final steps = parseEventScript('''
btnA.Click   ' a comment
txtName.Type "say ""hi"" ' not a comment"
Form.Load
OK
Answer "Kim"
Cancel
Close
''');
    expect(steps.map((s) => s.runtimeType.toString()), [
      'EventStep',
      'TypeStep',
      'EventStep',
      'OkStep',
      'AnswerStep',
      'AnswerStep',
      'CloseStep',
    ]);
    expect((steps[1] as TypeStep).value, 'say "hi" \' not a comment');
    expect((steps[2] as EventStep).control, isNull);
    expect((steps[5] as AnswerStep).value, isNull);
    expect(() => parseEventScript('click btnA'), throwsFormatException);
  });
}
