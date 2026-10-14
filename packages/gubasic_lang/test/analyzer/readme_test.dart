import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

void main() {
  test('README example: only lblMessage is reported, as a control (A003)', () {
    final readme = File('../../README.md').readAsStringSync();
    final sample =
        RegExp(r'## A taste of the language\s+```vb\n(.*?)```', dotAll: true)
            .firstMatch(readme)![1]!;
    final r = compile(sample);
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), ['A003@4']);
    expect(r.diagnostics.single.args, ['lblMessage']);
    expect(r.diagnostics.single.message,
        contains('once the form designer exists'));
  });
}
