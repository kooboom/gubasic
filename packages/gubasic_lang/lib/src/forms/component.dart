import 'package:yaml/yaml.dart';

import '../analyzer/builtins.dart';
import '../analyzer/types.dart';
import 'anchor.dart';
import 'shortcut.dart';
import 'components.g.dart';

/// The range of an Integer property unless its component.yaml narrows it:
/// 32 bits, the same on every platform.
const int integerPropertyMin = -2147483648;
const int integerPropertyMax = 2147483647;

/// The value of an ambient property that is not set (D137): the control
/// takes its Frame's, its form's, or the default.
class Unset {
  const Unset._();

  @override
  String toString() => '(unset)';
}

/// The one [Unset] value.
const unset = Unset._();

/// What an ambient property is when neither the control, its Frames nor
/// its form set it (D137): 9.75 points (13 pixels), not bold, the theme's
/// colours ("").
Object ambientDefault(GbType type) => switch (type) {
      GbType.double_ => 9.75,
      GbType.boolean => false,
      _ => '',
    };

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
    this.picture = false,
    this.pictures = false,
    this.anchor = false,
    this.shortcut = false,
    this.ambient = false,
  }) : designTime = designTime && !readOnly && !internal;

  final String name;

  /// Integer, Double, Boolean, String or Color (kept as [colorText] gives
  /// it, D137); `List(Of String)` for an [internal] property, `String()`
  /// for a [readOnly] one (D136).
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

  /// A String property that names one of the project's pictures, or ""
  /// for none (Image's Picture, D51): the form file and the program may
  /// give it only those names (F016, A037, R013), in any case.
  final bool picture;

  /// A String property naming several of the project's pictures,
  /// separated by commas (a Sprite's Frames, D138), or "".
  final bool pictures;

  /// A String property naming the edges of the form a control keeps its
  /// distance to (`Anchor`, D57): the form file and the program may give
  /// it only edge names (F017, A038, R014), kept as [normalAnchor] gives
  /// them.
  final bool anchor;

  /// A String property naming the keys that choose a menu item
  /// (`Shortcut`, D106): the form file and the program may give it only
  /// shortcuts (F022, A057, R024), kept as [normalShortcut] gives them.
  final bool shortcut;

  /// Whether a control that does not set it takes it from its Frame or
  /// its form (FontSize, FontBold, ForeColor, BackColor; D137): its
  /// [defaultValue] is [unset].
  final bool ambient;

  /// Whether a host keeps its value: all but the [readOnly] ones.
  bool get isStored => !readOnly;

  /// Whether [value] (an int for Integer properties) is in range: an
  /// Integer's, or a Double's with a min and max (FontSize, D137).
  bool accepts(Object value) => switch (type) {
        GbType.integer => value is int && value >= min && value <= max,
        GbType.double_ when value is double => value >= min && value <= max,
        _ => true,
      };
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
/// `List(index As Integer) As String`; one written with `Settable` after
/// it can be assigned to, as an indexed property: `grd.Cell(0, 1) = "90"`
/// (D114, D116).
class MethodSpec {
  const MethodSpec(this.name, this.parameters, this.returnType,
      {this.settable = false});

  final String name;
  final List<ParamSpec> parameters;

  /// [GbType.void_] for one that gives nothing back.
  final GbType returnType;
  final bool settable;
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
    this.otherNames = const {},
    this.otherEvents = const {},
    this.visual = true,
    this.aliases = const [],
    this.container = false,
    this.menu = false,
    this.object = false,
    this.channel = false,
    this.platforms = const [],
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

  /// Names other versions of BASIC use for a member GuBASIC calls
  /// differently, by lower-case name: `text` → `[Caption]` for a Button.
  /// The analyzer points to GuBASIC's member(s) (A036).
  final Map<String, List<String>> otherNames;

  /// Names other versions of BASIC give an event GuBASIC calls
  /// differently, by lower-case name: `timer` → `Tick` for a Timer
  /// (`Timer1_Timer` in Visual Basic 6). The analyzer points to GuBASIC's
  /// event (A051).
  final Map<String, String> otherEvents;

  /// Whether controls of this kind are seen on the form, with a place and
  /// a size. A Timer is not: the designer keeps it in a tray (D100).
  final bool visual;

  /// Names other versions of BASIC give this type (`RadioButton` for an
  /// OptionButton): the analyzer and the form file point to this one
  /// (A056, F020, D104).
  final List<String> aliases;

  /// Whether controls of this kind hold other controls, placed inside it
  /// (a Frame, D105): its OptionButtons are a group of their own.
  final bool container;

  /// Whether controls of this kind are the items of a form's menu bar
  /// (Menu, D106), written under `menus:` in the form file. Not [visual],
  /// and not in the designer's tray: the menu editor makes them.
  final bool menu;

