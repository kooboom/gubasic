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
  for (final name in const [
    'button',
    'label',
    'textbox',
    'checkbox',
    'listbox',
    'combobox',
    'optionbutton',
    'frame',
    'image',
    'timer',
  ])
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

/// The controls of [form] the designer chooses, copies and keeps in its
/// tray: all but its menu items, which the menu editor makes (D106).
Iterable<ControlDecl> designedControls(FormFile form) =>
    form.controls.where((c) => !c.component.menu);

/// The controls of [form] seen on it, with a place and a size: all but its
/// Timers, which the designer keeps in a tray (D100).
Iterable<ControlDecl> placedControls(FormFile form) =>
    form.controls.where((c) => c.component.visual);

/// The box of [control] as its file writes it: in its Frame, from the
/// Frame's top-left corner, if it is in one (D105); a control seen on the
/// form.
ControlBox boxOf(ControlDecl control) => (
  left: control.valueOf('Left') as int,
  top: control.valueOf('Top') as int,
  width: control.valueOf('Width') as int,
  height: control.valueOf('Height') as int,
);

/// The box of [control] where it is seen on [form]: in a Frame, moved by
/// where the Frame is (D105). The designer works with these.
ControlBox boxOn(FormFile form, ControlDecl control) =>
    shiftedBox(boxOf(control), originOf(form, control.container));

/// Where the inside of the Frame named [container] starts on [form], its
/// top-left corner: what the boxes of the controls in it are from (D105).
/// (0, 0) for the form itself.
({int left, int top}) originOf(FormFile form, String? container) {
  var (left, top) = (0, 0);
  var frame = container == null ? null : form.control(container);
  while (frame != null) {
    left += frame.valueOf('Left') as int;
    top += frame.valueOf('Top') as int;
    frame = frame.container == null ? null : form.control(frame.container!);
  }
  return (left: left, top: top);
}

/// The size of what the controls in [container] are placed in: that
/// Frame's, or the form's for null (D105).
({int width, int height}) roomOf(FormFile form, String? container) =>
    switch (container == null ? null : form.control(container)) {
      final frame? => (
        width: frame.valueOf('Width') as int,
        height: frame.valueOf('Height') as int,
      ),
      null => formSizeOf(form),
    };

/// [box] moved by [by], or back by it when [back].
ControlBox shiftedBox(
  ControlBox box,
  ({int left, int top}) by, {
  bool back = false,
}) {
  final sign = back ? -1 : 1;
  return (
    left: box.left + sign * by.left,
    top: box.top + sign * by.top,
    width: box.width,
    height: box.height,
  );
}

/// The Frame of [form] that a control put at [p] goes into: the innermost
/// one drawn there, or null for the form itself (D105). [except] and the
/// Frames in it are passed over.
String? frameAt(FormFile form, Point<double> p, {String? except}) {
  String? found;
  for (final c in form.controls) {
    if (!c.component.container ||
        (except != null && isWithin(form, c, except))) {
      continue;
    }
    final b = boxOn(form, c);
    // The controls come after the Frame they are in: the last one there is
    // the innermost.
    if (p.x >= b.left &&
        p.x < b.left + b.width &&
        p.y >= b.top &&
        p.y < b.top + b.height &&
        (c.container == null ||
            found?.toLowerCase() == c.container!.toLowerCase())) {
      found = c.name;
    }
  }
  return found;
}

/// Whether [control] is the control named [frame] or inside it, in any
/// depth (D105).
bool isWithin(FormFile form, ControlDecl control, String frame) {
  final lower = frame.toLowerCase();
  for (ControlDecl? c = control; c != null;) {
    if (c.name.toLowerCase() == lower) return true;
    c = c.container == null ? null : form.control(c.container!);
  }
  return false;
}

/// The names of [names] and of the controls inside them, in any depth, in
/// the form's order: what deleting or copying them takes (D105).
List<String> withInside(FormFile form, Iterable<String> names) => [
  for (final c in form.controls)
    if (names.any((n) => isWithin(form, c, n))) c.name,
];

