import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The text form of a Double (LANGUAGE 2.2) reads back as the same value
/// when written as a literal. The same test runs in Chrome
/// (apps/playground/test/platform_test.dart).
void main() {
  test('formatted Doubles read back as the same value', () {
    final random = Random(20261016);
    final values = <double>[
      0.1,
      0.5,
      1 / 3,
      2 / 3,
      0.1 + 0.2,
      1e15,
      1.5e20,
      1e21,
      1e-6,
      1e-7,
      2.5e-10,
      123456789012345.0,
      999999999999999.9,
      1.7976931348623157e308,
      5e-324,
      2.2250738585072014e-308,
      9.3e18,
      1.0,
      100.0,
      for (var i = 0; i < 2000; i++)
        random.nextDouble() * pow(10.0, random.nextInt(600) - 300),
    ];
    for (final x in values) {
      final text = formatDouble(x);
      final token = lex(text).tokens.first;
      expect(lex(text).diagnostics, isEmpty, reason: text);
      final back = token.kind == TokenKind.integerLiteral
          ? GbInt.parse(text)!.toDouble() // whole values print without "."
          : token.value! as double;
      expect(back, x, reason: text);
    }
  });
}
