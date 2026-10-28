import 'types.dart';

/// What a parameter accepts.
enum ArgKind {
  /// A value convertible to [ParamSpec.type] under the usual rules.
  typed,

  /// Any value at all (CStr, Debug.Print): it is shown as text.
  anyValue,

  /// Integer or Double.
  numeric,

  /// Integer, Double or String (CInt, CDbl: text is parsed).
  numericOrString,

  /// Integer, Double, Boolean or String (CBool).
  convertible,

  /// Any array.
  array,
}

class ParamSpec {
  const ParamSpec(this.name, this.type, {this.optional = false})
      : kind = ArgKind.typed;
  const ParamSpec.of(this.name, this.kind, {this.optional = false})
      : type = null;

  final String name;
  final ArgKind kind;

  /// For [ArgKind.typed].
  final GbType? type;
  final bool optional;
}

/// How a function's result type is decided.
enum ReturnKind {
  /// Always [Callable.returnType].
  fixed,

  /// The type of the first argument (Abs).
  sameAsFirstArgument,

  /// Integer if all arguments are Integer, otherwise Double (Min, Max).
  widerOfArguments,
}

/// Something that can be called: a built-in function or Sub, or a method
/// of a built-in type.
class Callable {
  const Callable(
    this.name,
    this.parameters,
    this.returnType, {
    this.returnKind = ReturnKind.fixed,
  });

  final String name;
  final List<ParamSpec> parameters;

  /// [GbType.void_] for a Sub.
  final GbType returnType;
  final ReturnKind returnKind;

  bool get isSub => returnType == GbType.void_;
  int get requiredCount => parameters.where((p) => !p.optional).length;
}

const _s = GbType.string;
const _i = GbType.integer;
const _d = GbType.double_;
const _b = GbType.boolean;
const _dt = GbType.date;
const _v = GbType.void_;

/// Built-in functions and Subs (docs/LANGUAGE.md §10), by lower-case name.
final Map<String, Callable> builtinFunctions = {
  for (final f in _builtins) f.name.toLowerCase(): f,
};

const _builtins = <Callable>[
  // Text. Positions count from 1.
  Callable('Len', [ParamSpec('text', _s)], _i),
  Callable('Left', [ParamSpec('text', _s), ParamSpec('length', _i)], _s),
  Callable('Right', [ParamSpec('text', _s), ParamSpec('length', _i)], _s),
  Callable(
      'Mid',
      [
        ParamSpec('text', _s),
        ParamSpec('start', _i),
        ParamSpec('length', _i, optional: true),
      ],
      _s),
  Callable('InStr', [ParamSpec('text', _s), ParamSpec('find', _s)], _i),
  Callable('UCase', [ParamSpec('text', _s)], _s),
  Callable('LCase', [ParamSpec('text', _s)], _s),
  Callable('Trim', [ParamSpec('text', _s)], _s),
  Callable(
      'Replace',
      [ParamSpec('text', _s), ParamSpec('find', _s), ParamSpec('with', _s)],
      _s),
  Callable('Split', [ParamSpec('text', _s), ParamSpec('separator', _s)],
      ArrayType(_s)),
  Callable('Join',
      [ParamSpec('items', ArrayType(_s)), ParamSpec('separator', _s)], _s),

  // Conversion.
  Callable('CInt', [ParamSpec.of('value', ArgKind.numericOrString)], _i),
  Callable('CDbl', [ParamSpec.of('value', ArgKind.numericOrString)], _d),
  Callable('CStr', [ParamSpec.of('value', ArgKind.anyValue)], _s),
  Callable('CBool', [ParamSpec.of('value', ArgKind.convertible)], _b),
  Callable('Val', [ParamSpec('text', _s)], _d),
  Callable('Str', [ParamSpec.of('value', ArgKind.numeric)], _s),

  // Math.
  Callable('Abs', [ParamSpec.of('value', ArgKind.numeric)], _d,
      returnKind: ReturnKind.sameAsFirstArgument),
  // Unlike VB, Int gives back an Integer (rounding down).
  Callable('Int', [ParamSpec('value', _d)], _i),
  Callable('Round',
      [ParamSpec('value', _d), ParamSpec('digits', _i, optional: true)], _d),
  Callable('Sqr', [ParamSpec('value', _d)], _d),
  Callable('Rnd', [], _d),
  Callable('Randomize', [ParamSpec('seed', _i, optional: true)], _v),
  Callable(
      'Min',
      [ParamSpec.of('a', ArgKind.numeric), ParamSpec.of('b', ArgKind.numeric)],
      _d,
      returnKind: ReturnKind.widerOfArguments),
  Callable(
      'Max',
      [ParamSpec.of('a', ArgKind.numeric), ParamSpec.of('b', ArgKind.numeric)],
      _d,
      returnKind: ReturnKind.widerOfArguments),

  // Arrays.
  Callable('UBound', [ParamSpec.of('items', ArgKind.array)], _i),

  // Date and time.
  Callable('Now', [], _dt),
  Callable('Today', [], _dt),
  Callable('Year', [ParamSpec('date', _dt)], _i),
  Callable('Month', [ParamSpec('date', _dt)], _i),
  Callable('Day', [ParamSpec('date', _dt)], _i),
  Callable('Hour', [ParamSpec('date', _dt)], _i),
  Callable('Minute', [ParamSpec('date', _dt)], _i),
  Callable('Second', [ParamSpec('date', _dt)], _i),

  // Dialogs.
  Callable('MsgBox',
      [ParamSpec('prompt', _s), ParamSpec('title', _s, optional: true)], _v),
  Callable(
      'InputBox',
      [
        ParamSpec('prompt', _s),
        ParamSpec('title', _s, optional: true),
        ParamSpec('default', _s, optional: true),
      ],
      _s),

  // Program.
  Callable('DoEvents', [], _v),

  // Settings.
  Callable('SaveSetting', [ParamSpec('key', _s), ParamSpec('value', _s)], _v),
  Callable('GetSetting', [ParamSpec('key', _s), ParamSpec('default', _s)], _s),
];

/// Built-in objects, by lower-case name. Their members are in members.dart.
const Map<String, String> builtinObjects = {
  'debug': 'Debug',
  'integer': 'Integer',
  'keys': 'Keys',
};
