import 'builtins.dart';
import 'types.dart';

/// A property or method of a built-in type or object.
class MemberSpec {
  const MemberSpec.property(this.name, this.type, {this.readOnly = true})
      : method = null;
  MemberSpec.method(
    this.name,
    List<ParamSpec> parameters,
    GbType returnType,
  )   : method = Callable(name, parameters, returnType),
        type = returnType,
        readOnly = true;

  final String name;

  /// The property's type, or the method's return type.
  final GbType type;
  final bool readOnly;

  /// Set for methods.
  final Callable? method;

  bool get isMethod => method != null;
}

const _s = GbType.string;
const _i = GbType.integer;
const _b = GbType.boolean;
const _v = GbType.void_;

/// The members of [type], by lower-case name. Null when the type's members
/// are not checked (Object, unknown).
Map<String, MemberSpec>? membersOf(GbType type) {
  final List<MemberSpec> list;
  switch (type) {
    case ListType(:final element):
      list = [
        const MemberSpec.property('Count', _i),
        MemberSpec.method('Add', [ParamSpec('item', element)], _v),
        MemberSpec.method('Insert',
            [const ParamSpec('index', _i), ParamSpec('item', element)], _v),
        MemberSpec.method('Remove', [ParamSpec('item', element)], _b),
        MemberSpec.method('RemoveAt', [const ParamSpec('index', _i)], _v),
        MemberSpec.method('Clear', [], _v),
        MemberSpec.method('Contains', [ParamSpec('item', element)], _b),
        MemberSpec.method('IndexOf', [ParamSpec('item', element)], _i),
      ];
    case ArrayType():
      list = [const MemberSpec.property('Length', _i)];
    case GbType.string:
      // String methods count from 0, as in VB.NET (docs/LANGUAGE.md §10).
      list = [
        const MemberSpec.property('Length', _i),
        MemberSpec.method(
            'Substring',
            [
              const ParamSpec('start', _i),
              const ParamSpec('length', _i, optional: true),
            ],
            _s),
        MemberSpec.method('IndexOf', [const ParamSpec('text', _s)], _i),
        MemberSpec.method('Contains', [const ParamSpec('text', _s)], _b),
        MemberSpec.method('StartsWith', [const ParamSpec('text', _s)], _b),
        MemberSpec.method('EndsWith', [const ParamSpec('text', _s)], _b),
        MemberSpec.method('Replace',
            [const ParamSpec('find', _s), const ParamSpec('with', _s)], _s),
        MemberSpec.method('ToUpper', [], _s),
        MemberSpec.method('ToLower', [], _s),
        MemberSpec.method('Trim', [], _s),
        MemberSpec.method(
            'Split', [const ParamSpec('separator', _s)], const ArrayType(_s)),
      ];
    case GbType.exception:
      list = [const MemberSpec.property('Message', _s)];
    case GbType.integer ||
          GbType.double_ ||
          GbType.boolean ||
          GbType.date ||
          GbType.nothing ||
          GbType.void_:
      list = const [];
    default:
      return null; // Object, unknown: not checked.
  }
  return {for (final m in list) m.name.toLowerCase(): m};
}

/// The members of the built-in object [name] (`Debug`), by lower-case name.
Map<String, MemberSpec> builtinObjectMembers(String name) => switch (name) {
      'Debug' => {
          'print': MemberSpec.method(
              'Print', [const ParamSpec.of('value', ArgKind.anyValue)], _v),
        },
      'Integer' => {
          'maxvalue': const MemberSpec.property('MaxValue', _i),
          'minvalue': const MemberSpec.property('MinValue', _i),
        },
      _ => const {},
    };
