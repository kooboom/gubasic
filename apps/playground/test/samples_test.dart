@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_playground/src/model/samples.dart';
import 'package:test/test.dart';

void main() {
  test('readmeSample is exactly the example in README.md', () {
    final readme = File('../../README.md').readAsStringSync();
    final match =
        RegExp(r'## A taste of the language\s+```vb\n(.*?)```', dotAll: true)
            .firstMatch(readme);
    expect(match, isNotNull, reason: 'README example not found');
    expect(readmeSample, match![1]);
  });

  test('the starter example passes every check', () {
    expect(compile(starterSample).diagnostics, isEmpty);
  });

  test('the README example parses cleanly; the analyzer reports the control',
      () {
    expect(parse(readmeSample).diagnostics, isEmpty);
    expect(compile(readmeSample).diagnostics.map((d) => d.code.code), ['A003']);
  });

  test(
      'errorSample shows every lexer diagnostic and some parser and '
      'analyzer ones', () {
    final r = compile(errorSample);
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), [
      'L002@4',
      'L001@5',
      'L003@6',
      'L004@7',
      'L005@8',
      'L006@9',
      'L008@10',
      'L009@11',
      'L010@12',
      'A026@13',
      'P006@14',
      'P011@15',
      'P007@16',
      'P013@17',
      'A010@18',
      'L002@19',
      'A002@19',
    ]);
    final lexerCodes = DiagnosticCode.values
        .map((c) => c.code)
        .where((c) => c.startsWith('L'))
        .toSet();
    expect(lexerCodes, hasLength(9), reason: 'add the new code to errorSample');
  });

  test('errorSample is read to the end', () {
    final names = [
      for (final m in parse(errorSample).unit.members)
        if (m is ProcedureDecl) m.name.name,
    ];
    expect(names, ['Main', 'Later']);
  });
}
