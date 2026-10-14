import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

const _i = GbType.integer;
const _d = GbType.double_;
const _b = GbType.boolean;
const _s = GbType.string;
const _dt = GbType.date;
const _o = GbType.object;
const _e = GbType.exception;
const _n = GbType.nothing;
const _list = ListType(GbType.string);
const _array = ArrayType(GbType.integer);

/// Expected result for every (from, to) pair: a conversion or an error.
const List<(GbType, GbType, Object)> _table = [
  // to Integer
  (_i, _i, ImplicitConversion.none),
  (_d, _i, DiagnosticCode.doubleToInteger),
  (_b, _i, DiagnosticCode.typeMismatch),
  (_s, _i, DiagnosticCode.stringToNumber),
  (_dt, _i, DiagnosticCode.typeMismatch),
  (_o, _i, DiagnosticCode.typeMismatch),
  (_n, _i, DiagnosticCode.typeMismatch),
  // to Double
  (_i, _d, ImplicitConversion.integerToDouble),
  (_d, _d, ImplicitConversion.none),
  (_b, _d, DiagnosticCode.typeMismatch),
  (_s, _d, DiagnosticCode.stringToNumber),
  (_o, _d, DiagnosticCode.typeMismatch),
  // to Boolean
  (_i, _b, DiagnosticCode.typeMismatch),
  (_s, _b, DiagnosticCode.typeMismatch),
  (_b, _b, ImplicitConversion.none),
  // to String
  (_i, _s, ImplicitConversion.toText),
  (_d, _s, ImplicitConversion.toText),
  (_b, _s, ImplicitConversion.toText),
  (_dt, _s, ImplicitConversion.toText),
  (_s, _s, ImplicitConversion.none),
  (_o, _s, DiagnosticCode.typeMismatch),
  (_n, _s, DiagnosticCode.typeMismatch), // H8
  (_list, _s, DiagnosticCode.typeMismatch),
  // to Date
  (_s, _dt, DiagnosticCode.typeMismatch),
  (_dt, _dt, ImplicitConversion.none),
  // to Object
  (_i, _o, ImplicitConversion.toObject),
  (_s, _o, ImplicitConversion.toObject),
  (_list, _o, ImplicitConversion.toObject),
  (_n, _o, ImplicitConversion.toObject),
  (_o, _o, ImplicitConversion.none),
  // to reference types
  (_n, _list, ImplicitConversion.nothingToReference),
  (_n, _array, ImplicitConversion.nothingToReference),
  (_n, _e, ImplicitConversion.nothingToReference),
  (_list, _list, ImplicitConversion.none),
  (ListType(_i), _list, DiagnosticCode.typeMismatch),
  (_array, ArrayType(_d), DiagnosticCode.typeMismatch),
  (_o, _list, DiagnosticCode.typeMismatch),
  (_s, _e, DiagnosticCode.typeMismatch),
  // a Sub call has no value
  (GbType.void_, _o, DiagnosticCode.typeMismatch),
  (GbType.void_, _s, DiagnosticCode.typeMismatch),
];

void main() {
  for (final (from, to, expected) in _table) {
    test('$from → $to', () {
      final check = checkConversion(from, to);
      if (expected is ImplicitConversion) {
        expect(check.isAllowed, isTrue);
        expect(check.conversion, expected);
      } else {
        expect(check.isAllowed, isFalse);
        expect(check.error, expected);
      }
    });
  }

  test('anything involving an unknown type is not checked', () {
    for (final t in [_i, _s, _o, _list, GbType.unknown]) {
      expect(checkConversion(GbType.unknown, t).conversion,
          ImplicitConversion.unchecked);
      expect(checkConversion(t, GbType.unknown).conversion,
          ImplicitConversion.unchecked);
    }
  });

  test('type names', () {
    expect(_list.displayName, 'List(Of String)');
    expect(_array.displayName, 'Integer()');
    expect(
        const ListType(ListType(_i)).displayName, 'List(Of List(Of Integer))');
    expect(const ListType(_s), const ListType(_s));
    expect(const ListType(_s) == const ListType(_i), isFalse);
  });
}
