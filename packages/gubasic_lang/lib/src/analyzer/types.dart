import '../forms/component.dart';
import 'forms.dart';

/// A GuBASIC type, as seen by the analyzer (and later the interpreter).
sealed class GbType {
  const GbType();

  /// How the type is written in GuBASIC, e.g. `List(Of String)`.
  String get displayName;

  static const integer = PrimitiveType._('Integer');
  static const double_ = PrimitiveType._('Double');
  static const boolean = PrimitiveType._('Boolean');
  static const string = PrimitiveType._('String');
  static const date = PrimitiveType._('Date');
  static const object = PrimitiveType._('Object');
  static const exception = PrimitiveType._('Exception');

  /// What a form's KeyDown and KeyUp are told: the key and Shift, Control
  /// and Alt (docs/DESIGN.md D101).
  static const keyEventArgs = PrimitiveType._('KeyEventArgs');
  static const mouseEventArgs = PrimitiveType._('MouseEventArgs');
  static const table = PrimitiveType._('Table');

  /// A PDF file being put together (docs/DESIGN.md D117).
  static const pdfDocument = PrimitiveType._('PdfDocument');

  /// The type of the `Nothing` literal.
  static const nothing = SpecialType._('Nothing');

  /// The "type" of a Sub call: there is no value.
  static const void_ = SpecialType._('(no value)');

  /// A built-in object such as `Debug`: only its members can be used.
  static const builtinObject = SpecialType._('(built-in object)');

  /// A type the analyzer could not work out because of an earlier problem.
  /// Nothing is checked against it, so one mistake is reported once.
  static const unknown = SpecialType._('?');

  bool get isNumeric => this == integer || this == double_;

  /// Value types always hold a value; `Nothing` is not allowed for them.
  bool get isValueType =>
      this == integer ||
      this == double_ ||
      this == boolean ||
      this == string ||
      this == date;

  /// Types whose variables may hold `Nothing`.
  bool get isReferenceType =>
      this == object ||
      this == exception ||
      this is ListType ||
      this is ArrayType ||
      this is ControlType ||
      this is ControlsType;

  /// `Me.Controls`: the controls on a form (docs/DESIGN.md D98).
  static const controls = ControlsType._();

  @override
  String toString() => displayName;
}

final class PrimitiveType extends GbType {
  const PrimitiveType._(this.displayName);

  @override
  final String displayName;
}

final class SpecialType extends GbType {
  const SpecialType._(this.displayName);

  @override
  final String displayName;
}

/// `List(Of T)`.
final class ListType extends GbType {
  const ListType(this.element);

  final GbType element;

  @override
  String get displayName => 'List(Of ${element.displayName})';

  @override
  bool operator ==(Object other) =>
      other is ListType && other.element == element;

  @override
  int get hashCode => Object.hash(ListType, element);
}

/// An array, `Dim a(5) As T` or `Dim a() As T`.
final class ArrayType extends GbType {
  const ArrayType(this.element);

  final GbType element;

  @override
  String get displayName => '${element.displayName}()';

  @override
  bool operator ==(Object other) =>
      other is ArrayType && other.element == element;

  @override
  int get hashCode => Object.hash(ArrayType, element);
}

/// A control or form: `Button`, `Label`, `Form`, … Its members are the
/// properties of its component (docs/DESIGN.md §5); a form of a project
/// ([form]) also has its controls, `Public` variables and procedures as
/// members (D88).
final class ControlType extends GbType {
  ControlType(this.component, {this.form});

  final ComponentSpec component;

  /// The project's form this is, for `Form2` and `Me`; null otherwise.
  final FormInterface? form;

  @override
  String get displayName => form?.name ?? component.name;
}

/// A module of the project, `Module1` (docs/DESIGN.md D102): its members
/// are its `Public` variables and constants and its procedures that are
/// not `Private`.
final class ModuleType extends GbType {
  const ModuleType(this.module);

  final ModuleInterface module;

  @override
  String get displayName => module.name;
}

/// The controls on a form, `Me.Controls` (docs/DESIGN.md D98): counted,
/// numbered from 0, gone through with For Each, added to and removed from.
final class ControlsType extends GbType {
  const ControlsType._();

  @override
  String get displayName => 'Controls';
}

/// The type names a program can write after `As` or `New`, besides
/// `List(Of T)` and control types (see [lookupNamedType]). Looked up
/// ignoring case.
const Map<String, GbType> namedTypes = {
  'integer': GbType.integer,
  'double': GbType.double_,
  'boolean': GbType.boolean,
  'string': GbType.string,
  'date': GbType.date,
  'object': GbType.object,
  'exception': GbType.exception,
  'keyeventargs': GbType.keyEventArgs,
  'mouseeventargs': GbType.mouseEventArgs,
  'table': GbType.table,
  'pdfdocument': GbType.pdfDocument,
};

/// A type name written after `As` or `New` (not `List`): a built-in type
/// or a control type. Null if there is none. [name] is lower case.
GbType? lookupNamedType(String name) =>
    namedTypes[name] ??
    builtinComponents[name]?.type ??
    (name == 'control' ? controlComponent.type : null);

/// Whether [type] is a control's: a component's other than the form's, or
/// Control (D98).
bool isControlType(GbType type) =>
    type is ControlType &&
    type.component != formComponent &&
    type.component.visual;
