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
      'A026@10',
      'P006@11',
      'P011@12',
      'P007@13',
      'P013@14',
      'A010@15',
      'L002@16',
      'A002@16',
    ]);
    final lexerCodes = DiagnosticCode.values
        .map((c) => c.code)
        .where((c) => c.startsWith('L'))
        .toSet();
    expect(lexerCodes, hasLength(6), reason: 'add the new code to errorSample');
  });

  test('errorSample is read to the end', () {
    final names = [
      for (final m in parse(errorSample).unit.members)
        if (m is ProcedureDecl) m.name.name,
    ];
    expect(names, ['Main', 'Later']);
  });
}
