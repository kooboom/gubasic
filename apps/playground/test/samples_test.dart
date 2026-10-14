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

  test('readmeSample lexes without diagnostics', () {
    expect(lex(readmeSample).diagnostics, isEmpty);
  });

  test('errorSample triggers every lexer diagnostic and reaches the end', () {
    final r = lex(errorSample);
    expect(r.diagnostics.map((d) => d.code.code),
        ['L002', 'L001', 'L003', 'L004', 'L005', 'L006']);
    expect(DiagnosticCode.values.length, 6,
        reason: 'add the new code to errorSample');
    final tokens = r.tokens;
    expect(tokens[tokens.length - 6].text, 'MsgBox');
    expect(tokens.last.kind, TokenKind.eof);
  });
}
