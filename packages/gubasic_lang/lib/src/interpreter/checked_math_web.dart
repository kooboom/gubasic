import 'package:fixnum/fixnum.dart';

/// An exact 64-bit GuBASIC Integer (`Int64` from package:fixnum on the
/// web, where Dart's `int` is a JavaScript number, exact only to 2⁵³).
///
/// Same API and results as the native implementation.
extension type GbInt._(Int64 _v) implements Object {
  static final GbInt zero = GbInt._(Int64.ZERO);
  static final GbInt one = GbInt._(Int64.ONE);
  static final GbInt maxValue = GbInt._(Int64.MAX_VALUE);
  static final GbInt minValue = GbInt._(Int64.MIN_VALUE);

  static GbInt of(int value) => GbInt._(Int64(value));

  static GbInt? parse(String text) {
    if (!RegExp(r'^[+-]?\d+$').hasMatch(text) || !_fitsDigits(text)) {
      return null;
    }
    return GbInt._(Int64.parseInt(text));
  }

  static GbInt fromWholeDouble(double value) =>
      GbInt._(Int64.parseInt(BigInt.from(value).toString()));

  static GbInt fromHalves(int high, int low) =>
      GbInt._(Int64.fromInts(high, low));

  GbInt? operator +(GbInt other) {
    final r = _v + other._v;
    return ((_v ^ r) & (other._v ^ r)).isNegative ? null : GbInt._(r);
  }

  GbInt? operator -(GbInt other) {
    final r = _v - other._v;
    return ((_v ^ other._v) & (_v ^ r)).isNegative ? null : GbInt._(r);
  }

  GbInt? operator *(GbInt other) {
    final a = _v, b = other._v;
    if (a.isZero || b.isZero) return zero;
    if ((a == _minusOne && b == Int64.MIN_VALUE) ||
        (b == _minusOne && a == Int64.MIN_VALUE)) {
      return null;
    }
    final r = a * b;
    return r ~/ b != a ? null : GbInt._(r);
  }

  GbInt? negate() => _v == Int64.MIN_VALUE ? null : GbInt._(-_v);

  GbInt? quotient(GbInt other) => _v == Int64.MIN_VALUE && other._v == _minusOne
      ? null
      : GbInt._(_v ~/ other._v);

  GbInt remainder(GbInt other) => GbInt._(_v.remainder(other._v));

  GbInt? abs() => _v.isNegative ? negate() : this;

  int compareTo(GbInt other) => _v.compareTo(other._v);
  bool get isZero => _v.isZero;
  bool get isNegative => _v.isNegative;

  double toDouble() => _v.toDouble();

  int? toSmallInt() {
    const limit = 9007199254740992;
    return _v.abs() < Int64(limit) ? _v.toInt() : null;
  }

  String format() => _v.toString();

  GbInt addWrapping(GbInt other) => GbInt._(_v + other._v);
  GbInt multiplyWrapping(GbInt other) => GbInt._(_v * other._v);
  GbInt xor(GbInt other) => GbInt._(_v ^ other._v);
  GbInt shiftRightUnsigned(int bits) => GbInt._(_v.shiftRightUnsigned(bits));
}

final _minusOne = Int64(-1);

bool isGbInt(Object? value) => value is Int64;

/// On the web every Dart number is a JavaScript number; Integers are
/// Int64 objects, so any number here is a Double.
bool isGbDouble(Object? value) => value is num;

GbInt timeSeed() => GbInt._(Int64(DateTime.now().microsecondsSinceEpoch));

bool _fitsDigits(String text) {
  final negative = text.startsWith('-');
  final digits = text
      .replaceFirst(RegExp(r'^[+-]'), '')
      .replaceFirst(RegExp('^0+(?=.)'), '');
  final limit = negative ? '9223372036854775808' : '9223372036854775807';
  if (digits.length != limit.length) return digits.length < limit.length;
  return digits.compareTo(limit) <= 0;
}
