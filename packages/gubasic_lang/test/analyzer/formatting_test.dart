import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The same cases run in Chrome in apps/playground/test/platform_test.dart.
final doubleCases = <(double, String)>[
  (1.0, '1'),
  (-1.0, '-1'),
  (0.0, '0'),
  (-0.0, '0'),
  (1.5, '1.5'),
  (0.1, '0.1'),
  (0.25, '0.25'),
  (-12.5, '-12.5'),
  (2.5, '2.5'),
  (1 / 3, '0.3333333333333333'),
  (2 / 3, '0.6666666666666666'),
  (0.1 + 0.2, '0.30000000000000004'),
  (100.0, '100'),
  (123456789012345.0, '123456789012345'),
  (999999999999999.9, '999999999999999.9'),
  (1e15, '1E+15'),
  (1.5e20, '1.5E+20'),
  (1e21, '1E+21'),
  (0.000001, '0.000001'),
  (0.0000015, '0.0000015'),
  (1e-7, '1E-7'),
  (2.5e-10, '2.5E-10'),
  (1.7976931348623157e308, '1.7976931348623157E+308'),
  (5e-324, '5E-324'),
  (double.nan, 'NaN'),
  (double.infinity, 'Infinity'),
  (double.negativeInfinity, '-Infinity'),
];

void main() {
  for (final (value, text) in doubleCases) {
    test('formatDouble($value) = $text', () {
      expect(formatDouble(value), text);
    });
  }

  test('formatted doubles read back as the same value', () {
    for (final (v, _) in doubleCases.where((c) => c.$1.isFinite)) {
      final text = formatDouble(v).replaceFirst('E', 'e');
      expect(double.parse(text), v == 0 ? 0 : v);
    }
  });

  test('integers, booleans and dates', () {
    expect(formatInteger(0), '0');
    expect(formatInteger(-42), '-42');
    expect(formatInteger(9007199254740991), '9007199254740991');
    expect(formatBoolean(true), 'True');
    expect(formatBoolean(false), 'False');
    expect(formatDate(DateTime(2026, 3, 7, 9, 5, 2)), '2026-03-07 09:05:02');
    expect(formatDate(DateTime(1, 1, 1)), '0001-01-01 00:00:00');
  });

  group('rounding (H9)', () {
    test('CInt rounds half away from zero', () {
      expect(roundToInteger(2.5), 3);
      expect(roundToInteger(-2.5), -3);
      expect(roundToInteger(0.5), 1);
      expect(roundToInteger(1.5), 2);
      expect(roundToInteger(2.4999), 2);
      expect(roundToInteger(-0.4), 0);
    });

    test('Int rounds down to the smaller whole number', () {
      expect(floorToInteger(2.5), 2);
      expect(floorToInteger(-2.5), -3);
      expect(floorToInteger(-0.1), -1);
      expect(floorToInteger(3.0), 3);
    });

    test('out of range or not a number gives null', () {
      for (final v in [1e19, -1e19, double.nan, double.infinity]) {
        expect(roundToInteger(v), isNull, reason: '$v');
        expect(floorToInteger(v), isNull, reason: '$v');
      }
      expect(roundToInteger(9.2e18), isNotNull);
    });
  });
}
