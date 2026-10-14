import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The same cases run in Chrome (apps/playground/test/platform_test.dart).
GbInt _p(String s) => GbInt.parse(s)!;

void main() {
  test('parse: exact, with range check', () {
    expect(_p('9223372036854775807').format(), '9223372036854775807');
    expect(_p('-9223372036854775808').format(), '-9223372036854775808');
    expect(_p('0009007199254740993').format(), '9007199254740993');
    expect(GbInt.parse('9223372036854775808'), isNull);
    expect(GbInt.parse('-9223372036854775809'), isNull);
    expect(GbInt.parse('1.5'), isNull);
    expect(GbInt.parse(''), isNull);
  });

  test('add and subtract: overflow exactly at the limits', () {
    expect((GbInt.maxValue - GbInt.one)!.format(), '9223372036854775806');
    expect(GbInt.maxValue + GbInt.one, isNull);
    expect(GbInt.minValue - GbInt.one, isNull);
    expect((GbInt.minValue + GbInt.one)!.format(), '-9223372036854775807');
    expect((_p('9007199254740993') + _p('2'))!.format(), '9007199254740995');
  });

  test('multiply: overflow detection', () {
    expect(
        (_p('3037000499') * _p('3037000499'))!.format(), '9223372030926249001');
    expect(_p('3037000500') * _p('3037000500'), isNull);
    expect(GbInt.minValue * _p('-1'), isNull);
    expect((GbInt.minValue * GbInt.one)!.format(), '-9223372036854775808');
    expect((_p('-4611686018427387904') * _p('2'))!.format(),
        '-9223372036854775808');
    expect(_p('4611686018427387904') * _p('2'), isNull);
  });

  test('negate, quotient, remainder, abs', () {
    expect(GbInt.minValue.negate(), isNull);
    expect(GbInt.maxValue.negate()!.format(), '-9223372036854775807');
    expect(GbInt.minValue.quotient(_p('-1')), isNull);
    expect(_p('-7').quotient(_p('2'))!.format(), '-3');
    expect(_p('-7').remainder(_p('3')).format(), '-1');
    expect(_p('7').remainder(_p('-3')).format(), '1');
    expect(GbInt.minValue.abs(), isNull);
  });

  test('conversions', () {
    expect(_p('9007199254740993').toDouble(), 9007199254740992.0);
    expect(GbInt.fromWholeDouble(-9223372036854775808.0).format(),
        '-9223372036854775808');
    expect(GbInt.fromWholeDouble(1e18).format(), '1000000000000000000');
    expect(_p('123').toSmallInt(), 123);
    expect(_p('9007199254740993').toSmallInt(), isNull);
    expect(isGbInt(GbInt.one), isTrue);
    expect(isGbDouble(1.5), isTrue);
    expect(isGbInt(1.5), isFalse);
  });

  test('random numbers (SplitMix64) match the reference values', () {
    final r = GbRandom()..seed(GbInt.of(42));
    expect([r.next(), r.next(), r.next()],
        [0.7415648787718233, 0.1599103928769201, 0.27860113025513866]);
  });
}
