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

/// A control, or a form itself (`btnSave`, `Me`). While it is on a form
/// its properties live in the [FormHost]; a control made with New, or
/// taken off its form, keeps them in [pending] (D98).
class GbControl {
  GbControl(this.name, this.component,
      {this.form = '', this.attached = true, this.container})
      : pending = attached ? <String, Object>{} : defaultProperties(component);

  /// The control's name; null for a form, and for a control made with New
  /// until it is given one or added to a form.
  String? name;
  final ComponentSpec component;

  /// The name of the form it is on, or is (D88).
  String form;

  /// The name of the Frame it is in on [form], or null (D105).
  String? container;

  /// Whether it is on [form]; always for a form.
  bool attached;

  /// Its properties while it is not on a form.
  final Map<String, Object> pending;

  /// The handler of each of its events, by lower-case event name: by name,
  /// by Handles, or by AddHandler (D98). A ProcedureDecl.
  final handlers = <String, Object>{};

  bool get isForm => component == formComponent;

  @override
  String toString() => name ?? (isForm ? form : component.name);
}

/// The properties a new control of [component] starts with: its
/// component's defaults.
Map<String, Object> defaultProperties(ComponentSpec component) => {
      for (final p in component.properties.values)
        if (p.isStored) p.name: p.defaultValue,
    };

/// The controls on a form, `Me.Controls` (D98): what the interpreter keeps
/// for it.
class GbControls {
  GbControls(this.form, this.items);

  /// The form's name.
  final String form;

  /// In the form file's order, then in the order they were added.
  final List<GbControl> items;
}

/// A module of the project, `Module1` (D102): what `Module1.Total` reads
/// through.
class GbModule {
  const GbModule(this.name);

  final String name;
}

/// What a form's KeyDown and KeyUp are told (D101): the key's number, as
/// in Keys, and the modifiers held.
class GbKeyEvent {
  const GbKeyEvent(this.keyCode,
      {this.shift = false, this.control = false, this.alt = false});

  final int keyCode;
  final bool shift;
  final bool control;
  final bool alt;
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
    GbControls() => 'Controls',
    GbKeyEvent() => 'KeyEventArgs',
    GbModule m => m.name,
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
    GbControls() => 'Controls',
    GbKeyEvent() => 'KeyEventArgs',
    GbModule m => m.name,
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
