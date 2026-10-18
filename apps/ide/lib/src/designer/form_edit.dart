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
  for (final name in const ['button', 'label', 'textbox', 'checkbox'])
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

/// [form] with the control named [name] moved to the end of the list, on
/// top of the controls of its layer ([front]), or to its start, under
/// them (D42). The layers stay as they are (D41).
FormFile withOrder(FormFile form, String name, {required bool front}) {
  final lower = name.toLowerCase();
  final moved = form.controls.where((c) => c.name.toLowerCase() == lower);
  final others = form.controls.where((c) => c.name.toLowerCase() != lower);
  return _copy(form, front ? [...others, ...moved] : [...moved, ...others]);
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

/// How a step of [FormHistory] changed the form's code: a control was
/// renamed [from] one name [to] another, and the code with it (D39), from
/// [before] to [after].
typedef CodeRename = ({String from, String to, String before, String after});

/// The texts a form file had as the designer changed it, to go back and
/// forth with undo and redo. Each finished action is one step; the
/// oldest steps are forgotten after [limit]. Changes recorded with the
/// same group, such as the letters typed in one field of the Properties
/// window, make one step until [seal]. A step that renamed a control
/// also keeps how it changed the code, so that both go back together.
class FormHistory {
  FormHistory({this.limit = 100});

  final int limit;
  final _texts = <String>[];

  /// The code change of the step that leads to each text.
  final _codes = <CodeRename?>[];
  var _at = -1;

  /// The code change the last [undo] or [redo] went across, the way it
  /// went: after an undo, from the new name back to the old one.
  CodeRename? get lastCode => _lastCode;
  CodeRename? _lastCode;

  /// The group of the last step, while it may still grow.
  Object? _group;

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
    _codes
      ..clear()
      ..add(null);
    _at = 0;
    _group = null;
  }

  /// Records [text] as the next step, after [follow]ing [before], with
  /// the [code] change that goes with it. Steps that were undone are
  /// dropped.
  void record(String before, String text, {Object? group, CodeRename? code}) {
    follow(before);
    if (code == null &&
        group != null &&
        group == _group &&
        _at == _texts.length - 1) {
      // The same step goes on; back where it started, it is no step.
      if (text == _texts[_at - 1]) {
        _texts.removeLast();
        _codes.removeLast();
        _at--;
        _group = null;
      } else {
        _texts[_at] = text;
      }
      return;
    }
    _group = null;
    if (text == before && code == null) return;
    _texts
      ..removeRange(_at + 1, _texts.length)
      ..add(text);
    _codes
      ..removeRange(_at + 1, _codes.length)
      ..add(code);
    if (_texts.length > limit + 1) {
      _texts.removeAt(0);
      _codes.removeAt(0);
    }
    _at = _texts.length - 1;
    _group = group;
  }

  /// Ends the step of the current group: what is recorded next is a new
  /// step, even with the same group.
  void seal() => _group = null;

  /// The text one step back, or null.
  String? undo() {
    seal();
    _lastCode = null;
    if (!canUndo) return null;
    final c = _codes[_at];
    if (c != null) {
      _lastCode = (from: c.to, to: c.from, before: c.after, after: c.before);
    }
    return _texts[--_at];
  }

  /// The text one step forward, or null.
  String? redo() {
    seal();
    _lastCode = null;
    if (!canRedo) return null;
    _lastCode = _codes[++_at];
    return _texts[_at];
  }
}

/// The smallest width or height the designer gives a form.
const minFormSize = 64;

/// A handle of a control's frame: [x] is -1 at the left edge, 0 in the
/// middle, 1 at the right edge; [y] likewise from the top. (0, 0) is not
/// a handle.
typedef Handle = ({int x, int y});

/// The eight handles of a frame, corners first.
const List<Handle> handles = [
  (x: -1, y: -1),
  (x: 1, y: -1),
  (x: -1, y: 1),
  (x: 1, y: 1),
  (x: 0, y: -1),
  (x: 0, y: 1),
  (x: -1, y: 0),
  (x: 1, y: 0),
];

/// [box] moved by [dx], [dy]: its top left on the grid when [grid] is on,
/// and inside a form of [size] as far as it fits.
ControlBox movedBox(
  ControlBox box,
  double dx,
  double dy, {
  required ({int width, int height}) size,
  required bool grid,
}) => _inside((
  left: snap(box.left + dx, grid: grid),
  top: snap(box.top + dy, grid: grid),
  width: box.width,
  height: box.height,
), size);

