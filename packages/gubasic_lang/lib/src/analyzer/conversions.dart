import '../diagnostics/diagnostic.dart';
import '../forms/component.dart';
import 'types.dart';

/// How a value of one type is turned into another without the program
/// asking for it. This table is the single definition used by the analyzer
/// and by the interpreter; see docs/LANGUAGE.md §2.1.
enum ImplicitConversion {
  /// Same type: nothing to do.
  none,

  /// Integer → Double.
  integerToDouble,

  /// Integer, Double, Boolean or Date → String, using [formatInteger],
  /// [formatDouble], [formatBoolean] or [formatDate].
  toText,

  /// Any value → Object (the value is kept as it is).
  toObject,

  /// `Nothing` → a reference type.
  nothingToReference,

  /// One side is unknown because of an earlier error: not checked.
  unchecked,
}

/// The result of asking whether a value can be stored in a place of
/// another type.
class ConversionCheck {
  const ConversionCheck.allowed(ImplicitConversion this.conversion)
      : error = null;
  const ConversionCheck.refused(DiagnosticCode this.error) : conversion = null;

  final ImplicitConversion? conversion;

  /// Why the conversion is refused: A009 (text to number), A010 (Double to
  /// Integer) or A008 (any other mismatch).
  final DiagnosticCode? error;

  bool get isAllowed => conversion != null;
}

/// Whether a value of type [from] can be stored where [to] is expected.
ConversionCheck checkConversion(GbType from, GbType to) {
  if (from == GbType.unknown || to == GbType.unknown) {
    return const ConversionCheck.allowed(ImplicitConversion.unchecked);
  }
  if (from == to) return const ConversionCheck.allowed(ImplicitConversion.none);
  if (to == GbType.object && from != GbType.void_) {
    return const ConversionCheck.allowed(ImplicitConversion.toObject);
  }
  if (from == GbType.nothing && to.isReferenceType) {
    return const ConversionCheck.allowed(ImplicitConversion.nothingToReference);
  }
  // A project's form (Form2) is a Form (D88, D98).
  if (to is ControlType &&
      from is ControlType &&
      to.form == null &&
      from.component == to.component) {
    return const ConversionCheck.allowed(ImplicitConversion.none);
  }
  // Any control is a Control; a Control is a particular control only
  // through CType (D98).
  if (to is ControlType &&
      to.component == controlComponent &&
      isControlType(from)) {
    return const ConversionCheck.allowed(ImplicitConversion.none);
  }
  if (from is ControlType &&
      from.component == controlComponent &&
      isControlType(to)) {
    return const ConversionCheck.refused(DiagnosticCode.controlNarrowing);
  }
  if (from == GbType.integer && to == GbType.double_) {
    return const ConversionCheck.allowed(ImplicitConversion.integerToDouble);
  }
  if (to == GbType.string && from.isValueType) {
    return const ConversionCheck.allowed(ImplicitConversion.toText);
  }
  if (from == GbType.string && to.isNumeric) {
    return const ConversionCheck.refused(DiagnosticCode.stringToNumber);
  }
  if (from == GbType.double_ && to == GbType.integer) {
    return const ConversionCheck.refused(DiagnosticCode.doubleToInteger);
  }
  return const ConversionCheck.refused(DiagnosticCode.typeMismatch);
}

// ---------------------------------------------------------------------------
// Text form of values (docs/LANGUAGE.md §2.2). Used by automatic conversion,
// CStr, & and Debug.Print alike. Dart's toString is not used because it
// differs between the VM and the web (1.0 prints as "1.0" or "1").

String formatInteger(int value) => '$value';

String formatBoolean(bool value) => value ? 'True' : 'False';

/// `yyyy-MM-dd HH:mm:ss`, always.
String formatDate(DateTime value) {
  String two(int n) => n.toString().padLeft(2, '0');
  return '${value.year.toString().padLeft(4, '0')}-${two(value.month)}-'
      '${two(value.day)} ${two(value.hour)}:${two(value.minute)}:'
      '${two(value.second)}';
}

