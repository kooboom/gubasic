import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';

/// The designer's grid, in logical pixels: with the grid on, controls
/// are placed on it and sized in its steps (D34).
const gridStep = 8;

/// The smallest width or height the designer gives a control.
const minControlSize = 8;

/// A drag shorter than this, across and down, places a control at its
/// default size, as a click does.
const clickDistance = 4;

/// Where a control sits on its form: `Left`, `Top`, `Width`, `Height`.
typedef ControlBox = ({int left, int top, int width, int height});

/// [value] on the grid when [grid] is on: the nearest step.
int snap(num value, {required bool grid}) =>
    grid ? (value / gridStep).round() * gridStep : value.round();

/// The control types the toolbox offers, in its order.
List<ComponentSpec> get toolboxComponents => [
  for (final name in const ['button', 'label', 'textbox'])
    builtinComponents[name]!,
];

/// The name a new control of [type] gets on [form]: the type's name and
/// the smallest number from 1 that no control uses, in any case
/// (`Button1`, then `Button2`; `Button1` again once it is deleted).
String newControlName(FormFile form, ComponentSpec type) {
  for (var n = 1; ; n++) {
    final name = '${type.name}$n';
    if (form.control(name) == null) return name;
  }
}

/// The box of [control] on its form.
ControlBox boxOf(ControlDecl control) => (
  left: control.valueOf('Left') as int,
  top: control.valueOf('Top') as int,
  width: control.valueOf('Width') as int,
  height: control.valueOf('Height') as int,
);

/// The form's inside size: `Width` x `Height`.
({int width, int height}) formSizeOf(FormFile form) => (
  width: form.valueOf('Width') as int,
  height: form.valueOf('Height') as int,
);

/// The default size of a control of [type], from its component.yaml.
({int width, int height}) defaultSizeOf(ComponentSpec type) => (
  width: type.properties['width']!.defaultValue as int,
  height: type.properties['height']!.defaultValue as int,
);

/// The box a control of [type] gets when the user drags from [start] to
/// [end] on [form], in any direction. A drag of less than
/// [clickDistance] is a click: the default size at [start]. The box is on
/// the grid when [grid] is on and inside the form where it fits.
ControlBox drawnBox(
  FormFile form,
  ComponentSpec type, {
  required Point<double> start,
  required Point<double> end,
  required bool grid,
}) {
  final size = formSizeOf(form);
  final isClick =
      (end.x - start.x).abs() < clickDistance &&
      (end.y - start.y).abs() < clickDistance;
  if (isClick) {
    final d = defaultSizeOf(type);
    return _inside((
      left: snap(start.x, grid: grid),
      top: snap(start.y, grid: grid),
      width: d.width,
      height: d.height,
    ), size);
  }
  int clampX(double x) =>
      min(snap(x.clamp(0, size.width), grid: grid), size.width);
  int clampY(double y) =>
      min(snap(y.clamp(0, size.height), grid: grid), size.height);
  final left = clampX(min(start.x, end.x));
  final top = clampY(min(start.y, end.y));
  final right = clampX(max(start.x, end.x));
  final bottom = clampY(max(start.y, end.y));
  final smallest = grid ? max(gridStep, minControlSize) : minControlSize;
  return _inside((
    left: left,
    top: top,
    width: max(right - left, smallest),
    height: max(bottom - top, smallest),
  ), size);
}

/// The box a control of [type] gets when placed from the toolbox with a
/// double-click: its default size in the middle of [form], moved down
/// and right by a grid step while another control starts there.
ControlBox centredBox(FormFile form, ComponentSpec type, {required bool grid}) {
  final size = formSizeOf(form);
  final d = defaultSizeOf(type);
  var left = snap(max(0, (size.width - d.width) / 2), grid: grid);
  var top = snap(max(0, (size.height - d.height) / 2), grid: grid);
  bool taken(int l, int t) => form.controls.any((c) {
    final b = boxOf(c);
    return b.left == l && b.top == t;
  });
  while (taken(left, top)) {
    left += gridStep;
    top += gridStep;
  }
  return (left: left, top: top, width: d.width, height: d.height);
}

/// Moves [box] left and up so that it ends inside a form of [size], but
/// never past its top left corner.
ControlBox _inside(ControlBox box, ({int width, int height}) size) => (
  left: max(0, min(box.left, size.width - box.width)),
  top: max(0, min(box.top, size.height - box.height)),
  width: box.width,
  height: box.height,
);

/// [form] with a new control of [type] named [name] at [box], last, so
/// that it is drawn above the others. A type with a `Caption` shows its
/// name there.
FormFile withControl(
  FormFile form,
  ComponentSpec type,
  String name,
  ControlBox box,
) {
  final properties = <String, Object>{
    if (type.properties.containsKey('caption')) 'Caption': name,
    'Left': box.left,
    'Top': box.top,
    'Width': box.width,
    'Height': box.height,
  };
  return _copy(form, [
    ...form.controls,
    ControlDecl(name: name, component: type, properties: properties, line: 0),
  ]);
}

/// [form] without the control named [name].
FormFile withoutControl(FormFile form, String name) => _copy(form, [
  for (final c in form.controls)
    if (c.name.toLowerCase() != name.toLowerCase()) c,
]);

FormFile _copy(FormFile form, List<ControlDecl> controls) => FormFile(
  name: form.name,
  properties: Map.of(form.properties),
  controls: controls,
);

/// The texts a form file had as the designer changed it, to go back and
/// forth with undo and redo. Each finished action is one step; the
/// oldest steps are forgotten after [limit].
class FormHistory {
  FormHistory({this.limit = 100});

  final int limit;
  final _texts = <String>[];
  var _at = -1;

  bool get canUndo => _at > 0;
  bool get canRedo => _at < _texts.length - 1;

  /// Starts again from [text] unless it is the text the history is at:
  /// the file was changed some other way, so the old steps no longer
  /// lead to it.
  void follow(String text) {
    if (_at >= 0 && _texts[_at] == text) return;
    _texts
      ..clear()
      ..add(text);
    _at = 0;
  }

  /// Records [text] as the next step, after [follow]ing [before]. Steps
  /// that were undone are dropped.
  void record(String before, String text) {
    follow(before);
    if (text == before) return;
    _texts
      ..removeRange(_at + 1, _texts.length)
      ..add(text);
    if (_texts.length > limit + 1) _texts.removeAt(0);
    _at = _texts.length - 1;
  }

  /// The text one step back, or null.
  String? undo() => canUndo ? _texts[--_at] : null;

  /// The text one step forward, or null.
  String? redo() => canRedo ? _texts[++_at] : null;
}
