@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// examples/quiz, the quiz that stage 1 ends with (docs/ROADMAP.md), is
/// played through by the parity program quiz_example, which must stay a
/// copy of it.
void main() {
  test('quiz_example is a copy of examples/quiz', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'quiz_example.gbas'),
      ('Form1.form.yaml', 'quiz_example.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/quiz/$example').readAsStringSync(),
        reason: 'copy examples/quiz/$example to test/parity/$parity',
      );
    }
  });

  test('the quiz has no diagnostics', () {
    final form = readFormFile(
      File('../../examples/quiz/Form1.form.yaml').readAsStringSync(),
      name: 'Form1',
    );
    expect(form.diagnostics, isEmpty);
    final program = compile(
      File('../../examples/quiz/Form1.gbas').readAsStringSync(),
      form: form.form,
    );
    expect(program.diagnostics, isEmpty);
  });
}