  /// Whether this is a built-in object used by its name (`Http`, D125),
  /// through the component channel (COMPONENT_CHANNEL.md): one instance
  /// for the program, never on a form, in the toolbox or made with New.
  /// Its properties are set only by the program.
  final bool object;

  /// Whether this is a control in the designer's tray whose code comes
  /// through the component channel (`WebSocket`, D136): each control has
  /// an instance of its own, its read-only properties and its methods are
  /// the instance's, and the instance reports its events. Not [visual].
  final bool channel;

  /// Where an [object] or [channel] component runs (`web`, `macos`,
  /// `windows`), as its component.yaml says; empty for everywhere.
  final List<String> platforms;

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

/// The built-in components that are control types, by lower-case name:
/// all but the built-in objects (`Http`, D125).
final Map<String, ComponentSpec> controlComponents = {
  for (final MapEntry(:key, :value) in builtinComponents.entries)
    if (!value.object) key: value,
};

/// The built-in objects that come through the component channel (D125),
/// by lower-case name: `Http`.
final Map<String, ComponentSpec> objectComponents = {
  for (final MapEntry(:key, :value) in builtinComponents.entries)
    if (value.object) key: value,
};

/// The form's own component.
ComponentSpec get formComponent => builtinComponents['form']!;

/// The component of a form's menu items (D106).
ComponentSpec get menuComponent => builtinComponents['menu']!;

/// The built-in component another version of BASIC calls [name] (any
/// case), or null (D104).
ComponentSpec? componentAliased(String name) {
  final lower = name.toLowerCase();
  for (final c in controlComponents.values) {
    if (c.aliases.any((a) => a.toLowerCase() == lower)) return c;
  }
  return null;
}

/// `Control`, the type of any control on a form (docs/DESIGN.md D98): a
/// handler's `sender` for controls of different types, the items of
/// `Me.Controls`. It has what every control has: its place, size, Anchor
/// and Tag (and its Name, which every control has as a member). It is not
/// a component: nothing is made of it.
final ComponentSpec controlComponent = ComponentSpec(
  name: 'Control',
  version: 1,
  defaultEvent: '',
  properties: [
    for (final name in const [
      'Left',
      'Top',
      'Width',
      'Height',
      'Anchor',
      'Tag'
    ])
      builtinComponents['button']!.properties[name.toLowerCase()]!,
  ],
  events: const [],
);

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
    final picture = p['picture'] ?? false;
    final pictures = p['pictures'] ?? false;
    final anchor = p['anchor'] ?? false;
    final shortcut = p['shortcut'] ?? false;
    final ambient = p['ambient'] ?? false;
    if (ambient is! bool) throw FormatException('$name: bad ambient');
    if (internal is! bool ||
        readOnly is! bool ||
        designTime is! bool ||
        picture is! bool ||
        pictures is! bool ||
        anchor is! bool ||
        shortcut is! bool) {
      throw FormatException('$name: internal, readOnly, designTime, '
          'picture, pictures, anchor and shortcut are true or false');
    }
    final type = switch (typeName) {
      'list(of string)' when internal => const ListType(GbType.string),
      // A component's own list, read only (Room.Members, D136).
      'string()' when readOnly => const ArrayType(GbType.string),
      // A colour, ambient (D137).
      'color' when ambient => GbType.color,
      _ => _valueTypes[typeName],
    };
    if (type == null) throw FormatException('$name: unsupported type');
    if (ambient &&
        (p['default'] != null ||
            !const {GbType.double_, GbType.boolean, GbType.color}
                .contains(type))) {
      throw FormatException('$name: an ambient property is a Double, a '
          'Boolean or a Color, without a default');
    }
    final value = ambient ? unset : p['default'];
    final ok = ambient ||
        switch (type) {
          GbType.integer => value is int,
          GbType.double_ => value is num,
          GbType.boolean => value is bool,
          ListType() ||
          ArrayType() =>
            value is YamlList && value.every((v) => v is String),
          _ => value is String,
        };
    if (!ok) throw FormatException('$name: default does not match its type');
    final min = p['min'] ?? integerPropertyMin;
    final max = p['max'] ?? integerPropertyMax;
    if (min is! int ||
        max is! int ||
        min < integerPropertyMin ||
        max > integerPropertyMax ||
        (type != GbType.integer &&
            type != GbType.double_ &&
            (p['min'] != null || p['max'] != null))) {
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
          _ when ambient => unset,
          GbType.double_ => (value as num).toDouble(),
          ListType() ||
          ArrayType() =>
            List<String>.unmodifiable(value as YamlList),
          _ => value as Object,
        },
        min: min,
        max: max,
        changeEvent: changeEvent as String?,
        designTime: designTime,
        readOnly: readOnly,
        internal: internal,
        picture: picture,
        pictures: pictures,
        anchor: anchor,
        shortcut: shortcut,
        ambient: ambient);
    if (picture && (type != GbType.string || spec.defaultValue != '')) {
      throw FormatException('$name: a picture property is a String, '
          'empty by default');
    }
    if (pictures && (type != GbType.string || spec.defaultValue != '')) {
      throw FormatException('$name: a pictures property is a String, '
          'empty by default');
    }
    if (anchor &&
        (type != GbType.string ||
            normalAnchor(spec.defaultValue as String) != spec.defaultValue)) {
      throw FormatException('$name: an anchor property is a String whose '
          'default names edges as normalAnchor writes them');
    }
    if (shortcut &&
        (type != GbType.string ||
            normalShortcut(spec.defaultValue as String) != spec.defaultValue)) {
      throw FormatException('$name: a shortcut property is a String whose '
          'default is written as normalShortcut writes it');
    }
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
  final methodPattern = RegExp(
      r'^([A-Za-z][A-Za-z0-9_]*)\((.*)\)(?: As ([A-Za-z]+))?( Settable)?$');
  for (final m in doc['methods'] as YamlList? ?? YamlList()) {
    final mm = m is String ? methodPattern.firstMatch(m.trim()) : null;
    if (mm == null) throw FormatException('bad method: $m');
    final returnType =
        mm[3] == null ? GbType.void_ : _returnTypes[mm[3]!.toLowerCase()];
    if (returnType == null) throw FormatException('bad return type: $m');
    methods.add(MethodSpec(mm[1]!, _parameters(mm[2]!), returnType,
        settable: mm[4] != null));
  }

  final layerName = doc['layer'] ?? 'control';
  final layer =
      ComponentLayer.values.where((l) => l.name == layerName).firstOrNull;
  if (layer == null) throw FormatException('bad layer: $layerName');

  final otherNames = <String, List<String>>{};
  final others = doc['otherNames'] ?? YamlMap();
  if (others is! YamlMap) throw const FormatException('bad otherNames');
  for (final MapEntry(:key, :value) in others.entries) {
    final names = value is String ? [value] : value;
    if (key is! String ||
        names is! List ||
        names.isEmpty ||
        names.any((n) => n is! String)) {
      throw FormatException('bad otherNames: $key');
    }
    otherNames[key.toLowerCase()] = List.unmodifiable(names.cast<String>());
  }

  final otherEvents = <String, String>{};
  final eventNames = doc['otherEvents'] ?? YamlMap();
  if (eventNames is! YamlMap) throw const FormatException('bad otherEvents');
  for (final MapEntry(:key, :value) in eventNames.entries) {
    if (key is! String || value is! String) {
      throw FormatException('bad otherEvents: $key');
    }
    otherEvents[key.toLowerCase()] = value;
  }
  // A built-in object (D125): used by its name, never on a form.
  final object = doc['object'] ?? false;
  if (object is! bool) throw const FormatException('object is true or false');
  // A tray control through the component channel (D136).
  final channel = doc['channel'] ?? false;
  if (channel is! bool) {
    throw const FormatException('channel is true or false');
  }
  final visual = doc['visual'] ?? !object;
  if (visual is! bool) throw const FormatException('visual is true or false');
  final container = doc['container'] ?? false;
  final menu = doc['menu'] ?? false;
  if (container is! bool || menu is! bool) {
    throw const FormatException('container and menu are true or false');
  }
  final aliases = doc['aliases'] ?? YamlList();
  if (aliases is! List || aliases.any((a) => a is! String)) {
    throw const FormatException('aliases is a list of names');
  }
  final platforms = doc['platforms'] ?? YamlList();
  if (platforms is! List ||
      platforms.any((p) => !const {'web', 'macos', 'windows'}.contains(p))) {
    throw const FormatException('platforms is a list of web, macos, windows');
  }
  if (object && (visual || container || menu || aliases.isNotEmpty)) {
    throw const FormatException(
        'an object is not visual, a container, a menu or aliased');
  }
  if (channel && (object || visual || container || menu)) {
    throw const FormatException(
        'a channel control is not visual, an object, a container or a menu');
  }
  if (!object && !channel && (platforms.isNotEmpty || doc['object'] != null)) {
    throw const FormatException(
        'only an object or a channel control names its platforms');
  }

  final spec = ComponentSpec(
    name: field<String>(doc, 'name'),
    version: field<int>(doc, 'version'),
    defaultEvent: object && events.isEmpty
        ? (doc['defaultEvent'] as String? ?? '')
        : field<String>(doc, 'defaultEvent'),
    properties: properties,
    events: events,
    methods: methods,
    layer: layer,
    otherNames: otherNames,
    otherEvents: otherEvents,
    visual: visual,
    aliases: List.unmodifiable(aliases.cast<String>()),
    container: container,
    menu: menu,
    object: object,
    channel: channel,
    platforms: List.unmodifiable(platforms.cast<String>()),
  );
  for (final MapEntry(:key, :value) in spec.otherEvents.entries) {
    if (spec.events.containsKey(key) ||
        !spec.events.containsKey(value.toLowerCase())) {
      throw FormatException('${spec.name}: otherEvents $key must name an '
          'event GuBASIC calls $value');
    }
  }
  if (!spec.events.containsKey(spec.defaultEvent.toLowerCase()) &&
      !(object && events.isEmpty && spec.defaultEvent.isEmpty)) {
    throw FormatException('${spec.name}: defaultEvent is not an event');
  }
  for (final p in spec.properties.values) {
    final e = p.changeEvent;
    if (e != null && spec.events[e.toLowerCase()]?.parameters.isEmpty != true) {
      throw FormatException('${p.name}: changeEvent is not an event '
          'without parameters');
    }
  }
  // A program sees the properties that are not internal, and the methods.
  bool isMember(String name) =>
      spec.methods.containsKey(name.toLowerCase()) ||
      spec.properties[name.toLowerCase()]?.internal == false;
  for (final MapEntry(:key, :value) in spec.otherNames.entries) {
    if (isMember(key)) {
      throw FormatException('${spec.name}: $key is a member, not another '
          'name');
    }
    for (final name in value) {
      if (!isMember(name)) {
        throw FormatException('${spec.name}: $name in otherNames is not a '
            'member');
      }
    }
  }
  return spec;
}

