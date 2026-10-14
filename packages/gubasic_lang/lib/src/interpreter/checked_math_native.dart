/// An exact 64-bit GuBASIC Integer (native `int` on the VM).
///
/// Checked operations return null on overflow; the interpreter reports
/// R001. Wrapping operations (`…Wrapping`) exist only for the random
/// number generator.
extension type const GbInt._(int _v) implements Object {
  static const GbInt zero = GbInt._(0);
  static const GbInt one = GbInt._(1);
  static const GbInt maxValue = GbInt._(0x7FFFFFFFFFFFFFFF);
  static const GbInt minValue = GbInt._(-0x8000000000000000);

  /// A small Dart int (a length, an index, a count).
  static GbInt of(int value) => GbInt._(value);

  /// Decimal digits with an optional sign. Null if they do not fit.
  static GbInt? parse(String text) {
    if (!RegExp(r'^[+-]?\d+$').hasMatch(text) || !_fitsDigits(text)) {
      return null;
    }
    return GbInt._(int.parse(text));
  }

  /// A whole-number double inside the Integer range (checked by caller).
  static GbInt fromWholeDouble(double value) => GbInt._(value.toInt());

  /// 64 bits given as two unsigned 32-bit halves.
  static GbInt fromHalves(int high, int low) =>
      GbInt._((high << 32) | (low & 0xFFFFFFFF));

  GbInt? operator +(GbInt other) {
    final r = _v + other._v;
    return ((_v ^ r) & (other._v ^ r)) < 0 ? null : GbInt._(r);
  }

  GbInt? operator -(GbInt other) {
    final r = _v - other._v;
    return ((_v ^ other._v) & (_v ^ r)) < 0 ? null : GbInt._(r);
  }

  GbInt? operator *(GbInt other) {
    final a = _v, b = other._v;
    if (a == 0 || b == 0) return zero;
    if ((a == -1 && b == minValue._v) || (b == -1 && a == minValue._v)) {
      return null;
    }
    final r = a * b;
    return r ~/ b != a ? null : GbInt._(r);
  }

  GbInt? negate() => _v == minValue._v ? null : GbInt._(-_v);

  /// `\`: truncates toward zero. [other] must not be zero.
  GbInt? quotient(GbInt other) =>
      _v == minValue._v && other._v == -1 ? null : GbInt._(_v ~/ other._v);

  /// `Mod`: the sign follows the left operand. [other] must not be zero.
  GbInt remainder(GbInt other) => GbInt._(_v.remainder(other._v));

  GbInt? abs() => _v < 0 ? negate() : this;

  int compareTo(GbInt other) => _v.compareTo(other._v);
  bool get isZero => _v == 0;
  bool get isNegative => _v < 0;

  double toDouble() => _v.toDouble();

  /// The value as a Dart int when it is small enough to be exact on every
  /// platform (|value| < 2⁵³), otherwise null. For indexes and counts.
  int? toSmallInt() => _v.abs() < 9007199254740992 ? _v : null;

  /// Decimal digits, exact.
  String format() => _v.toString();

  // Wrapping operations, for the random number generator only.
  GbInt addWrapping(GbInt other) => GbInt._(_v + other._v);
  GbInt multiplyWrapping(GbInt other) => GbInt._(_v * other._v);
  GbInt xor(GbInt other) => GbInt._(_v ^ other._v);
  GbInt shiftRightUnsigned(int bits) => GbInt._(_v >>> bits);
}

/// Whether [value] is a GuBASIC Integer.
bool isGbInt(Object? value) => value is int;

/// Whether [value] is a GuBASIC Double.
bool isGbDouble(Object? value) => value is double;

/// The current time in microseconds (for Randomize without a seed).
GbInt timeSeed() => GbInt._(DateTime.now().microsecondsSinceEpoch);

bool _fitsDigits(String text) {
  final negative = text.startsWith('-');
  final digits = text
      .replaceFirst(RegExp(r'^[+-]'), '')
      .replaceFirst(RegExp('^0+(?=.)'), '');
  final limit = negative ? '9223372036854775808' : '9223372036854775807';
  if (digits.length != limit.length) return digits.length < limit.length;
  return digits.compareTo(limit) <= 0;
}
