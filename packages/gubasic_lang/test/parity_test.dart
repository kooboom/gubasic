@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

import 'interpreter/fake_host.dart';

/// Parity tests (CLAUDE.md rule 3, docs/DESIGN.md §9): every program in
/// test/parity/ is run and its output compared with NAME.out.
///
/// - NAME.gbas  the program
/// - NAME.in    InputBox answers, one per line (optional)
/// - NAME.settings  the settings an earlier run saved, as SaveSetting
///              writes them (optional; D48)
/// - NAME.out   expected output: "Debug.Print: …", "MsgBox: …",
///              "InputBox: … → …", and a last line "Error R0xx @ line" or
///              "Ended" when the run ends that way
///
/// A program with a form also has (docs/DESIGN.md §9.1):
///
/// - NAME.form.yaml  its form
/// - NAME.events     the event script: clicks, typing, dialog answers
/// - NAME.pictures   the project's pictures, one name per line (optional;
///                   only the names matter, D51)
///
/// and its output echoes each step as "> step" (see runEventScript).
///
/// A program with several forms (docs/DESIGN.md D88) has, for each form
/// besides Form1, NAME.FORM.form.yaml and NAME.FORM.gbas (FORM: `Form2`);
/// Form1 starts.
///
/// Today the programs run in the interpreter; when the transpiler exists,
/// the same files run through it too and must give the same output. The
/// same cases also run in Chrome (apps/playground/test/parity_web_test.dart).
///
/// Expected output is checked by hand. To write .out files for new
/// programs: UPDATE_PARITY=1 dart test test/parity_test.dart, then review.
void main() {
  final update = Platform.environment['UPDATE_PARITY'] == '1';
  final programs = Directory('../../test/parity')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.gbas'))
      // NAME.Form2.gbas is a form of NAME's project.
      .where((f) => !f.uri.pathSegments.last
          .substring(0, f.uri.pathSegments.last.length - 5)
          .contains('.'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are at least 12 parity programs', () {
    expect(programs.length, greaterThanOrEqualTo(12));
  });

  for (final program in programs) {
    test(program.uri.pathSegments.last, () async {
      final formFile = File(program.path.replaceFirst('.gbas', '.form.yaml'));
      final settingsFile =
          File(program.path.replaceFirst('.gbas', '.settings'));
      final settings = settingsFile.existsSync()
          ? settingsFile.readAsStringSync().trim()
          : null;
      final picturesFile =
          File(program.path.replaceFirst('.gbas', '.pictures'));
      final pictures = picturesFile.existsSync()
          ? picturesFile.readAsLinesSync().where((l) => l.isNotEmpty).toList()
          : <String>[];
      final List<String> lines;
      final base = program.path.substring(0, program.path.length - 5);
      final otherForms = Directory('../../test/parity')
          .listSync()
          .whereType<File>()
          .map((f) => f.path)
          .where((p) => p.startsWith('$base.') && p.endsWith('.form.yaml'))
          .where((p) => p != '$base.form.yaml')
          .toList()
        ..sort();
      if (otherForms.isNotEmpty) {
        final forms = <FormSource>[];
        for (final (name, formPath, codePath) in [
          ('Form1', formFile.path, program.path),
          for (final p in otherForms)
            (
              p.substring(base.length + 1, p.length - '.form.yaml'.length),
              p,
              p.replaceFirst('.form.yaml', '.gbas'),
            ),
        ]) {
          final read = readFormFile(File(formPath).readAsStringSync(),
              name: name, pictures: pictures);
          expect(read.diagnostics, isEmpty);
          forms.add(
              (file: read.form, source: File(codePath).readAsStringSync()));
        }
        lines = await runProjectScript(
            forms,
            File(program.path.replaceFirst('.gbas', '.events'))
                .readAsStringSync(),
            settings: settings,
            pictures: pictures);
      } else if (formFile.existsSync()) {
        final form = readFormFile(formFile.readAsStringSync(),
            name: 'Form1', pictures: pictures);
        expect(form.diagnostics, isEmpty);
        lines = await runEventScript(
            program.readAsStringSync(),
            form.form,
            File(program.path.replaceFirst('.gbas', '.events'))
                .readAsStringSync(),
            settings: settings,
            pictures: pictures);
      } else {
        final input = File(program.path.replaceFirst('.gbas', '.in'));
        final answers =
            input.existsSync() ? input.readAsLinesSync() : <String>[];
        lines = await runAndRecord(program.readAsStringSync(),
            answers: answers, settings: settings);
      }
      final actual = '${lines.join('\n')}\n';
      final expected = File(program.path.replaceFirst('.gbas', '.out'));
      if (update || !expected.existsSync()) {
        expected.writeAsStringSync(actual);
        if (!update) fail('Wrote ${expected.path}: check it by hand.');
      }
      expect(actual, expected.readAsStringSync());
    });
  }
}
