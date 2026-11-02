import 'dart:async';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// The debugger (docs/DESIGN.md D124 E, D127): breakpoints pause the
/// program before a statement, Step Into, Step Over and Step Out go on
/// from there as Visual Basic 6's do, the paused program shows its
/// variables and its call stack, and a stop while paused ends the run.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnA, type: Button }
  - { name: btnB, type: Button }
''', name: 'Form1').form;

const _source = '''
Dim total As Integer
Sub btnA_Click()
    Dim n As Integer = 2
    total = Add(n, 3)
    Debug.Print("sum " & total)
End Sub
Function Add(a As Integer, b As Integer) As Integer
    Dim r As Integer = a + b
    Return r
End Function
Sub btnB_Click()
    Dim names(1) As String
    names(0) = "Kim"
    For i = 1 To 3
        Debug.Print(i)
    Next
End Sub
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
  var changes = 0;

  setUp(() async {
    d = Debugger()..onChanged = () => changes++;
    changes = 0;
    host = ScriptedHost(_form);
    final program = compile(_source, form: _form);
    expect(program.diagnostics.where((x) => x.isError), isEmpty);
    i = Interpreter(program, host, debugger: d);
    unawaited(i.run());
    await _until(() => i.isWaitingForUser);
  });

  String where() => '${d.paused!.procedure}:${d.paused!.line}';
  String vars() => [
        for (final v in d.paused!.variables)
          '${v.local ? '' : '.'}${v.name} As ${v.type} = ${v.value}'
      ].join('; ');

  test('a breakpoint pauses before the line, with the variables and the stack',
      () async {
    expect(d.toggleBreakpoint('Form1.gbas', 4), isTrue);
    expect(d.hasBreakpoint('form1.gbas', 4), isTrue);
    i.raiseEvent('btnA', 'Click');
    await _until(() => d.isPaused);
    expect(where(), 'btnA_Click:4');
    expect(d.paused!.file, 'Form1.gbas');
    expect(vars(), 'n As Integer = 2; .total As Integer = 0');
    expect(d.paused!.stack.map((f) => '${f.procedure}@${f.line}'),
        ['btnA_Click@4']);
    expect(i.isWaitingForUser, isFalse, reason: 'the handler still runs');
    expect(changes, 2, reason: 'the breakpoint set, then the pause');

    // Into Add: its parameters, its local still at its default.
    d.stepInto();
    await _until(() => d.isPaused);
    expect(where(), 'Add:8');
    // r is not there until its Dim has run.
    expect(vars(), 'a As Integer = 2; b As Integer = 3; .total As Integer = 0');
    expect(d.paused!.stack.map((f) => '${f.procedure}@${f.line}'),
        ['Add@8', 'btnA_Click@4']);

    d.stepOver();
    await _until(() => d.isPaused);
    expect(where(), 'Add:9');
    expect(vars(), contains('r As Integer = 5'));

    // Out of Add: the assignment finishes, the next statement is line 5.
    d.stepOut();
    await _until(() => d.isPaused);
    expect(where(), 'btnA_Click:5');
    expect(vars(), 'n As Integer = 2; .total As Integer = 5');

    d.resume();
    await _until(() => i.isWaitingForUser);
    expect(host.transcript, ['Debug.Print: sum 5']);
    expect(d.isPaused, isFalse);
  });

  test(
      'Step Over takes a call as one step; stepping past the handler\'s '
      'end runs on', () async {
    d.toggleBreakpoint('Form1.gbas', 4);
    i.raiseEvent('btnA', 'Click');
    await _until(() => d.isPaused);
    d.stepOver();
    await _until(() => d.isPaused);
    expect(where(), 'btnA_Click:5');
    d.stepOver();
    await _until(() => i.isWaitingForUser);
    expect(d.isPaused, isFalse);
    expect(d.isStepping, isFalse, reason: 'the handler ended');
    // The next handler is not paused.
    i.raiseEvent('btnB', 'Click');
    await _until(() => i.isWaitingForUser);
    expect(host.transcript, [
      'Debug.Print: sum 5',
      'Debug.Print: 1',
      'Debug.Print: 2',
      'Debug.Print: 3'
    ]);
  });

  test('a breakpoint inside a loop pauses every round', () async {
    d.toggleBreakpoint('Form1.gbas', 15);
    i.raiseEvent('btnB', 'Click');
    for (var round = 1; round <= 3; round++) {
      await _until(() => d.isPaused);
      expect(where(), 'btnB_Click:15');
      expect(
          vars(),
          'names As String() = ("Kim", ""); i As Integer = $round; '
          '.total As Integer = 0');
      d.resume();
    }
    await _until(() => i.isWaitingForUser);
    expect(host.transcript.length, 3);
  });

  test('Pause stops at the next statement; Stop while paused ends the run',
      () async {
    d.pause();
    expect(d.isStepping, isTrue);
    i.raiseEvent('btnB', 'Click');
    await _until(() => d.isPaused);
    expect(where(), 'btnB_Click:12');
    i.stop();
    await _until(() => i.isWaitingForUser);
    expect(d.isPaused, isFalse);
    expect(host.transcript, isEmpty);
  });

  test('breakpoints are toggled, replaced and cleared', () {
    expect(d.toggleBreakpoint('Form1.gbas', 3), isTrue);
    expect(d.toggleBreakpoint('Form1.gbas', 3), isFalse);
    expect(d.breakpointsOf('Form1.gbas'), isEmpty);
    d.setBreakpoints('Form1.gbas', {3, 5});
    expect(d.breakpointsOf('FORM1.gbas'), {3, 5});
    expect(d.filesWithBreakpoints, ['form1.gbas']);
    d.clearBreakpoints();
    expect(d.filesWithBreakpoints, isEmpty);
  });

  test('values as the debugger shows them', () {
    expect(debugValueText('a "b"'), '"a ""b"""');
    expect(debugValueText(null), 'Nothing');
    expect(debugValueText(GbInt.of(3)), '3');
    expect(debugValueText(2.5), '2.5');
    expect(debugValueText(true), 'True');
    final list = GbList(GbType.string)..items.addAll(['x', 'y']);
    expect(debugValueText(list), '("x", "y")');
  });
}
