@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// examples/quiz, the quiz that stage 1 ends with (docs/ROADMAP.md), is
/// played through by the parity programs quiz_example and quiz_best (with
/// a best score saved before), which must stay copies of it, pictures
/// included.
void main() {
  test('quiz_example and quiz_best are copies of examples/quiz', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'quiz_example.gbas'),
      ('Form1.form.yaml', 'quiz_example.form.yaml'),
      ('Form1.gbas', 'quiz_best.gbas'),
      ('Form1.form.yaml', 'quiz_best.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/quiz/$example').readAsStringSync(),
        reason: 'copy examples/quiz/$example to test/parity/$parity',
      );
    }
  });

  test('quiz_example and quiz_best have the pictures of examples/quiz', () {
    final project = readProjectFile(
      File('../../examples/quiz/Quiz.gbproj').readAsStringSync(),
    );
    expect(project.diagnostics, isEmpty);
    expect(project.project.pictures, ['triangle.png', 'pentagon.png']);
    for (final name in project.project.pictures) {
      expect(
        File('../../examples/quiz/pictures/$name').existsSync(),
        isTrue,
        reason: 'examples/quiz/pictures/$name',
      );
    }
    for (final parity in ['quiz_example', 'quiz_best']) {
      expect(
        File('../../test/parity/$parity.pictures').readAsLinesSync(),
        project.project.pictures,
        reason: 'list them in test/parity/$parity.pictures',
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

  test('askname_example is a copy of examples/askname, both forms (D88)', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'askname_example.gbas'),
      ('Form1.form.yaml', 'askname_example.form.yaml'),
      ('Form2.gbas', 'askname_example.Form2.gbas'),
      ('Form2.form.yaml', 'askname_example.Form2.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/askname/$example').readAsStringSync(),
        reason: 'copy examples/askname/$example to test/parity/$parity',
      );
    }
  });
}