/// [names] without those inside another of them: when a Frame moves, the
/// controls in it move with it (D105).
List<String> outermost(FormFile form, Iterable<String> names) => [
  for (final n in names)
    if (form.control(n) case final c?
        when !names.any(
          (other) =>
              other.toLowerCase() != n.toLowerCase() &&
              c.container != null &&
              isWithin(form, form.control(c.container!)!, other),
        ))
      n,
];

/// [control] with [properties], and [name] and [container] when given;
/// its line as it was.
ControlDecl _changed(
  ControlDecl control, {
  String? name,
  Map<String, Object>? properties,
  String? Function()? container,
}) => ControlDecl(
  name: name ?? control.name,
  component: control.component,
  properties: properties ?? control.properties,
  line: control.line,
  container: container == null ? control.container : container(),
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
/// the grid when [grid] is on and inside the form where it fits; inside
/// [room] instead when given, a Frame's, with [start] and [end] from its
/// corner (D105).
ControlBox drawnBox(
  FormFile form,
  ComponentSpec type, {
  required Point<double> start,
  required Point<double> end,
  required bool grid,
  ({int width, int height})? room,
}) {
  final size = room ?? formSizeOf(form);
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
  // Where a control is already, the next goes below it, then at the top
  // of the next column, so that captions never sit over each other (D68).
  bool taken(int l, int t) => placedControls(form).any((c) {
    final b = boxOf(c);
    return l < b.left + b.width &&
        b.left < l + d.width &&
        t < b.top + b.height &&
        b.top < t + d.height;
  });
  final step = snap(d.height + gridStep, grid: grid);
  final across = snap(d.width + gridStep, grid: grid);
  final firstTop = snap(gridStep, grid: grid);
  var l = left, t = top;
  while (taken(l, t)) {
    t += step;
    if (t + d.height > size.height) {
      t = firstTop;
      l += across;
      // The form is full: on the middle after all, as before.
      if (l + d.width > size.width) return _cascade(form, left, top, d);
    }
  }
  return (left: l, top: t, width: d.width, height: d.height);
}

/// A box [d] large at [left], [top], moved a grid step down and right
/// while a control has that very place.
ControlBox _cascade(
  FormFile form,
  int left,
  int top,
  ({int width, int height}) d,
) {
  bool taken(int l, int t) => placedControls(form).any((c) {
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

/// [form] with a new control of [type] named [name] at [box] on the form,
/// last, so that it is drawn above the others; in the Frame named
/// [container] if given (D105). A type with a `Caption` shows its name
/// there.
FormFile withControl(
  FormFile form,
  ComponentSpec type,
  String name,
  ControlBox box, {
  String? container,
}) {
  box = shiftedBox(box, originOf(form, container), back: true);
  final properties = <String, Object>{
    if (type.properties.containsKey('caption')) 'Caption': name,
    // A Timer has no place (D100).
    if (type.visual) ...{
      'Left': box.left,
      'Top': box.top,
      'Width': box.width,
      'Height': box.height,
    },
  };
  return _copy(form, [
    ...form.controls,
    ControlDecl(
      name: name,
      component: type,
      properties: properties,
      line: 0,
      container: container,
    ),
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

/// [form] without the control named [name], and the controls in it.
FormFile withoutControl(FormFile form, String name) =>
    withoutControls(form, [name]);

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

/// Whether a drag of [dx], [dy] on [start] (moving it, or with [handle]
/// resizing it) would take it past an edge of a form of [size], where
/// [movedBox] and [resizedBox] stop it (D77).
bool dragPastEdge(
  ControlBox start,
  Handle? handle,
  double dx,
  double dy, {
  required ({int width, int height}) size,
  required bool grid,
}) {
  int at(num v) => snap(v, grid: grid);
  if (handle == null) {
    final left = at(start.left + dx);
    final top = at(start.top + dy);
    return left < 0 ||
        top < 0 ||
        left + start.width > size.width ||
        top + start.height > size.height;
  }
  return (handle.x < 0 && at(start.left + dx) < 0) ||
      (handle.x > 0 && at(start.left + start.width + dx) > size.width) ||
      (handle.y < 0 && at(start.top + dy) < 0) ||
      (handle.y > 0 && at(start.top + start.height + dy) > size.height);
}

/// Where to show that [box], wholly outside a form of [size], is there
/// (D77): the point on the form's edge nearest the box's middle, and the
/// way out from it towards the box; null when part of it is inside.
({Point<double> at, Point<double> towards})? outsideMarker(
  ControlBox box,
  ({int width, int height}) size,
) {
  final inside =
      box.left < size.width &&
      box.top < size.height &&
      box.left + box.width > 0 &&
      box.top + box.height > 0;
  if (inside) return null;
  final mx = box.left + box.width / 2;
  final my = box.top + box.height / 2;
  final at = Point(
    mx.clamp(0, size.width).toDouble(),
    my.clamp(0, size.height).toDouble(),
  );
  final d = Point(mx - at.x, my - at.y);
  final length = d.magnitude;
  return (at: at, towards: Point(d.x / length, d.y / length));
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

/// [form] with the control named [name] at [box], where it is seen on the
/// form (D105).
FormFile withBox(FormFile form, String name, ControlBox box) {
  final container = form.control(name)?.container;
  return withOwnBox(
    form,
    name,
    shiftedBox(box, originOf(form, container), back: true),
  );
}

/// [form] with the control named [name] at [box] as its file writes it:
/// in its Frame, from the Frame's corner (D105).
FormFile withOwnBox(FormFile form, String name, ControlBox box) => _copy(form, [
  for (final c in form.controls)
    if (c.name.toLowerCase() == name.toLowerCase())
      _changed(
        c,
        properties: {
          ...c.properties,
          'Left': box.left,
          'Top': box.top,
          'Width': box.width,
          'Height': box.height,
        },
      )
    else
      c,
]);

/// Whether [box] reaches outside a form of [size] (D72).
bool isOutside(ControlBox box, ({int width, int height}) size) =>
    box.left < 0 ||
    box.top < 0 ||
    box.left + box.width > size.width ||
    box.top + box.height > size.height;

/// The controls of [form] that reach outside it, in the form's order;
/// those in a Frame go where it goes (D105).
List<ControlDecl> controlsOutside(FormFile form) {
  final size = formSizeOf(form);
  return [
    for (final c in placedControls(form))
      if (c.container == null && isOutside(boxOf(c), size)) c,
  ];
}

/// [box] brought inside a form of [size], along each axis on its own
/// (D72): a control that starts inside the form keeps its start and is
/// made to end at the form's edge, unless that would make it smaller than
/// [least], its type's default size; that one, and one that starts
/// outside, is moved in as little as it takes, made no larger than the
/// form.
ControlBox fittedInside(
  ControlBox box,
  ({int width, int height}) size, {
  required ({int width, int height}) least,
}) {
  (int, int) along(int start, int length, int room, int smallest) {
    if (start >= 0 && start < room) {
      if (start + length <= room) return (start, length);
      final shortened = room - start;
      if (shortened >= min(smallest, room)) return (start, shortened);
    }
    final fitted = min(length, room);
    return (start.clamp(0, room - fitted), fitted);
  }

  final (left, width) = along(box.left, box.width, size.width, least.width);
  final (top, height) = along(box.top, box.height, size.height, least.height);
  return (left: left, top: top, width: width, height: height);
}

/// [form] with every control that reaches outside it brought inside
/// (D72); the others, and every Anchor, as they are.
FormFile withControlsInside(FormFile form) {
  final size = formSizeOf(form);
  var inside = form;
  for (final c in controlsOutside(form)) {
    inside = withBox(
      inside,
      c.name,
      fittedInside(boxOf(c), size, least: defaultSizeOf(c.component)),
    );
  }
  return inside;
}

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
        _changed(c, properties: {...c.properties, property: value})
      else
        c,
  ]);
}

/// [form] with the control named [name] renamed to [newName]. Its
/// properties stay as they are, but a `Caption` that still is the old
/// name, as a new control gets it, takes the new one (D68): a Label1
/// renamed lblQuestion no longer says Label1 next to the next Label1. The
/// controls in a Frame that is renamed stay in it (D105).
FormFile withName(FormFile form, String name, String newName) {
  final lower = name.toLowerCase();
  return _copy(form, [
    for (final c in form.controls)
      if (c.name.toLowerCase() == lower)
        _changed(
          c,
          name: newName,
          properties: {
            ...c.properties,
            if (c.component.properties.containsKey('caption') &&
                c.valueOf('Caption') == c.name)
              'Caption': newName,
          },
        )
      else if (c.container?.toLowerCase() == lower)
        _changed(c, container: () => newName)
      else
        c,
  ]);
}

/// The form sizes the designer offers (D60), upright for a phone and a
/// tablet: the inside of the form, as `Width` and `Height`.
const formSizePresets = [
  (name: FormSizePreset.phone, width: 360, height: 800),
  (name: FormSizePreset.tablet, width: 768, height: 1024),
  (name: FormSizePreset.desktop, width: 800, height: 600),
];

enum FormSizePreset { phone, tablet, desktop }

/// The preset [size] is, upright or turned, or null.
({FormSizePreset name, bool turned})? presetOf(({int width, int height}) size) {
  for (final p in formSizePresets) {
    if (p.width == size.width && p.height == size.height) {
      return (name: p.name, turned: false);
    }
    if (p.width == size.height && p.height == size.width) {
      return (name: p.name, turned: true);
    }
  }
  return null;
}

/// What the designer moves controls from when the form changes size
/// (D59): each control's box and the form's size before the first of a
/// run of size changes, so that changing it back puts every control back
/// exactly.
typedef AnchorBase = ({
  Map<String, ControlBox> boxes,
  ({int width, int height}) size,
});

/// [form]'s controls and size as they are, to move controls from. The
/// boxes are as the file writes them: in a Frame, from its corner (D105).
AnchorBase anchorBaseOf(FormFile form) => (
  boxes: {for (final c in placedControls(form)) c.name.toLowerCase(): boxOf(c)},
  size: formSizeOf(form),
);

/// Where each control of [form], by name in lower case, goes when the
/// form becomes [size]: moved from [base] as its Anchor says (D57), never
/// to the grid; a control in a Frame as the Frame's size changes (D105).
/// A control [base] does not have stays where it is. The boxes are as the
/// file writes them.
Map<String, ControlBox> anchoredBoxes(
  FormFile form,
  ({int width, int height}) size,
  AnchorBase base,
) {
  final boxes = <String, ControlBox>{};
  // What each control is placed in, before and after: a Frame comes
  // before the controls in it.
  ({int width, int height}) outer(
    ControlDecl c,
    Map<String, ControlBox> of,
    ({int width, int height}) form,
  ) => switch (c.container == null ? null : of[c.container!.toLowerCase()]) {
    final b? => (width: b.width, height: b.height),
    null => form,
  };
  for (final c in placedControls(form)) {
    final key = c.name.toLowerCase();
    final before = outer(c, base.boxes, base.size);
    final after = outer(c, boxes, size);
    boxes[key] = switch (base.boxes[key]) {
      final from? => anchoredRect(
        from,
        c.valueOf('Anchor') as String,
        baseWidth: before.width,
        baseHeight: before.height,
        width: after.width,
        height: after.height,
      ),
      null => boxOf(c),
    };
  }
  return boxes;
}

/// [own], boxes as the file writes them by name in lower case, where they
/// are seen on [form] (D105).
Map<String, ControlBox> boxesOn(FormFile form, Map<String, ControlBox> own) {
  ({int left, int top}) origin(String? container) {
    var (left, top) = (0, 0);
    var frame = container == null ? null : form.control(container);
    while (frame != null) {
      final b = own[frame.name.toLowerCase()] ?? boxOf(frame);
      left += b.left;
      top += b.top;
      frame = frame.container == null ? null : form.control(frame.container!);
    }
    return (left: left, top: top);
  }

  return {
    for (final MapEntry(:key, :value) in own.entries)
      key: shiftedBox(value, origin(form.control(key)?.container)),
  };
}

/// [form] with its inside [size] and each control moved as its Anchor
/// says, from [base].
FormFile withAnchoredSize(
  FormFile form,
  ({int width, int height}) size,
  AnchorBase base,
) {
  final boxes = anchoredBoxes(form, size, base);
  var sized = withFormSize(form, size);
  for (final c in placedControls(form)) {
    sized = withOwnBox(sized, c.name, boxes[c.name.toLowerCase()]!);
  }
  return sized;
}

/// The lines that show [box]'s Anchor on a form of [size]: from the middle
/// of each edge it is anchored to, straight out to that edge of the form.
List<(Point<double>, Point<double>)> anchorLines(
  ControlBox box,
  String anchor,
  ({int width, int height}) size,
) {
  final words = anchor.split(' ');
  final midX = box.left + box.width / 2;
  final midY = box.top + box.height / 2;
  final right = (box.left + box.width).toDouble();
  final bottom = (box.top + box.height).toDouble();
  return [
    if (words.contains('Left'))
      (Point(0.0, midY), Point(box.left.toDouble(), midY)),
    if (words.contains('Top'))
      (Point(midX, 0.0), Point(midX, box.top.toDouble())),
    if (words.contains('Right'))
      (Point(right, midY), Point(size.width.toDouble(), midY)),
    if (words.contains('Bottom'))
      (Point(midX, bottom), Point(midX, size.height.toDouble())),
  ];
}

// Several controls at once: moving, deleting, copying and pasting them.

/// The smallest box around [boxes], which must not be empty.
ControlBox boundsOf(Iterable<ControlBox> boxes) {
  final left = boxes.map((b) => b.left).reduce(min);
  final top = boxes.map((b) => b.top).reduce(min);
  final right = boxes.map((b) => b.left + b.width).reduce(max);
  final bottom = boxes.map((b) => b.top + b.height).reduce(max);
  return (left: left, top: top, width: right - left, height: bottom - top);
}

/// [boxes] all moved as one, by as much as [move] moves the box around
/// them: so that they keep their places to one another, and stop together
/// at the form's edge.
Map<String, ControlBox> movedTogether(
  Map<String, ControlBox> boxes,
  ControlBox Function(ControlBox bounds) move,
) {
  final bounds = boundsOf(boxes.values);
  final moved = move(bounds);
  final dx = moved.left - bounds.left;
  final dy = moved.top - bounds.top;
  return {
    for (final MapEntry(key: name, value: b) in boxes.entries)
      name: (
        left: b.left + dx,
        top: b.top + dy,
        width: b.width,
        height: b.height,
      ),
  };
}

/// [form] with each control named in [boxes] at its box.
FormFile withBoxes(FormFile form, Map<String, ControlBox> boxes) {
  var result = form;
  for (final MapEntry(key: name, value: box) in boxes.entries) {
    result = withBox(result, name, box);
  }
  return result;
}

/// [form] without the controls named in [names], in any case, and the
/// controls inside them (D105).
FormFile withoutControls(FormFile form, Iterable<String> names) {
  final lower = {for (final n in withInside(form, names)) n.toLowerCase()};
  return _copy(form, [
    for (final c in form.controls)
      if (!lower.contains(c.name.toLowerCase())) c,
  ]);
}

/// [form] with the controls named in [names] on top of the others of
/// their layers ([front]), or under them (D42), keeping their order among
/// themselves.
FormFile withOrderOf(
  FormFile form,
  Iterable<String> names, {
  required bool front,
}) {
  final lower = {for (final n in names) n.toLowerCase()};
  final moved = form.controls.where(
    (c) => lower.contains(c.name.toLowerCase()),
  );
  final others = form.controls.where(
    (c) => !lower.contains(c.name.toLowerCase()),
  );
  return _copy(form, front ? [...others, ...moved] : [...moved, ...others]);
}

/// The controls named in [names] and those inside them, as the
/// designer's clipboard keeps them (D105): the outermost at the place
/// they are seen on [form], in no Frame; the others in their Frames.
List<ControlDecl> copiedControls(FormFile form, Iterable<String> names) {
  final roots = {for (final n in outermost(form, names)) n.toLowerCase()};
  return [
    for (final name in withInside(form, roots))
      if (form.control(name) case final c?)
        roots.contains(name.toLowerCase())
            ? _changed(
                c,
                properties: {
                  ...c.properties,
                  if (c.component.visual)
                    ...switch (boxOn(form, c)) {
                      final b => {'Left': b.left, 'Top': b.top},
                    },
                },
                container: () => null,
              )
            : c,
  ];
}

/// Controls pasted onto [form]: the form with them last, on top, and the
/// names they got.
typedef Pasted = ({FormFile form, List<String> names});

/// [form] with copies of [controls] added last, so that they are drawn
/// above the others, and chosen by the names returned: on the form, or in
/// the Frame named [into] (D105). [controls] are as [copiedControls] gives
/// them: those in no Frame at the place they were seen on their form,
/// which here is from the corner of [into]; those in a Frame of the copy
/// go into the Frame's copy.
///
/// A copy keeps its name when the form has no control of that name, and
/// otherwise takes a new control's name (`Button2`), its `Caption` too
/// when that was its old name (D68), so that the code of the form, which
/// names the original, is not suddenly about the copy. The copies keep their
/// places to one another; while one would lie exactly where a control
/// starts, as when they are pasted back where they were copied from, they
/// all move a grid step down and right, and then into the form (or the
/// Frame) as far as they fit. A `Picture` that [hasPicture] says the
/// project does not have is left empty, so that the form file stays
/// valid (F016).
Pasted withPasted(
  FormFile form,
  List<ControlDecl> controls, {
  required bool Function(String picture) hasPicture,
  String? into,
}) {
  final origin = originOf(form, into);
  final starts = {
    for (final c in placedControls(form))
      (boxOn(form, c).left - origin.left, boxOn(form, c).top - origin.top),
  };
  final copied = {for (final c in controls) c.name.toLowerCase()};
  bool isRoot(ControlDecl c) =>
      c.container == null || !copied.contains(c.container!.toLowerCase());
  // A Timer has no place (D100): it is pasted without one.
  final placed = {
    for (final (i, c) in controls.indexed)
      if (c.component.visual && isRoot(c))
        '$i': shiftedBox(boxOf(c), origin, back: true),
  };
  var shift = 0;
  while (shift < 40 * gridStep &&
      placed.values.any(
        (b) => starts.contains((b.left + shift, b.top + shift)),
      )) {
    shift += gridStep;
  }
  final size = roomOf(form, into);
  final boxes = placed.isEmpty
      ? const <String, ControlBox>{}
      : movedTogether(
          placed,
          (bounds) => _inside((
            left: bounds.left + shift,
            top: bounds.top + shift,
            width: bounds.width,
            height: bounds.height,
          ), size),
        );
  var result = form;
  final names = <String>[];
  final renamed = <String, String>{};
  for (final (i, c) in controls.indexed) {
    final name = result.control(c.name) == null
        ? c.name
        : newControlName(result, c.component);
    renamed[c.name.toLowerCase()] = name;
    final box = boxes['$i'];
    result = _copy(result, [
      ...result.controls,
      ControlDecl(
        name: name,
        component: c.component,
        properties: {
          for (final MapEntry(:key, :value) in c.properties.entries)
            if (!(key == 'Picture' &&
                value is String &&
                value.isNotEmpty &&
                !hasPicture(value)))
              key: value,
          if (name != c.name &&
              c.component.properties.containsKey('caption') &&
              c.valueOf('Caption') == c.name)
            'Caption': name,
          if (box != null) ...{
            'Left': box.left,
            'Top': box.top,
            'Width': box.width,
            'Height': box.height,
          },
        },
        line: 0,
        container: isRoot(c) ? into : renamed[c.container!.toLowerCase()],
      ),
    ]);
    names.add(name);
  }
  return (form: result, names: names);
}

/// The pictures of [controls] that [hasPicture] says the project does not
/// have, which a paste leaves empty.
List<String> missingPictures(
  List<ControlDecl> controls, {
  required bool Function(String picture) hasPicture,
}) => [
  for (final c in controls)
    if (c.properties['Picture'] case final String p
        when p.isNotEmpty && !hasPicture(p))
      p,
];

/// Whether [box] and the rectangle from [a] to [b], drawn in any
/// direction, overlap: a rubber band chooses each control it touches, so
/// that a control needs not be wholly inside it.
bool touches(ControlBox box, Point<double> a, Point<double> b) {
  final left = min(a.x, b.x), right = max(a.x, b.x);
  final top = min(a.y, b.y), bottom = max(a.y, b.y);
  return box.left <= right &&
      box.left + box.width >= left &&
      box.top <= bottom &&
      box.top + box.height >= top;
}
