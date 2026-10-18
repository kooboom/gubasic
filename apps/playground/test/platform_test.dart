import 'dart:math' as math;

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Runs on the VM and in Chrome (`dart test -p vm,chrome`): rules that
/// could differ between the two (no 64-bit integers on the web, different
/// toString of doubles) must give the same results on both.
void main() {
  // L007 is retired (D26): large Integers are exact everywhere.
  const cases = {
    '9007199254740991': <String>[], // 2^53 - 1
    '9007199254740992': <String>[], // 2^53
    '9007199254740993': <String>[],
    '1234567890123456789': <String>[],
    '9223372036854775807': <String>[], // 2^63 - 1
    '9223372036854775808': ['L006'], // 2^63
    '99999999999999999999': ['L006'],
    '0009007199254740992': <String>[],
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

  group('exact 64-bit Integer (D26), same as checked_math_test', () {
    GbInt p(String s) => GbInt.parse(s)!;
    test('limits and overflow', () {
      expect(GbInt.maxValue.format(), '9223372036854775807');
      expect(GbInt.minValue.format(), '-9223372036854775808');
      expect(GbInt.maxValue + GbInt.one, isNull);
      expect(GbInt.minValue - GbInt.one, isNull);
      expect(GbInt.minValue.negate(), isNull);
      expect(GbInt.minValue.quotient(p('-1')), isNull);
      expect(p('3037000500') * p('3037000500'), isNull);
      expect(
          (p('3037000499') * p('3037000499'))!.format(), '9223372030926249001');
    });

    test('exact above 2^53', () {
      expect((p('9007199254740993') + p('2'))!.format(), '9007199254740995');
      expect((p('123456789012345678').quotient(p('7')))!.format(),
          '17636684144620811');
      expect(p('123456789012345678').remainder(p('1000')).format(), '678');
      expect(p('-7').remainder(p('3')).format(), '-1');
    });

    test('random numbers', () {
      final r = GbRandom()..seed(GbInt.of(42));
      expect([r.next(), r.next(), r.next()],
          [0.7415648787718233, 0.1599103928769201, 0.27860113025513866]);
    });
  });

  group('J3: deep calls', () {
    test('R009 at the default limit, on this platform too', () async {
      final result = await Interpreter(
              compile('Sub Main()\nF(1)\nEnd Sub\n'
                  'Sub F(n As Integer)\nF(n + 1)\nEnd Sub'),
              _QuietHost())
          .run();
      expect((result as RunFailed).error.code, DiagnosticCode.callsTooDeep);
      expect(result.error.args, ['$maxCallDepth']);
    });

    test('an error 9,999 calls deep reaches the top', () async {
      final result = await Interpreter(
              compile('Sub Main()\nF(1)\nEnd Sub\nSub F(n As Integer)\n'
                  'If n = 9999 Then Debug.Print(1 \\ 0)\nF(n + 1)\nEnd Sub'),
              _QuietHost())
          .run();
      expect((result as RunFailed).error.code, DiagnosticCode.divisionByZero);
    });
  });

  group('exponent literals and the text form read back the same', () {
    test('exponent literals', () {
      expect(lex('1E+21').tokens.first.value, 1e21);
      expect(lex('1.5E-7').tokens.first.value, 1.5e-7);
      expect(lex('2e10').tokens.first.value, 2e10);
      expect(lex('1E400').diagnostics.single.code.code, 'L008');
    });

    test('formatDouble → literal → same value', () {
      final random = math.Random(20261016);
      final values = <double>[
        0.1,
        1 / 3,
        0.1 + 0.2,
        1e15,
        1.5e20,
        1e-7,
        2.5e-10,
        9.3e18,
        1.7976931348623157e308,
        5e-324,
        123456789012345.0,
        for (var i = 0; i < 2000; i++)
          random.nextDouble() * math.pow(10.0, random.nextInt(600) - 300),
      ];
      for (final x in values) {
        final text = formatDouble(x);
        final token = lex(text).tokens.first;
        final back = token.kind == TokenKind.integerLiteral
            ? GbInt.parse(text)!.toDouble()
            : token.value! as double;
        expect(back, x, reason: text);
      }
    });
  });
}

class _QuietHost implements Host {
  @override
  void debugPrint(String line) {}
  @override
  Future<void> msgBox(String prompt, String title) async {}
  @override
  Future<String> inputBox(String p, String t, String d) async => '';
  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);
  @override
  Future<String?> loadSettings() async => null;
  @override
  Future<void> saveSettings(String text) async {}
}
