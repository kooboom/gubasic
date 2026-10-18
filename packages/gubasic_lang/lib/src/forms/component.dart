import 'package:yaml/yaml.dart';

import '../analyzer/builtins.dart';
import '../analyzer/types.dart';
import 'components.g.dart';

/// The range of an Integer property unless its component.yaml narrows it:
/// 32 bits, the same on every platform.
const int integerPropertyMin = -2147483648;
const int integerPropertyMax = 2147483647;

/// A property of a component, as declared in its component.yaml.
class PropertySpec {
  const PropertySpec(
    this.name,
    this.type,
    this.defaultValue, {
    this.min = integerPropertyMin,
    this.max = integerPropertyMax,
    this.changeEvent,
    bool designTime = true,
    this.readOnly = false,
    this.internal = false,
  }) : designTime = designTime && !readOnly && !internal;

  final String name;

  /// Integer, Double, Boolean or String; `List(Of String)` for an
  /// [internal] property.
  final GbType type;

  /// An `int`, `double`, `bool`, `String` or `List<String>`, matching
  /// [type].
  final Object defaultValue;

  /// For Integer properties: the smallest and largest value allowed.
  final int min;
  final int max;

  /// The event that runs after the value changes, also when the program
  /// sets it (`Changed` for TextBox.Text). Null for most properties.
  final String? changeEvent;

  /// Whether the form file and the Properties window can set it. False
  /// for a property only the program sets while it runs (ListBox's
  /// ListIndex), and always false for [readOnly] and [internal] ones
  /// (docs/DESIGN.md D45).
  final bool designTime;

  /// The program can read it but not set it. Its value is not kept: the
  /// component's code works it out from the others (ListBox's ListCount
  /// from its items).
  final bool readOnly;

  /// State the runtime keeps for the component's code, which programs do
  /// not see as a property (ListBox's items, read through its methods).
  final bool internal;

  /// Whether a host keeps its value: all but the [readOnly] ones.
  bool get isStored => !readOnly;

  /// Whether [value] (an int for Integer properties) is in range.
  bool accepts(Object value) =>
      type != GbType.integer || (value is int && value >= min && value <= max);
}

/// An event of a component: `Click()`, later `Detected(code As String)`.
class EventSpec {
  const EventSpec(this.name, this.parameters);

  final String name;
  final List<ParamSpec> parameters;

  /// How a handler for control [controlName] is written, for messages:
  /// `btnSave_Click()`.
  String handlerSignature(String controlName) {
    final params = [
      for (final p in parameters) '${p.name} As ${p.type!.displayName}'
    ].join(', ');
    return '${controlName}_$name($params)';
  }
}

/// A method of a component: `AddItem(item As String)`,
/// `List(index As Integer) As String`.
class MethodSpec {
  const MethodSpec(this.name, this.parameters, this.returnType);

  final String name;
  final List<ParamSpec> parameters;

  /// [GbType.void_] for one that gives nothing back.
  final GbType returnType;
}

/// The layer a control is drawn in (docs/DESIGN.md D41): [graphic]
/// controls (Label) under all the others, whatever their order in the
/// form file; within a layer, a control later in the file is on top.
enum ComponentLayer { graphic, control }

/// A control type described by a component.yaml (docs/DESIGN.md §5, D10).
class ComponentSpec {
  ComponentSpec({
    required this.name,
    required this.version,
    required this.defaultEvent,
    required List<PropertySpec> properties,
    required List<EventSpec> events,
    List<MethodSpec> methods = const [],
    this.layer = ComponentLayer.control,
  })  : properties = {for (final p in properties) p.name.toLowerCase(): p},
        events = {for (final e in events) e.name.toLowerCase(): e},
        methods = {for (final m in methods) m.name.toLowerCase(): m};

  final String name;
  final int version;
  final String defaultEvent;

  /// `layer:` in the component.yaml; `control` when it is left out.
  final ComponentLayer layer;

  /// By lower-case name, in declaration order.
  final Map<String, PropertySpec> properties;

  /// By lower-case name, in declaration order.
  final Map<String, EventSpec> events;

  /// By lower-case name, in declaration order.
  final Map<String, MethodSpec> methods;

  /// The properties the form file and the Properties window can set.
  Iterable<PropertySpec> get designProperties =>
      properties.values.where((p) => p.designTime);

  /// The GuBASIC type of controls of this kind (`Button`).
  late final ControlType type = ControlType(this);
}

/// The built-in components, by lower-case name. Read from the
/// component.yaml files embedded in components.g.dart, so that the web
/// gets them too.
final Map<String, ComponentSpec> builtinComponents = {
  for (final text in builtinComponentFiles.values)
    for (final c in [readComponentFile(text)]) c.name.toLowerCase(): c,
};

/// The form's own component.
ComponentSpec get formComponent => builtinComponents['form']!;

const _valueTypes = {
  'integer': GbType.integer,
  'double': GbType.double_,
  'boolean': GbType.boolean,
  'string': GbType.string,
};

