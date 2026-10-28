import 'dart:ui' show Offset;

import 'package:flutter/foundation.dart';

import 'anchor.dart';

/// The kinds of built-in controls (components/NAME/component.yaml).
enum GbControlKind {
  form,
  button,
  label,
  textBox,
  checkBox,
  listBox,
  image,
  optionButton,
  comboBox,
  frame,
  menu,
}

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
    this.container,
  }) : _properties = Map.of(properties);

  /// The control's name; null for the form.
  final String? name;

  /// The name of the Frame it is in, or null: on the form itself
  /// (docs/DESIGN.md D105). Its `Left` and `Top` are from the Frame's
  /// top-left corner, and its Anchor keeps distances to the Frame's edges.
  /// For a menu item, the menu it is in; null on the menu bar (D106).
  final String? container;
  final GbControlKind kind;
  final GbLayer layer;
  final Map<String, Object> _properties;

  Object operator [](String property) =>
      _properties[property] ??
      (throw ArgumentError('${name ?? 'Form'} has no property $property'));

  /// Whether the control has [property].
  bool has(String property) => _properties.containsKey(property);

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

/// Receives the keys the user presses and lets go on a form (D101):
/// [event] is `KeyDown` (also again while a key is held) or `KeyUp`,
/// [keyCode] its number (gbKeyCode). [inTextBox]: while a TextBox is typed
/// in.
typedef GbKeySink = void Function(
  String event,
  int keyCode, {
  required bool shift,
  required bool control,
  required bool alt,
  required bool inTextBox,
});

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
    this.onKey,
  }) : pictures = pictures ?? _noPictures,
       accepts = accepts ?? _acceptAll,
       form = GbControlState(null, GbControlKind.form, form),
       _controls = List.of(controls) {
    for (final c in _controls) {
      if (c.has('Anchor')) _bases[c] = _baseOf(c);
    }
  }

  final GbControlState form;

  final List<GbControlState> _controls;

  /// In the form file's order, then the ones the program added
  /// (docs/DESIGN.md D98).
  List<GbControlState> get controls => List.unmodifiable(_controls);

  /// Tells the form's view when a control is added or removed.
  Listenable get layout => _layout;
  final _layout = _Signal();
  final GbEventSink onEvent;
  final GbEventFilter accepts;

  /// Where the form's keys go (D101); null: nowhere.
  final GbKeySink? onKey;

  /// Gives the form the keyboard's focus, set by its view: so that its
  /// keys come to [onKey].
  VoidCallback? requestFocus;

  /// Where on the screen the mouse or a finger last went down on the form,
  /// set by its view: where `PopupMenu` shows a menu (D106).
  Offset? lastPointer;

  /// Whether the form is shown in a designer rather than run: an empty
  /// ListBox then shows its name, so that it can be seen.
  final bool designing;

  /// The bytes of the project's picture named by an Image's `Picture`.
  final GbPictureSource pictures;

  static bool _acceptAll(String? control, String event) => true;
  static Uint8List? _noPictures(String name) => null;

  /// The controls on the form itself in the order they are drawn, the last
  /// on top: the graphic layer first, each layer in the form file's order
  /// (D41). Those in a Frame are drawn in it: [drawnIn].
  List<GbControlState> get drawingOrder => drawnIn(null);

  /// The controls in the Frame named [container] (null: on the form
  /// itself), in the order they are drawn (D41, D105).
  List<GbControlState> drawnIn(String? container) =>
      (_drawingOrder ??= {})[container?.toLowerCase()] ??= List.unmodifiable([
        for (final layer in GbLayer.values)
          for (final c in _controls)
            if (c.layer == layer &&
                c.kind != GbControlKind.menu &&
                c.container?.toLowerCase() == container?.toLowerCase())
              c,
      ]);
  Map<String?, List<GbControlState>>? _drawingOrder;

  /// The form's menu items (D106), in the form file's order: each menu
  /// followed by its items.
  List<GbControlState> get menuItems => [
    for (final c in _controls)
      if (c.kind == GbControlKind.menu) c,
  ];

  /// The items of the menu named [menu], or of the menu bar for null
  /// (D106).
  List<GbControlState> menusIn(String? menu) => [
    for (final c in _controls)
      if (c.kind == GbControlKind.menu &&
          c.container?.toLowerCase() == menu?.toLowerCase())
        c,
  ];

  /// Puts [control] on the form, on top of the others of its layer, for
  /// the program (D98).
  void addControl(GbControlState control) {
    _controls.add(control);
    if (control.has('Anchor')) _bases[control] = _baseOf(control);
    _drawingOrder = null;
    _layout.ping();
  }

  /// Takes the control named [name] off the form, for the program (D98).
  void removeControl(String name) {
    final c = control(name) ?? (throw ArgumentError('no control $name'));
    _controls.remove(c);
    _bases.remove(c);
    _drawingOrder = null;
    _layout.ping();
  }

  final _committers = <VoidCallback>[];

  /// For each control with an Anchor: where it was, and the size of the
  /// form (or of its Frame) then, as the form file or the program last
  /// placed it (D57, D105). A Frame comes before the controls in it.
  final _bases = <GbControlState, (GbRect, int, int)>{};

  static const _placing = {'Left', 'Top', 'Width', 'Height', 'Anchor'};

  (GbRect, int, int) _baseOf(GbControlState c) {
    final outer = _outer(c);
    return (
      (
        left: c.integer('Left'),
        top: c.integer('Top'),
        width: c.integer('Width'),
        height: c.integer('Height'),
      ),
      outer.integer('Width'),
      outer.integer('Height'),
    );
  }

  /// What [c] is placed in: its Frame, or the form (D105).
  GbControlState _outer(GbControlState c) => control(c.container) ?? form;

  /// Moves the controls as their Anchor says, for the size now of the form
  /// and of each Frame, a Frame before the controls in it.
  void _place() {
    for (final MapEntry(key: c, value: (base, width, height))
        in _bases.entries) {
      final outer = _outer(c);
      final r = gbAnchored(
        base,
        c.text('Anchor'),
        baseWidth: width,
        baseHeight: height,
        width: outer.integer('Width'),
        height: outer.integer('Height'),
      );
      c
        ..set('Left', r.left)
        ..set('Top', r.top)
        ..set('Width', r.width)
        ..set('Height', r.height);
    }
  }

  /// Sets a property for the program (or a generated app). A control
  /// placed or anchored this way stays where it is put, at the form's
  /// size now, and follows its Anchor from there; a new `Width` or
  /// `Height` of the form moves the controls as their Anchor says (D57).
  void setProperty(String? name, String property, Object value) {
    final c = control(name) ?? (throw ArgumentError('no control $name'));
    c.set(property, value);
    if (identical(c, form)) {
      if (property == 'Width' || property == 'Height') _place();
    } else if (_placing.contains(property) && _bases.containsKey(c)) {
      _bases[c] = _baseOf(c);
      // A Frame's new size moves the controls in it (D105).
      if (property == 'Width' || property == 'Height') _place();
    }
  }

  /// The user makes the inside of the form [width] x [height] (the run
  /// window's corner dragged): the controls move as their Anchor says,
  /// then [onEvent] gets the form's `Resize` (D58), unless [raise] is
  /// false: while the corner is still being dragged, the window raises it
  /// once it is let go. Nothing happens when it already is that size.
  void resize(int width, int height, {bool raise = true}) {
    if (form.integer('Width') == width && form.integer('Height') == height) {
      return;
    }
    form
      ..set('Width', width)
      ..set('Height', height);
    _place();
    if (raise) onEvent(null, 'Resize');
  }

  /// The control named [name] (any case), or null; null names the form.
  GbControlState? control(String? name) {
    if (name == null) return form;
    final lower = name.toLowerCase();
    for (final c in _controls) {
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

/// A [ChangeNotifier] that only says that something changed.
class _Signal extends ChangeNotifier {
  void ping() => notifyListeners();
}
