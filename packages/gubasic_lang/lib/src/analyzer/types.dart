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

  /// The type of the `Nothing` literal.
  static const nothing = SpecialType._('Nothing');

  /// The "type" of a Sub call: there is no value.
  static const void_ = SpecialType._('(no value)');

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
      this is ArrayType;

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

/// The type names a program can write after `As` or `New`, besides
/// `List(Of T)`. Looked up ignoring case.
const Map<String, GbType> namedTypes = {
  'integer': GbType.integer,
  'double': GbType.double_,
  'boolean': GbType.boolean,
  'string': GbType.string,
  'date': GbType.date,
  'object': GbType.object,
  'exception': GbType.exception,
};