/// The shortest text that reads back as exactly the same Double.
///
/// - Between 1E-6 (inclusive) and 1E+15 (exclusive) in size: plain
///   decimal; whole numbers have no decimal point (`1`, `0.25`, `-12.5`).
/// - Otherwise: `d.dddE+n` / `d.dddE-n` (`1E+15`, `2.5E-7`).
/// - `-0` prints as `0`; also `NaN`, `Infinity`, `-Infinity`.
String formatDouble(double value) {
  if (value.isNaN) return 'NaN';
  if (value.isInfinite) return value > 0 ? 'Infinity' : '-Infinity';
  if (value == 0) return '0';

  // toStringAsExponential() gives the shortest round-trip digits, and does
  // so identically on the VM and on the web: "-1.2345e+2".
  final exp = value.toStringAsExponential();
  final negative = exp.startsWith('-');
  final eAt = exp.indexOf('e');
  final mantissa = exp.substring(negative ? 1 : 0, eAt);
  final exponent = int.parse(exp.substring(eAt + 1));
  final digits = mantissa.replaceFirst('.', '');
  final sign = negative ? '-' : '';

  if (exponent < -6 || exponent >= 15) {
    final fraction = digits.length > 1 ? '.${digits.substring(1)}' : '';
    final expSign = exponent < 0 ? '-' : '+';
    return '$sign${digits[0]}${fraction}E$expSign${exponent.abs()}';
  }
  if (exponent < 0) {
    return '${sign}0.${'0' * (-exponent - 1)}$digits';
  }
  final intLength = exponent + 1;
  if (digits.length <= intLength) {
    return '$sign${digits.padRight(intLength, '0')}';
  }
  return '$sign${digits.substring(0, intLength)}.${digits.substring(intLength)}';
}

// ---------------------------------------------------------------------------
// Turning a Double into an Integer (docs/LANGUAGE.md §2.1).

const _int64Limit = 9223372036854775808.0; // 2⁶³

/// `CInt`: rounds half away from zero, as taught in school and as Excel's
/// ROUND does: 2.5 → 3, -2.5 → -3. Returns null if the result does not fit
/// in an Integer (or for NaN / Infinity).
int? roundToInteger(double value) {
  if (!value.isFinite) return null;
  // roundToDouble rounds half away from zero, on the VM and the web alike.
  final rounded = value.roundToDouble();
  return _fits(rounded) ? rounded.toInt() : null;
}

/// `Int`: rounds down to the smaller whole number: 2.5 → 2, -2.5 → -3.
/// Returns null if the result does not fit in an Integer.
int? floorToInteger(double value) {
  if (!value.isFinite) return null;
  final floored = value.floorToDouble();
  return _fits(floored) ? floored.toInt() : null;
}

bool _fits(double whole) => whole >= -_int64Limit && whole < _int64Limit;

/// `Round(value, digits)`: rounds half away from zero at [digits] places
/// after the decimal point (0 to 15), working on the shortest decimal text
/// of [value] rather than its binary value, so Round(2.675, 2) is 2.68 as
/// written, not 2.67. Returns null for digits outside 0–15.
double? roundToDigits(double value, int digits) {
  if (digits < 0 || digits > 15) return null;
  if (!value.isFinite || value == 0) return value;
  final exp = value.toStringAsExponential();
  final negative = exp.startsWith('-');
  final eAt = exp.indexOf('e');
  final mantissa = exp.substring(negative ? 1 : 0, eAt).replaceFirst('.', '');
  final exponent = int.parse(exp.substring(eAt + 1));
  // value = 0.d1 d2 … dn × 10^(exponent + 1); keep this many digits:
  final keep = exponent + 1 + digits;
  if (keep >= mantissa.length) return value; // nothing to round
  if (keep < 0) return negative ? -0.0 : 0.0;
  var kept = BigInt.parse(keep == 0 ? '0' : mantissa.substring(0, keep));
  if (mantissa.codeUnitAt(keep) >= 0x35) kept += BigInt.one; // '5'..'9'
  // kept × 10^(exponent + 1 - keep) = kept × 10^(-digits)
  final text = '${negative ? '-' : ''}${kept}e-$digits';
  return double.parse(text);
}
