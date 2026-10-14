import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Runs on the VM and in Chrome (`dart test -p vm,chrome`): the lexer's
/// integer rules must give the same diagnostics on both, although the web
/// has no 64-bit integers.
void main() {
  const cases = {
    '9007199254740991': <String>[], // 2^53 - 1
    '9007199254740992': ['L007'], // 2^53
    '9007199254740993': ['L007'],
    '1234567890123456789': ['L007'],
    '9223372036854775807': ['L007'], // 2^63 - 1
    '9223372036854775808': ['L006'], // 2^63
    '99999999999999999999': ['L006'],
    '0009007199254740992': ['L007'],
    '9007199254740993.0': <String>[],
  };

  cases.forEach((source, expected) {
    test('$source → ${expected.isEmpty ? 'no diagnostic' : expected}', () {
      final r = lex(source);
      expect(r.diagnostics.map((d) => d.code.code), expected);
      expect(r.tokens.first.text, source, reason: 'text is always exact');
      expect(r.hasErrors, expected.contains('L006'));
    });
  });
}
