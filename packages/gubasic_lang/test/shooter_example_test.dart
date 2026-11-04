@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// examples/shooter, the shooting game of v0.7 (docs/DESIGN.md D138), is
/// played through by the parity program shooter_example, which must stay
/// a copy of it, pictures and sounds included.
void main() {
  test('shooter_example is a copy of examples/shooter', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'shooter_example.gbas'),
      ('Form1.form.yaml', 'shooter_example.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/shooter/$example').readAsStringSync(),
        reason: 'copy examples/shooter/$example to test/parity/$parity',
      );
    }
  });

  test('shooter_example has the pictures and sounds of examples/shooter', () {
    final project = readProjectFile(
      File('../../examples/shooter/Shooter.gbproj').readAsStringSync(),
    );
    expect(project.diagnostics, isEmpty);
    expect(project.project.sounds, ['shot.wav', 'hit.wav', 'music.wav']);
    for (final name in project.project.pictures) {
      expect(
        File('../../examples/shooter/pictures/$name').existsSync(),
        isTrue,
        reason: 'examples/shooter/pictures/$name',
      );
    }
    for (final name in project.project.sounds) {
      expect(
        File('../../examples/shooter/sounds/$name').existsSync(),
        isTrue,
        reason: 'examples/shooter/sounds/$name',
      );
    }
    expect(
      File('../../test/parity/shooter_example.pictures').readAsLinesSync(),
      project.project.pictures,
      reason: 'list them in test/parity/shooter_example.pictures',
    );
    expect(
      File('../../test/parity/shooter_example.sounds').readAsLinesSync(),
      project.project.sounds,
      reason: 'list them in test/parity/shooter_example.sounds',
    );
  });

  test('the shooter has no diagnostics', () {
    final project = readProjectFile(
      File('../../examples/shooter/Shooter.gbproj').readAsStringSync(),
    ).project;
    final form = readFormFile(
      File('../../examples/shooter/Form1.form.yaml').readAsStringSync(),
      name: 'Form1',
      pictures: project.pictures,
    );
    expect(form.diagnostics, isEmpty);
    final program = compile(
      File('../../examples/shooter/Form1.gbas').readAsStringSync(),
      form: form.form,
      pictures: project.pictures,
      sounds: project.sounds,
    );
    expect(program.diagnostics, isEmpty);
  });
}