/// Reads a component.yaml. These files are part of GuBASIC, not of user
/// projects, so a mistake throws a [FormatException]; a test reads every
/// one of them.
ComponentSpec readComponentFile(String text) {
  final doc = loadYaml(text);
  if (doc is! YamlMap) throw const FormatException('expected a map');

  T field<T>(YamlMap map, String key) {
    final value = map[key];
    if (value is! T) throw FormatException('"$key" must be a $T');
    return value;
  }

  final properties = <PropertySpec>[];
  for (final p in field<YamlList>(doc, 'properties')) {
    if (p is! YamlMap) throw const FormatException('a property is not a map');
    final name = field<String>(p, 'name');
    final typeName = field<String>(p, 'type').toLowerCase();
    final internal = p['internal'] ?? false;
    final readOnly = p['readOnly'] ?? false;
    final designTime = p['designTime'] ?? true;
    if (internal is! bool || readOnly is! bool || designTime is! bool) {
      throw FormatException('$name: internal, readOnly and designTime are '
          'true or false');
    }
    final type = typeName == 'list(of string)' && internal
        ? const ListType(GbType.string)
        : _valueTypes[typeName];
    if (type == null) throw FormatException('$name: unsupported type');
    final value = p['default'];
    final ok = switch (type) {
      GbType.integer => value is int,
      GbType.double_ => value is num,
      GbType.boolean => value is bool,
      ListType() => value is YamlList && value.every((v) => v is String),
      _ => value is String,
    };
    if (!ok) throw FormatException('$name: default does not match its type');
    final min = p['min'] ?? integerPropertyMin;
    final max = p['max'] ?? integerPropertyMax;
    if (min is! int ||
        max is! int ||
        min < integerPropertyMin ||
        max > integerPropertyMax ||
        (type != GbType.integer && (p['min'] != null || p['max'] != null))) {
      throw FormatException('$name: bad min or max');
    }
    final changeEvent = p['changeEvent'];
    if (changeEvent != null && changeEvent is! String) {
      throw FormatException('$name: bad changeEvent');
    }
    if (changeEvent != null && (readOnly || internal)) {
      throw FormatException('$name: only a property the program sets can '
          'have a changeEvent');
    }
    final spec = PropertySpec(
        name,
        type,
        switch (type) {
          GbType.double_ => (value as num).toDouble(),
          ListType() => List<String>.unmodifiable(value as YamlList),
          _ => value as Object,
        },
        min: min,
        max: max,
        changeEvent: changeEvent as String?,
        designTime: designTime,
        readOnly: readOnly,
        internal: internal);
    if (!spec.accepts(spec.defaultValue)) {
      throw FormatException('$name: default is out of range');
    }
    properties.add(spec);
  }

  final events = <EventSpec>[];
  final eventPattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\((.*)\)$');
  for (final e in field<YamlList>(doc, 'events')) {
    final m = e is String ? eventPattern.firstMatch(e.trim()) : null;
    if (m == null) throw FormatException('bad event: $e');
    events.add(EventSpec(m[1]!, _parameters(m[2]!)));
  }

  final methods = <MethodSpec>[];
  final methodPattern =
      RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\((.*)\)(?: As ([A-Za-z]+))?$');
  for (final m in doc['methods'] as YamlList? ?? YamlList()) {
    final mm = m is String ? methodPattern.firstMatch(m.trim()) : null;
    if (mm == null) throw FormatException('bad method: $m');
    final returnType =
        mm[3] == null ? GbType.void_ : _valueTypes[mm[3]!.toLowerCase()];
    if (returnType == null) throw FormatException('bad return type: $m');
    methods.add(MethodSpec(mm[1]!, _parameters(mm[2]!), returnType));
  }

  final layerName = doc['layer'] ?? 'control';
  final layer =
      ComponentLayer.values.where((l) => l.name == layerName).firstOrNull;
  if (layer == null) throw FormatException('bad layer: $layerName');

  final spec = ComponentSpec(
    name: field<String>(doc, 'name'),
    version: field<int>(doc, 'version'),
    defaultEvent: field<String>(doc, 'defaultEvent'),
    properties: properties,
    events: events,
    methods: methods,
    layer: layer,
  );
  if (!spec.events.containsKey(spec.defaultEvent.toLowerCase())) {
    throw FormatException('${spec.name}: defaultEvent is not an event');
  }
  for (final p in spec.properties.values) {
    final e = p.changeEvent;
    if (e != null && spec.events[e.toLowerCase()]?.parameters.isEmpty != true) {
      throw FormatException('${p.name}: changeEvent is not an event '
          'without parameters');
    }
  }
  return spec;
}

/// `a As Integer, b As String`: the parameters of an event or a method.
List<ParamSpec> _parameters(String text) {
  final paramPattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*) As ([A-Za-z]+)$');
  return [
    for (final part in text.split(',').where((s) => s.trim().isNotEmpty))
      switch (paramPattern.firstMatch(part.trim())) {
        final pm? when _valueTypes[pm[2]!.toLowerCase()] != null =>
          ParamSpec(pm[1]!, _valueTypes[pm[2]!.toLowerCase()]!),
        _ => throw FormatException('bad parameter: $part'),
      },
  ];
}
