import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Runs on the VM and in Chrome (`dart test -p vm,chrome`): rules that
/// could differ between the two (no 64-bit integers on the web, different
/// toString of doubles) must give the same results on both.
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

  group('text form of values (H10), same as test/analyzer/formatting_test', () {
    const doubles = <(double, String)>[
      (1.0, '1'),
      (-1.0, '-1'),
      (-0.0, '0'),
      (1.5, '1.5'),
      (0.1, '0.1'),
      (1 / 3, '0.3333333333333333'),
      (0.1 + 0.2, '0.30000000000000004'),
      (123456789012345.0, '123456789012345'),
      (999999999999999.9, '999999999999999.9'),
      (1e15, '1E+15'),
      (1.5e20, '1.5E+20'),
      (0.000001, '0.000001'),
      (1e-7, '1E-7'),
      (2.5e-10, '2.5E-10'),
      (1.7976931348623157e308, '1.7976931348623157E+308'),
      (5e-324, '5E-324'),
      (double.nan, 'NaN'),
      (double.infinity, 'Infinity'),
    ];
    for (final (value, text) in doubles) {
      test('formatDouble($text)', () => expect(formatDouble(value), text));
    }

    test('integers, booleans, dates', () {
      expect(formatInteger(9007199254740991), '9007199254740991');
      expect(formatInteger(-42), '-42');
      expect(formatBoolean(true), 'True');
      expect(formatDate(DateTime(2026, 3, 7, 9, 5, 2)), '2026-03-07 09:05:02');
    });

    test('rounding (H9)', () {
      expect(roundToInteger(2.5), 3);
      expect(roundToInteger(-2.5), -3);
      expect(floorToInteger(-2.5), -3);
      expect(roundToInteger(1e19), isNull);
    });
  });
}
