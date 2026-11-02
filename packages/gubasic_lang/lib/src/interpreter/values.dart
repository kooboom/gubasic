import '../analyzer/conversions.dart';
import '../analyzer/types.dart';
import '../forms/component.dart';
import '../pdf/pdf_document.dart';
import '../text/json.dart';
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
/// | Json | [GbJson] |
/// | HttpResponse | [GbHttpResponse] |

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

/// What a control's MouseDown and MouseUp are told (D111): the button, as
/// in MouseButtons, and where, from the control's top left corner.
class GbMouseEvent {
  const GbMouseEvent(this.button, this.x, this.y);

  final int button;
  final int x;
  final int y;
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
    GbMouseEvent() => 'MouseEventArgs',
    GbTable() => 'Table',
    GbPdfDocument() => 'PdfDocument',
    GbJson j => j.text,
    GbHttpResponse() => 'HttpResponse',
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
    GbMouseEvent() => 'MouseEventArgs',
    GbTable() => 'Table',
    GbPdfDocument() => 'PdfDocument',
    GbJson() => 'Json',
    GbHttpResponse() => 'HttpResponse',
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

/// A table of text, as a CSV file holds it (D114): named columns, and rows
/// of cells counted from 0, the header not among them.
class GbTable {
  GbTable([List<String>? headers, List<List<String>>? rows])
      : headers = headers ?? [],
        rows = rows ?? [];

  final List<String> headers;
  final List<List<String>> rows;

  /// [rows] read as a CSV file's: the first is the header; every row as
  /// wide as the widest, its missing cells "".
  factory GbTable.fromCsv(List<List<String>> lines) {
    final width = lines.fold(0, (w, r) => r.length > w ? r.length : w);
    List<String> padded(List<String> r) =>
        [...r, for (var i = r.length; i < width; i++) ''];
    return GbTable(
      lines.isEmpty ? [] : padded(lines.first),
      [for (final r in lines.skip(1)) padded(r)],
    );
  }

  /// The header and the rows, as a CSV file writes them.
  List<List<String>> get csv => [headers, ...rows];

  /// The number of the column named [name] (exactly, then in any case),
  /// or -1.
  int column(String name) {
    final i = headers.indexOf(name);
    if (i >= 0) return i;
    final lower = name.toLowerCase();
    return headers.indexWhere((h) => h.toLowerCase() == lower);
  }
}

/// A JSON value (docs/DESIGN.md D125): [value] as json.dart keeps it, an
/// object (`Map<String, Object?>`), an array (`List<Object?>`), a
/// `String`, an `int` or `double`, a `bool` or null. Two Json values that
/// share an object or array see each other's changes, as two List
/// variables do.
class GbJson {
  GbJson(this.value);

  /// An empty object, `New Json`.
  GbJson.object() : value = <String, Object?>{};

  /// An empty array, `Json.Array()`.
  GbJson.array() : value = <Object?>[];

  Object? value;

  /// `Kind`: `Object`, `Array`, `String`, `Number`, `Boolean` or `Null`.
  String get kind => jsonKind(value);

  /// The value as compact JSON text.
  String get json => writeJson(value);

  /// The text form (docs/LANGUAGE.md §2.2): a string's own text, a number
  /// as GuBASIC writes it, `True` or `False`, "" for null, and an object
  /// or an array as JSON text.
  String get text => switch (value) {
        null => '',
        final String s => s,
        final bool b => formatBoolean(b),
        final int i => '$i',
        final double d => formatDouble(d),
        _ => json,
      };
}

/// The whole answer to an HTTP request, from `Http.Send` (D125).
class GbHttpResponse {
  GbHttpResponse(this.status, this.headers, this.text);

  /// The status code, 200 or 404.
  final int status;

  /// The answer's headers, by lower-case name.
  final Map<String, String> headers;

  /// The body as text.
  final String text;

  /// `Ok`: a status below 400.
  bool get ok => status < 400;
}
