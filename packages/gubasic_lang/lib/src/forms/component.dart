import 'package:yaml/yaml.dart';

import '../analyzer/builtins.dart';
import '../analyzer/types.dart';
import 'components.g.dart';

/// A property of a component, as declared in its component.yaml.
class PropertySpec {
  const PropertySpec(this.name, this.type, this.defaultValue);

  final String name;

  /// Integer, Double, Boolean or String.
  final GbType type;

  /// An `int`, `double`, `bool` or `String`, matching [type].
  final Object defaultValue;
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

/// A control type described by a component.yaml (docs/DESIGN.md §5, D10).
class ComponentSpec {
  ComponentSpec({
    required this.name,
    required this.version,
    required this.defaultEvent,
    required List<PropertySpec> properties,
    required List<EventSpec> events,
  })  : properties = {for (final p in properties) p.name.toLowerCase(): p},
        events = {for (final e in events) e.name.toLowerCase(): e};

  final String name;
  final int version;
  final String defaultEvent;

  /// By lower-case name, in declaration order.
  final Map<String, PropertySpec> properties;

  /// By lower-case name, in declaration order.
  final Map<String, EventSpec> events;

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
    final type = _valueTypes[field<String>(p, 'type').toLowerCase()];
    if (type == null) throw FormatException('$name: unsupported type');
    final value = p['default'];
    final ok = switch (type) {
      GbType.integer => value is int,
      GbType.double_ => value is num,
      GbType.boolean => value is bool,
      _ => value is String,
    };
    if (!ok) throw FormatException('$name: default does not match its type');
    properties.add(PropertySpec(name, type,
        type == GbType.double_ ? (value as num).toDouble() : value as Object));
  }

  final events = <EventSpec>[];
  final eventPattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\((.*)\)$');
  final paramPattern = RegExp(r'^([A-Za-z][A-Za-z0-9_]*) As ([A-Za-z]+)$');
  for (final e in field<YamlList>(doc, 'events')) {
    final m = e is String ? eventPattern.firstMatch(e.trim()) : null;
    if (m == null) throw FormatException('bad event: $e');
    final params = <ParamSpec>[];
    for (final part in m[2]!.split(',').where((s) => s.trim().isNotEmpty)) {
      final pm = paramPattern.firstMatch(part.trim());
      final type = pm == null ? null : _valueTypes[pm[2]!.toLowerCase()];
      if (type == null) throw FormatException('bad parameter: $part');
      params.add(ParamSpec(pm![1]!, type));
    }
    events.add(EventSpec(m[1]!, params));
  }

  final spec = ComponentSpec(
    name: field<String>(doc, 'name'),
    version: field<int>(doc, 'version'),
    defaultEvent: field<String>(doc, 'defaultEvent'),
    properties: properties,
    events: events,
  );
  if (!spec.events.containsKey(spec.defaultEvent.toLowerCase())) {
    throw FormatException('${spec.name}: defaultEvent is not an event');
  }
  return spec;
}
