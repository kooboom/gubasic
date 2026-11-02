import 'dart:async';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// A Structure while the program is paused (docs/DESIGN.md D131): the
/// variables show it with its fields, and the Immediate window reads it
/// and its fields.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnA, type: Button }
''', name: 'Form1').form;

const _source = '''
Structure Student
    Name As String
    Marks(1) As Integer
End Structure
Sub btnA_Click()
    Dim s As Student
    s.Name = "Kim"
    s.Marks(1) = 7
    Debug.Print(s.Name)
End Sub
''';

Future<void> _until(bool Function() condition) async {
  for (var n = 0; n < 10000 && !condition(); n++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue, reason: 'did not happen');
}

void main() {
  test('the variables and the Immediate window show a Structure', () async {
    final d = Debugger();
    final host = ScriptedHost(_form);
    final program = compile(_source, form: _form);
    expect(program.diagnostics.where((x) => x.isError), isEmpty);
    final i = Interpreter(program, host, debugger: d);
    unawaited(i.run());
    await _until(() => i.isWaitingForUser);
    d.toggleBreakpoint('Form1.gbas', 9);
    i.raiseEvent('btnA', 'Click');
    await _until(() => d.isPaused);
    expect([
      for (final v in d.paused!.variables)
        if (v.name == 's') v.value
    ], [
      'Student { Name = "Kim", Marks = (0, 7) }'
    ]);
    expect(await d.evaluate('s'), 'Student { Name = "Kim", Marks = (0, 7) }');
    expect(await d.evaluate('s.Marks(1)'), '7');
    expect(await d.evaluate('s.Name & "!"'), '"Kim!"');
    d.resume();
    await _until(() => i.isWaitingForUser);
    expect(host.transcript, ['Debug.Print: Kim']);
  });
}
