@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// examples/duel, the fighting game of v0.8 (docs/DESIGN.md D139), is
/// played through by the parity program duel_example, which must stay
/// a copy of it, pictures and sounds included.
void main() {
  test('duel_example is a copy of examples/duel', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'duel_example.gbas'),
      ('Form1.form.yaml', 'duel_example.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/duel/$example').readAsStringSync(),
        reason: 'copy examples/duel/$example to test/parity/$parity',
      );
    }
  });

  test('duel_example has the pictures and sounds of examples/duel', () {
    final project = readProjectFile(
      File('../../examples/duel/Duel.gbproj').readAsStringSync(),
    );
    expect(project.diagnostics, isEmpty);
    expect(project.project.sounds, ['hit.wav', 'block.wav', 'ko.wav']);
    for (final name in project.project.pictures) {
      expect(
        File('../../examples/duel/pictures/$name').existsSync(),
        isTrue,
        reason: 'examples/duel/pictures/$name',
      );
    }
    for (final name in project.project.sounds) {
      expect(
        File('../../examples/duel/sounds/$name').existsSync(),
        isTrue,
        reason: 'examples/duel/sounds/$name',
      );
    }
    expect(
      File('../../test/parity/duel_example.pictures').readAsLinesSync(),
      project.project.pictures,
      reason: 'list them in test/parity/duel_example.pictures',
    );
    expect(
      File('../../test/parity/duel_example.sounds').readAsLinesSync(),
      project.project.sounds,
      reason: 'list them in test/parity/duel_example.sounds',
    );
  });

  test('the duel has no diagnostics', () {
    final project = readProjectFile(
      File('../../examples/duel/Duel.gbproj').readAsStringSync(),
    ).project;
    final form = readFormFile(
      File('../../examples/duel/Form1.form.yaml').readAsStringSync(),
      name: 'Form1',
      pictures: project.pictures,
    );
    expect(form.diagnostics, isEmpty);
    final program = compile(
      File('../../examples/duel/Form1.gbas').readAsStringSync(),
      form: form.form,
      pictures: project.pictures,
      sounds: project.sounds,
    );
    expect(program.diagnostics, isEmpty);
  });
}
