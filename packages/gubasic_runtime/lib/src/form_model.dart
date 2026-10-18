import 'package:flutter/foundation.dart';

/// The kinds of built-in controls (components/NAME/component.yaml).
enum GbControlKind { form, button, label, textBox, checkBox, listBox, image }

/// The layer a control is drawn in, its component.yaml's `layer`
/// (docs/DESIGN.md D41): [graphic] controls (Label) under all the others,
/// whatever their order; within a layer, a later control is on top and
/// takes the clicks where they overlap.
enum GbLayer { graphic, control }

/// One control's current properties: `Caption`, `Text`, `Left`, `Top`,
/// `Width`, `Height`, named as in its component.yaml. Values are `int`,
/// `double`, `bool`, `String`, or for a ListBox's `Items` a `List<String>`. Its widget rebuilds when they change.
class GbControlState extends ChangeNotifier {
  GbControlState(
    this.name,
    this.kind,
    Map<String, Object> properties, {
    this.layer = GbLayer.control,
  }) : _properties = Map.of(properties);

  /// The control's name; null for the form.
  final String? name;
  final GbControlKind kind;
  final GbLayer layer;
  final Map<String, Object> _properties;

  Object operator [](String property) =>
      _properties[property] ??
      (throw ArgumentError('${name ?? 'Form'} has no property $property'));

  String text(String property) => this[property] as String;
  int integer(String property) => this[property] as int;

  /// Sets a property. Setting the value it already has does nothing.
  void set(String property, Object value) {
    if (_properties[property] == value) return;
    _properties[property] = value;
    notifyListeners();
  }
}

/// Receives the events the user causes: `Click`, and `Changed` when the
/// user changes a TextBox's text or a CheckBox. [control] is null for the
/// form.
typedef GbEventSink = void Function(String? control, String event);

/// Whether the program would take [event] of [control] now. A CheckBox
/// asks before a click changes it: a click whose Changed would be ignored
/// changes nothing (docs/DESIGN.md D44).
typedef GbEventFilter = bool Function(String? control, String event);

/// The bytes of the project's picture [name] (PNG, JPEG or GIF), or null
/// when there is none. The IDE looks it up as the language does, in any
/// case (docs/DESIGN.md D51); a generated app from its assets.
typedef GbPictureSource = Uint8List? Function(String name);

/// A form and its controls while a program runs. The interpreter (through
/// the IDE) or a generated app reads and sets properties here; the widgets
/// show them and report what the user does through [onEvent].
class GbFormModel {
  GbFormModel({
    required Map<String, Object> form,
    required List<GbControlState> controls,
    required this.onEvent,
    GbEventFilter? accepts,
    this.designing = false,
    GbPictureSource? pictures,
  }) : pictures = pictures ?? _noPictures,
       accepts = accepts ?? _acceptAll,
       form = GbControlState(null, GbControlKind.form, form),
       controls = List.unmodifiable(controls);

  final GbControlState form;

  /// In the form file's order.
  final List<GbControlState> controls;
  final GbEventSink onEvent;
  final GbEventFilter accepts;

  /// Whether the form is shown in a designer rather than run: an empty
  /// ListBox then shows its name, so that it can be seen.
  final bool designing;

  /// The bytes of the project's picture named by an Image's `Picture`.
  final GbPictureSource pictures;

  static bool _acceptAll(String? control, String event) => true;
  static Uint8List? _noPictures(String name) => null;

  /// [controls] in the order they are drawn, the last on top: the
  /// graphic layer first, each layer in the form file's order (D41).
  late final List<GbControlState> drawingOrder = List.unmodifiable([
    for (final layer in GbLayer.values)
      for (final c in controls)
        if (c.layer == layer) c,
  ]);

  final _committers = <VoidCallback>[];

  /// The control named [name] (any case), or null; null names the form.
  GbControlState? control(String? name) {
    if (name == null) return form;
    final lower = name.toLowerCase();
    for (final c in controls) {
      if (c.name!.toLowerCase() == lower) return c;
    }
    return null;
  }

  /// TextBoxes register a callback that commits the characters the input
  /// method is still composing.
  void addCommitter(VoidCallback commit) => _committers.add(commit);
  void removeCommitter(VoidCallback commit) => _committers.remove(commit);

  /// Passes an event the user caused to [onEvent]. Before a click, text
  /// still being composed in any TextBox is committed, so the order is
  /// always: commit, TextBox.Changed, then Click (docs/LANGUAGE.md §11.1).
  void raise(String? control, String event) {
    if (event == 'Click') commitComposing();
    onEvent(control, event);
  }

  /// Commits the text still being composed in every TextBox, which raises
  /// their Changed. A click does this before its own event.
  void commitComposing() {
    for (final commit in List.of(_committers)) {
      commit();
    }
  }
}
