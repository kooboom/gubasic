import '../forms/component.dart';
import '../forms/keys.dart';
import 'builtins.dart';
import 'symbols.dart';
import 'types.dart';

/// A property or method of a built-in type or object.
class MemberSpec {
  const MemberSpec.property(this.name, this.type, {this.readOnly = true})
      : method = null,
        settable = false;
  MemberSpec.method(
    this.name,
    List<ParamSpec> parameters,
    GbType returnType, {
    this.settable = false,
  })  : method = Callable(name, parameters, returnType),
        type = returnType,
        readOnly = true;

  final String name;

  /// The property's type, or the method's return type.
  final GbType type;
  final bool readOnly;

  /// Set for methods.
  final Callable? method;

  /// A method that can be assigned to, as an indexed property is:
  /// `t.Cell(0, 1) = "90"` (D114).
  final bool settable;

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
    case GbType.keyEventArgs:
      // The key, as a number of Keys (D101), and the modifiers held.
      list = const [
        MemberSpec.property('KeyCode', _i),
        MemberSpec.property('Shift', _b),
        MemberSpec.property('Control', _b),
        MemberSpec.property('Alt', _b),
      ];
    case GbType.table:
      // A table of text (D114): rows and columns from 0, a column by its
      // number or its name.
      list = [
        const MemberSpec.property('RowCount', _i),
        const MemberSpec.property('ColumnCount', _i),
        MemberSpec.method(
            'Cell',
            [
              const ParamSpec('row', _i),
              const ParamSpec.of('column', ArgKind.numericOrString),
            ],
            _s,
            settable: true),
        MemberSpec.method('Header', [const ParamSpec('column', _i)], _s,
            settable: true),
        MemberSpec.method('Column', [const ParamSpec('name', _s)], _i),
        MemberSpec.method('AddRow', [], _i),
        MemberSpec.method('AddColumn', [const ParamSpec('name', _s)], _v),
        MemberSpec.method('Clear', [], _v),
      ];
    case GbType.mouseEventArgs:
      // The button, as a number of MouseButtons, and where it went down or
      // up, from the control's top left corner (D111).
      list = const [
        MemberSpec.property('Button', _i),
        MemberSpec.property('X', _i),
        MemberSpec.property('Y', _i),
      ];
    case ModuleType(:final module):
      list = [
        for (final v in module.variables.values)
          MemberSpec.property(v.name, v.type,
              readOnly: v.kind == SymbolKind.constant),
        for (final p in module.procedures.values)
          if (p.callable case final c?)
            MemberSpec.method(c.name, c.parameters, c.returnType),
      ];
    case ControlsType():
      final control = controlComponent.type;
      list = [
        const MemberSpec.property('Count', _i),
        MemberSpec.method('Add', [ParamSpec('control', control)], _v),
        MemberSpec.method('Remove', [ParamSpec('control', control)], _v),
      ];
    case ControlType(:final component, :final form):
      list = [
        // Every control and form has a name (D98): a form's, and a
        // control's on a form, can only be read (A034, R019).
        const MemberSpec.property('Name', _s, readOnly: false),
        if (component == formComponent)
          const MemberSpec.property('Controls', GbType.controls),
        for (final p in component.properties.values)
          if (!p.internal)
            MemberSpec.property(p.name, p.type, readOnly: p.readOnly),
        for (final m in component.methods.values)
          MemberSpec.method(m.name, m.parameters, m.returnType),
        // A project's form: its controls, Public variables and procedures
        // (D88).
        if (form != null) ...[
          for (final c in form.file.controls)
            MemberSpec.property(c.name, c.component.type),
          for (final v in form.variables.values)
            MemberSpec.property(v.name, v.type,
                readOnly: v.kind == SymbolKind.constant),
          for (final p in form.procedures.values)
            if (p.callable case final c?)
              MemberSpec.method(c.name, c.parameters, c.returnType),
        ],
      ];
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
      // How a dialog form was closed (D103): DialogResult.OK is 1.
      'DialogResult' => {
          for (final name in dialogResults.keys)
            name.toLowerCase(): MemberSpec.property(name, _i),
        },
      // The keys KeyDown and KeyUp tell apart (D101): Keys.Left is 37.
      'Keys' => {
          for (final name in keyCodes.keys)
            name.toLowerCase(): MemberSpec.property(name, _i),
        },
      // The mouse's buttons (D111): MouseButtons.Left is 1048576.
      'MouseButtons' => {
          for (final name in mouseButtons.keys)
            name.toLowerCase(): MemberSpec.property(name, _i),
        },
      // CSV files as tables (D114).
      'Csv' => {
          'read': MemberSpec.method(
              'Read', [const ParamSpec('path', _s)], GbType.table),
          'write': MemberSpec.method(
              'Write',
              [
                const ParamSpec('path', _s),
                const ParamSpec('table', GbType.table)
              ],
              _v),
        },
      // Text files (D113): read, written, added to, there or not.
      'File' => {
          'readalltext': MemberSpec.method(
              'ReadAllText', [const ParamSpec('path', _s)], _s),
          'readalllines': MemberSpec.method('ReadAllLines',
              [const ParamSpec('path', _s)], const ArrayType(_s)),
          'writealltext': MemberSpec.method('WriteAllText',
              [const ParamSpec('path', _s), const ParamSpec('text', _s)], _v),
          'appendalltext': MemberSpec.method('AppendAllText',
              [const ParamSpec('path', _s), const ParamSpec('text', _s)], _v),
          'exists':
              MemberSpec.method('Exists', [const ParamSpec('path', _s)], _b),
        },
      _ => const {},
    };
