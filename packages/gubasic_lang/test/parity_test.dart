@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import 'interpreter/fake_host.dart';

/// Parity tests (CLAUDE.md rule 3, docs/DESIGN.md §9): every program in
/// test/parity/ is run and its output compared with NAME.out.
///
/// - NAME.gbas  the program
/// - NAME.in    InputBox answers, one per line (optional)
/// - NAME.out   expected output: "Debug.Print: …", "MsgBox: …",
///              "InputBox: … → …", and a last line "Error R0xx @ line" or
///              "Ended" when the run ends that way
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
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('there are at least 12 parity programs', () {
    expect(programs.length, greaterThanOrEqualTo(12));
  });

  for (final program in programs) {
    test(program.uri.pathSegments.last, () async {
      final input = File(program.path.replaceFirst('.gbas', '.in'));
      final answers = input.existsSync() ? input.readAsLinesSync() : <String>[];
      final lines =
          await runAndRecord(program.readAsStringSync(), answers: answers);
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
