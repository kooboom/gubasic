import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('the README example parses without diagnostics', () {
    final readme = File('../../README.md').readAsStringSync();
    final sample =
        RegExp(r'## A taste of the language\s+```vb\n(.*?)```', dotAll: true)
            .firstMatch(readme)![1]!;
    final r = parseClean(sample);
    expect(r.unit.members.map((m) => m.label),
        ['Field Dim', 'Sub Form_Load', 'Sub btnHello_Click']);
  });

  for (final file in ['LANGUAGE.md', 'LANGUAGE.ko.md']) {
    test('the $file examples parse without diagnostics', () {
      final doc = File('../../docs/$file').readAsStringSync();
      final blocks = RegExp(r'```vb\n(.*?)```', dotAll: true)
          .allMatches(doc)
          .map((m) => m[1]!)
          .toList();
      expect(blocks.length, greaterThan(10));
      for (final block in blocks) {
        final hasProcedure =
            RegExp(r'^\s*(Sub|Function) ', multiLine: true).hasMatch(block);
        // Bare statements are wrapped in a Sub; signature-only lines in a
        // Sub … End Sub pair are completed.
        final src =
            hasProcedure ? _complete(block) : 'Sub T()\n$block\nEnd Sub\n';
        final r = parse(src);
        final unexpected = r.diagnostics
            .where((d) => d.code != DiagnosticCode.plannedForStage2)
            .toList();
        expect(unexpected, isEmpty, reason: src);
      }
    });
  }
}

/// Closes `Sub` signature lines that the document shows on their own.
String _complete(String block) {
  final lines = block.split('\n');
  final out = <String>[];
  for (var i = 0; i < lines.length; i++) {
    out.add(lines[i]);
    final isSignature = RegExp(r'^\s*(Sub|Function) ').hasMatch(lines[i]);
    final next = i + 1 < lines.length ? lines[i + 1].trim() : '';
    final opensBody =
        next.isNotEmpty && !RegExp(r'^(Sub|Function) ').hasMatch(next);
    if (isSignature && !opensBody) {
      out.add(lines[i].trimLeft().startsWith('Function')
          ? 'End Function'
          : 'End Sub');
    }
  }
  return out.join('\n');
}
