import 'dart:async';

import 'package:gubasic_lang/gubasic_lang.dart';

/// Times the interpreter on loop-heavy programs (docs/KNOWN_ISSUES.md,
/// "Very long loops are slow"). Prints the median of five runs.
///
///     dart compile exe tool/benchmark.dart -o benchmark.exe
///     ./benchmark.exe
void main() async {
  await _time('local variable', '''
Sub Main()
    Dim total As Integer = 0
    For i = 1 To 1000000
        total = total + i * 2 - 1
    Next
    Debug.Print(total)
End Sub
''');
  await _time('form-level variable', '''
Dim total As Integer
Sub Main()
    For i = 1 To 1000000
        total = total + 1
    Next
    Debug.Print(total)
End Sub
''');
  // Properties without a change event keep the synchronous path (D25);
  // TextBox.Text may run Changed, so its assignment may wait.
  await _time(
      'Label.Left (no change event)',
      '''
Sub Form_Load()
    For i = 1 To 1000000
        lblInfo.Left = i
    Next
End Sub
''',
      form: true);
  await _time(
      'TextBox.Text (change event, no handler)',
      '''
Sub Form_Load()
    For i = 1 To 1000000
        txtName.Text = "x"
    Next
End Sub
''',
      form: true);
}

final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblInfo, type: Label }
  - { name: txtName, type: TextBox }
''', name: 'Form1').form;

Future<void> _time(String name, String source, {bool form = false}) async {
  final times = <int>[];
  for (var i = 0; i < 5; i++) {
    final host = _Host();
    final sw = Stopwatch()..start();
    if (form) {
      final program = compile(source, form: _form);
      final interpreter = Interpreter(program, host);
      final run = interpreter.run();
      await host.shown.future;
      sw.stop();
      interpreter.closeForm();
      await run;
    } else {
      await runProgram(source, host);
      sw.stop();
    }
    times.add(sw.elapsedMilliseconds);
  }
  times.sort();
  print('$name, 1,000,000 rounds: ${times[2]} ms '
      '(runs: ${times.join(', ')})');
}

class _Host implements FormHost {
  final _properties = <String, Object>{};
  final shown = Completer<void>();

  @override
  void debugPrint(String line) {}
  @override
  Future<void> msgBox(String prompt, String title) async {}
  @override
  Future<String> inputBox(String prompt, String title, String d) async => '';
  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);
  @override
  Object getProperty(String form, String? control, String property) =>
      _properties['$form.$control.$property'] ?? '';
  @override
  void setProperty(
          String form, String? control, String property, Object value) =>
      _properties['$form.$control.$property'] = value;
  @override
  Future<String?> loadSettings() async => null;
  @override
  Future<void> saveSettings(String text) async {}
  @override
  void showForms(List<ShownForm> forms) {
    if (!shown.isCompleted) shown.complete();
  }

  @override
  void resetForm(String form) {}
  @override
  void endProgram() {}
}