/// [box] with the edges of [handle] moved by [dx], [dy]: on the grid when
/// [grid] is on, inside a form of [size], and never smaller than
/// [minControlSize]. The other edges stay where they are.
ControlBox resizedBox(
  ControlBox box,
  Handle handle,
  double dx,
  double dy, {
  required ({int width, int height}) size,
  required bool grid,
}) {
  var (left, right) = (box.left, box.left + box.width);
  var (top, bottom) = (box.top, box.top + box.height);
  if (handle.x < 0) {
    left = min(max(0, snap(left + dx, grid: grid)), right - minControlSize);
  } else if (handle.x > 0) {
    right = max(
      min(size.width, snap(right + dx, grid: grid)),
      left + minControlSize,
    );
  }
  if (handle.y < 0) {
    top = min(max(0, snap(top + dy, grid: grid)), bottom - minControlSize);
  } else if (handle.y > 0) {
    bottom = max(
      min(size.height, snap(bottom + dy, grid: grid)),
      top + minControlSize,
    );
  }
  return (left: left, top: top, width: right - left, height: bottom - top);
}

/// [value] one step in [direction] (+1 or -1): to the next grid line when
/// [grid] is on, else one pixel.
int step(int value, int direction, {required bool grid}) {
  if (!grid) return value + direction;
  final down = (value / gridStep).floor() * gridStep;
  return direction > 0
      ? down + gridStep
      : (down == value ? value - gridStep : down);
}

/// [box] moved one step by an arrow key, [dx] and [dy] being -1, 0 or 1,
/// inside a form of [size].
ControlBox nudgedBox(
  ControlBox box,
  int dx,
  int dy, {
  required ({int width, int height}) size,
  required bool grid,
}) => _inside((
  left: dx == 0 ? box.left : step(box.left, dx, grid: grid),
  top: dy == 0 ? box.top : step(box.top, dy, grid: grid),
  width: box.width,
  height: box.height,
), size);

/// [box] made one step wider or narrower ([dx]), taller or shorter
/// ([dy]) by an arrow key with Shift: its right or bottom edge moves,
/// inside a form of [size] and never below [minControlSize].
ControlBox grownBox(
  ControlBox box,
  int dx,
  int dy, {
  required ({int width, int height}) size,
  required bool grid,
}) {
  int edge(int start, int length, int d, int limit) => d == 0
      ? start + length
      : min(
          limit,
          max(start + minControlSize, step(start + length, d, grid: grid)),
        );
  return (
    left: box.left,
    top: box.top,
    width:
        edge(box.left, box.width, dx, max(size.width, box.left + box.width)) -
        box.left,
    height:
        edge(box.top, box.height, dy, max(size.height, box.top + box.height)) -
        box.top,
  );
}

/// A form's size after its right or bottom edge was dragged by [dx], [dy]:
/// on the grid when [grid] is on, and never below [minFormSize].
({int width, int height}) resizedForm(
  ({int width, int height}) size,
  double dx,
  double dy, {
  required bool grid,
}) => (
  width: max(minFormSize, snap(size.width + dx, grid: grid)),
  height: max(minFormSize, snap(size.height + dy, grid: grid)),
);

/// [form] with the control named [name] at [box].
FormFile withBox(FormFile form, String name, ControlBox box) => _copy(form, [
  for (final c in form.controls)
    if (c.name.toLowerCase() == name.toLowerCase())
      ControlDecl(
        name: c.name,
        component: c.component,
        properties: {
          ...c.properties,
          'Left': box.left,
          'Top': box.top,
          'Width': box.width,
          'Height': box.height,
        },
        line: c.line,
      )
    else
      c,
]);

/// [form] with its inside [size].
FormFile withFormSize(FormFile form, ({int width, int height}) size) =>
    FormFile(
      name: form.name,
      properties: {
        ...form.properties,
        'Width': size.width,
        'Height': size.height,
      },
      controls: form.controls,
    );

/// [form] with [property] of the control named [control], or of the form
/// itself when [control] is null, set to [value].
FormFile withProperty(
  FormFile form,
  String? control,
  String property,
  Object value,
) {
  if (control == null) {
    return FormFile(
      name: form.name,
      properties: {...form.properties, property: value},
      controls: form.controls,
    );
  }
  return _copy(form, [
    for (final c in form.controls)
      if (c.name.toLowerCase() == control.toLowerCase())
        ControlDecl(
          name: c.name,
          component: c.component,
          properties: {...c.properties, property: value},
          line: c.line,
        )
      else
        c,
  ]);
}

/// [form] with the control named [name] renamed to [newName]. Its
/// properties, `Caption` included, stay as they are.
FormFile withName(FormFile form, String name, String newName) => _copy(form, [
  for (final c in form.controls)
    if (c.name.toLowerCase() == name.toLowerCase())
      ControlDecl(
        name: newName,
        component: c.component,
        properties: c.properties,
        line: c.line,
      )
    else
      c,
]);