/// The types an event's or a method's parameter can have: the values, a
/// key event's (D101), and a JSON value's (D125).
const _parameterTypes = {
  ..._valueTypes,
  'keyeventargs': GbType.keyEventArgs,
  'mouseeventargs': GbType.mouseEventArgs,
  'messageeventargs': GbType.messageEventArgs,
  'closeeventargs': GbType.closeEventArgs,
  'erroreventargs': GbType.errorEventArgs,
  'roomeventargs': GbType.roomEventArgs,
  'json': GbType.json,
};

/// The types a method can give back: a parameter's, the whole answer to
/// an HTTP request (D125) and a table of rows (D126).
const _returnTypes = {
  ..._parameterTypes,
  'httpresponse': GbType.httpResponse,
  'table': GbType.table,
};

/// `a As Integer, b As String`: the parameters of an event or a method.
/// `ParamArray values As Value`, last, takes the rest of the arguments,
/// each a value that can go into SQL (D126); `ParamArray headers As
/// String` takes the rest as strings (D135).
List<ParamSpec> _parameters(String text) {
  final paramPattern =
      RegExp(r'^(ParamArray )?([A-Za-z][A-Za-z0-9_]*) As ([A-Za-z]+)$');
  final params = [
    for (final part in text.split(',').where((s) => s.trim().isNotEmpty))
      switch (paramPattern.firstMatch(part.trim())) {
        final pm? when pm[1] != null && pm[3]!.toLowerCase() == 'value' =>
          ParamSpec.of(pm[2]!, ArgKind.sqlValue, variadic: true),
        final pm? when pm[1] != null && pm[3]!.toLowerCase() == 'string' =>
          ParamSpec(pm[2]!, GbType.string, variadic: true),
        final pm? when pm[1] != null =>
          throw FormatException('ParamArray takes Value or String only: $part'),
        // A form's menu (D106): Menu is a component, read after this one.
        final pm? when pm[3]!.toLowerCase() == 'menu' =>
          ParamSpec.of(pm[2]!, ArgKind.menu),
        // A Sprite (D138): Hits(other As Sprite).
        final pm? when pm[3]!.toLowerCase() == 'sprite' =>
          ParamSpec.of(pm[2]!, ArgKind.sprite),
        // A table's column, by its number or its name (D116).
        final pm? when pm[3]!.toLowerCase() == 'column' =>
          ParamSpec.of(pm[2]!, ArgKind.numericOrString),
        final pm? when _parameterTypes[pm[3]!.toLowerCase()] != null =>
          ParamSpec(pm[2]!, _parameterTypes[pm[3]!.toLowerCase()]!),
        _ => throw FormatException('bad parameter: $part'),
      },
  ];
  if (params.any((p) => p.variadic) && !params.last.variadic ||
      params.where((p) => p.variadic).length > 1) {
    throw FormatException('ParamArray must be the last parameter: $text');
  }
  return params;
}
