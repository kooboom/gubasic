import '../analyzer/conversions.dart';
import '../analyzer/types.dart';
import '../forms/component.dart';
import 'checked_math.dart';

/// Values while a program runs:
///
/// | GuBASIC | Dart |
/// |---|---|
/// | Integer | [GbInt] (exact 64-bit on every platform) |
/// | Double | `double` |
/// | Boolean | `bool` |
/// | String | `String` |
/// | Date | `DateTime` |
/// | Nothing | `null` |
/// | List(Of T) | [GbList] |
/// | array | [GbArray] |
/// | Exception | [GbException] |
/// | a control, the form | [GbControl] |

class GbList {
  GbList(this.element, [List<Object?>? items]) : items = items ?? [];

  final GbType element;
  final List<Object?> items;
}

class GbArray {
  GbArray(this.element, this.items);

  final GbType element;
  List<Object?> items;
}

/// A control on the form, or the form itself (`btnSave`, `Me`). Its
/// properties live in the [FormHost]; this only names it.
class GbControl {
  GbControl(this.name, this.component, {this.form = ''});

  /// The control's name; null for the form.
  final String? name;
  final ComponentSpec component;

  /// The name of the form it is on, or is (D88).
  final String form;

  @override
  String toString() => name ?? 'Form';
}

class GbException {
  GbException(this.message);

  final String message;
}

/// The value a variable of [type] starts with.
Object? defaultValue(GbType type) => switch (type) {
      GbType.integer => GbInt.zero,
      GbType.double_ => 0.0,
      GbType.boolean => false,
      GbType.string => '',
      GbType.date => DateTime(1),
      _ => null,
    };

/// The text form of any value (docs/LANGUAGE.md §2.2).
String formatValue(Object? value) {
  if (isGbInt(value)) return (value as GbInt).format();
  if (isGbDouble(value)) return formatDouble((value as num).toDouble());
  return switch (value) {
    null => '',
    bool b => formatBoolean(b),
    String s => s,
    DateTime d => formatDate(d),
    GbList l => 'List(Of ${l.element.displayName})',
    GbArray a =>
      a.element.displayName == '?' ? '()' : '${a.element.displayName}()',
    GbException e => e.message,
    _ => '$value',
  };
}

/// The GuBASIC type name of a value, for messages.
String typeNameOf(Object? value) {
  if (isGbInt(value)) return 'Integer';
  if (isGbDouble(value)) return 'Double';
  return switch (value) {
    null => 'Nothing',
    bool() => 'Boolean',
    String() => 'String',
    DateTime() => 'Date',
    GbList l => 'List(Of ${l.element.displayName})',
    GbArray a => '${a.element.displayName}()',
    GbException() => 'Exception',
    GbControl c => c.component.name,
    _ => 'Object',
  };
}

/// Equality used by `=`, `List.Contains`, `List.IndexOf` and `Select Case`.
bool valuesEqual(Object? a, Object? b) {
  if (isGbInt(a) && isGbInt(b)) return (a as GbInt) == (b as GbInt);
  if ((isGbInt(a) || isGbDouble(a)) && (isGbInt(b) || isGbDouble(b))) {
    return toDoubleValue(a) == toDoubleValue(b);
  }
  return a == b;
}

/// An Integer or Double as a double.
double toDoubleValue(Object? value) =>
    isGbInt(value) ? (value as GbInt).toDouble() : (value as num).toDouble();
