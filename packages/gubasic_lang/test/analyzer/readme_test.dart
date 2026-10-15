import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The example in README.md (and README.ko.md) is examples/hello: with its
/// form it has no diagnostics; without a form (the playground) the control
/// it uses is reported as A003.
void main() {
  String sample(String readme) => RegExp(r'```vb\n(.*?)```', dotAll: true)
      .firstMatch(File('../../$readme').readAsStringSync())![1]!;

  final form = readFormFile(
          File('../../examples/hello/Form1.form.yaml').readAsStringSync(),
          name: 'Form1')
      .form;

  test('examples/hello/Form1.gbas is the README example', () {
    expect(File('../../examples/hello/Form1.gbas').readAsStringSync(),
        sample('README.md'));
  });

  for (final readme in ['README.md', 'README.ko.md']) {
    test('$readme example: no diagnostics with its form', () {
      final r = compile(sample(readme), form: form);
      expect(r.diagnostics, isEmpty);
      expect(
          r.analysis.handlers.entries.map((e) => '${e.key.name.name} → '
              '${e.value.control?.name ?? 'Form'}.${e.value.event.name}'),
          ['Form_Load → Form.Load', 'btnHello_Click → btnHello.Click']);
    });
  }

  test('without a form, lblMessage is reported as a control (A003)', () {
    final r = compile(sample('README.md'));
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), ['A003@4']);
    expect(r.diagnostics.single.args, ['lblMessage']);
    expect(r.diagnostics.single.message, contains('This code has no form'));
  });

  test('the example project and form files have no diagnostics', () {
    final project = readProjectFile(
        File('../../examples/hello/Hello.gbproj').readAsStringSync());
    expect(project.diagnostics, isEmpty);
    expect(project.project.startupForm, 'Form1');
    expect(
        readFormFile(
                File('../../examples/hello/Form1.form.yaml').readAsStringSync(),
                name: 'Form1')
            .diagnostics,
        isEmpty);
  });
}
