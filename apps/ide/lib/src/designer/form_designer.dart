import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'package:gubasic_player/gubasic_player.dart';

import '../project/open_project.dart';
import '../strings.dart';
import '../theme.dart';
import 'control_icons.dart';
import 'form_edit.dart';
import 'menu_editor.dart';
import 'properties_panel.dart';
import 'toolbox.dart';

/// The key of the area the form is drawn in, for tests.
const designerFormKey = ValueKey('designer.form');

/// The form designer (D34): shows the form file [file] of [project] as
/// the run window will show it, and changes it with the toolbox, the
/// mouse and the keyboard. Each finished action writes the form file into
/// [project] (D31), and is one step of [history].
///
/// It only shows the form while [locked] (a program runs), or when the
/// form file has errors: writing it again would drop what could not be
/// The keys of the designer's context menu items and order buttons.
/// The bar above the designer about controls outside the form (D72), and
/// its button that brings them inside.
const designerOutsideKey = ValueKey('designer.outside');
const designerFitInsideKey = ValueKey('designer.outside.fit');

/// The tray under the form for the controls not seen on it (D100).
const designerTrayKey = ValueKey('designer.tray');

/// The status line's words while a drag is stopped at the form's edge.
const designerEdgeHintKey = ValueKey('designer.edgeHint');

/// The height of that bar, and of the strip above the form kept for it.
const outsideBarHeight = 40.0;

ValueKey<String> designerMenuKey(String item) =>
    ValueKey('designer.menu.$item');

/// read.
class FormDesigner extends StatefulWidget {
  const FormDesigner({
    super.key,
    required this.project,
    required this.file,
    required this.history,
    required this.grid,
    this.fit,
    required this.locked,
    required this.strings,
    this.onOpenHandler,
    this.onAddPicture,
  });

  final OpenProject project;

  /// The form file: `Form1.form.yaml`.
  final String file;
  final FormHistory history;

  /// Whether the grid is on; shared by all forms.
  final ValueNotifier<bool> grid;

  /// Whether a form larger than the designer is shrunk to fit (D66);
  /// shared by all forms. Null: never.
  final ValueNotifier<bool>? fit;
  final bool locked;
  final IdeStrings strings;

  /// A double-click on a control (or on the form: null) opens its default
  /// event's handler in the code editor (D38).
  final void Function(String? control)? onOpenHandler;

  /// Adds a picture to the project from the Properties window (D51): its
  /// name, or null when none was added.
  final Future<String?> Function()? onAddPicture;

  @override
  State<FormDesigner> createState() => _FormDesignerState();
}

class _FormDesignerState extends State<FormDesigner> {
  final _focus = FocusNode(debugLabel: 'designer');

  /// The control type being placed; null for the pointer.
  ComponentSpec? _tool;

  /// The chosen controls' names, as the form file spells them: none, one,
  /// or several, chosen with Shift or ⌘ (Ctrl) and a click, ⌘A (Ctrl+A),
  /// or a rubber band dragged over the form.
  List<String> _chosen = const [];

  /// The one chosen control's name; null for none, and for several.
  String? get _selected => _chosen.length == 1 ? _chosen.single : null;
  set _selected(String? name) => _chosen = name == null ? const [] : [name];

  bool _isChosen(String name) =>
      _chosen.any((n) => n.toLowerCase() == name.toLowerCase());

  /// The chosen controls that the form has, in its order.
  List<ControlDecl> get _chosenControls => [
    for (final c in _form.controls)
      if (_isChosen(c.name)) c,
  ];

  /// Those of them seen on the form, with a place: not its Timers (D100).
  List<ControlDecl> get _chosenPlaced => [
    for (final c in _chosenControls)
      if (c.component.visual) c,
  ];

  /// The one chosen control if it is seen on the form, for its frame and
  /// handles.
  ControlDecl? get _selectedPlaced => switch (_selectedControl) {
    final c? when c.component.visual => c,
    _ => null,
  };

  /// Several controls being moved with the mouse: their boxes when the
  /// drag started, and where it started; and where they are now, null
  /// until the drag goes far enough.
  ({Map<String, ControlBox> start, Offset from, String clicked})? _groupChange;
  Map<String, ControlBox>? _groupLive;

  /// A rubber band being dragged over the form, from where to where, and
  /// the controls chosen before it, which it adds to when Shift or ⌘ was
  /// held.
  ({Point<double> from, Point<double> to, List<String> before})? _band;

  /// Where a drag that draws a control started and is now.
  Point<double>? _dragStart;
  Point<double>? _dragEnd;

  /// A control being moved (no [handle]) or resized with the mouse: its
  /// box when the drag started, and where the drag started.
  ({String name, ControlBox start, Handle? handle, Offset from})? _change;

  /// Where that control is now; null until the drag goes far enough.
  ControlBox? _live;

  /// The form's size and where a drag of one of its handles started.
  ({({int width, int height}) start, Offset from, Handle handle})? _formChange;

  /// The form's size during that drag.
  ({int width, int height})? _liveForm;

  /// What the controls move from when the form changes size, and the form
  /// file's text it was last used for: kept while the text stays as the
  /// last size change left it, so that changing the size back puts every
  /// control back exactly (D59).
  AnchorBase? _anchorBase;
  String? _anchorText;

  /// The base for a size change now: the last one, or the form as it is
  /// when something else changed it since.
  AnchorBase get _resizeBase {
    if (_anchorBase == null || _anchorText != _text) {
      _anchorBase = anchorBaseOf(_form);
      _anchorText = _text;
    }
    return _anchorBase!;
  }

  /// Makes the form [size], moving the controls as their Anchor says
  /// (D57); one step of undo.
  void _resizeForm(({int width, int height}) size) {
    if (size == formSizeOf(_form)) return;
    _apply(withAnchoredSize(_form, size, _resizeBase), select: _selected);
    _anchorText = _text;
  }

  /// The mouse cursor over the form, from what is under the mouse.
  MouseCursor _cursor = MouseCursor.defer;

  /// Whether the form file's text is shown instead of the form.
  var _showText = false;

  // What was read from the file's text, kept until the text changes.
  String? _readText;
  int? _readPictures;
  late FormFileResult _read;
  late GbFormModel _model;

  /// Counts the models made, so that each one gets new widgets.
  var _modelVersion = 0;

  String get _text => widget.project.files[widget.file] ?? '';
  String get _formName =>
      widget.file.substring(0, widget.file.length - '.form.yaml'.length);

  FormFile get _form {
    final text = _text;
    final pictures = widget.project.picturesVersion;
    if (text != _readText || pictures != _readPictures) {
      _readText = text;
      _readPictures = pictures;
      _read = readFormFile(text, name: _formName);
      // A new model each time, never changed: the designer only shows it.
      _model = formModelOf(
        _read.form,
        // A menu item chosen in the menu bar opens its Click (D106).
        onEvent: (control, event) {
          if (control != null && event == 'Click') {
            widget.onOpenHandler?.call(control);
          }
        },
        designing: true,
        pictures: pictureSource(widget.project.pictures),
      );
      _modelVersion++;
      _showPreview();
    }
    return _read.form;
  }

  bool get _canEdit {
    _form;
    return !widget.locked && !_read.hasErrors;
  }

  bool get _grid => widget.grid.value;

  /// The scale the form is shown at: below 1 when it is shrunk to fit
  /// (D66). Set as the canvas is laid out.
  var _scale = 1.0;

  @override
  void initState() {
    super.initState();
    widget.history.follow(_text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
    widget.fit?.addListener(_fitChanged);
  }

  @override
  void didUpdateWidget(FormDesigner old) {
    super.didUpdateWidget(old);
    if (old.fit != widget.fit) {
      old.fit?.removeListener(_fitChanged);
      widget.fit?.addListener(_fitChanged);
    }
  }

  /// The canvas is laid out again for the new scale (D66).
  void _fitChanged() => setState(() {});

  @override
  void dispose() {
    widget.fit?.removeListener(_fitChanged);
    _focus.dispose();
    _propertiesNode.dispose();
    if (kIsWeb) BrowserContextMenu.enableContextMenu();
    super.dispose();
  }

  /// Writes [form] as the form file: one step of the history. [select]
  /// is then the one chosen control, or [choose] the chosen ones.
  void _apply(FormFile form, {String? select, List<String>? choose}) {
    final before = _text;
    final text = writeFormFile(form);
    widget.history.record(before, text);
    setState(() => _chosen = choose ?? [?select]);
    widget.project.setFile(widget.file, text);
  }

  void _undo() => _step(widget.history.undo);
  void _redo() => _step(widget.history.redo);

  void _step(String? Function() go) {
    if (!_canEdit) return;
    // From the toolbar while a field has the focus: the field shows the
    // value undo gives once it loses the focus.
    _focus.requestFocus();
    widget.history.follow(_text);
    final text = go();
    if (text == null) return;
    setState(() {});
    widget.project.setFile(widget.file, text);
    final code = widget.history.lastCode;
    final now = widget.project.files[_codeFile];
    if (code != null && now != null) {
      // The code as the step left it; if it was changed since, the names
      // in it are renamed again (D39).
      widget.project.setFile(
        _codeFile,
        now == code.before ? code.after : renameInCode(now, code.from, code.to),
      );
    }
  }

  /// Deletes the chosen controls. When the code uses one or has its
  /// handlers, asks first, naming the lines (D64).
  Future<void> _delete() async {
    // A Frame goes with the controls in it (D105).
    final names = withInside(_form, [for (final c in _chosenControls) c.name]);
    if (!_canEdit || names.isEmpty) return;
    final code = widget.project.files[_codeFile] ?? '';
    final s = widget.strings;
    final lines = <String>[];
    final handlers = <String>[];
    for (final name in names) {
      final uses = usesOfControl(code, name);
      if (uses.lines.isNotEmpty) {
        lines.add(
          s.deleteUsedControl
              .replaceAll('{0}', name)
              .replaceAll('{1}', _codeFile)
              .replaceAll('{2}', uses.lines.join(', ')),
        );
      }
      handlers.addAll(uses.handlers);
    }
    if (lines.isNotEmpty || handlers.isNotEmpty) {
      final message = [
        ...lines,
        if (handlers.isNotEmpty)
          s.deleteHandlersStay.replaceAll('{0}', handlers.join(', ')),
        s.deleteUndo.replaceAll('{0}', _isApple ? '⌘Z' : 'Ctrl+Z'),
      ].join('\n\n');
      final go = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: SizedBox(width: 420, child: Text(message)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(s.runtime.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(s.deleteControl),
            ),
          ],
        ),
      );
      if (go != true || !mounted) return;
      _focus.requestFocus();
      // The form may have changed while the dialog was open.
      if (names.any((n) => _form.control(n) == null)) return;
    }
    _apply(withoutControls(_form, names));
  }

  void _escape() => setState(() {
    _tool = null;
    _selected = null;
    _dragStart = _dragEnd = null;
    _band = null;
    _endChange();
  });

  /// Moves the selected control one step, [dx] and [dy] being -1, 0 or 1.
  void _nudge(int dx, int dy) => _arrow(
    (b, size) => nudgedBox(b, dx, dy, size: size, grid: _grid),
    together: true,
  );

  /// Makes the selected control one step wider or narrower, taller or
  /// shorter.
  void _grow(int dx, int dy) => _arrow(
    (b, size) => grownBox(b, dx, dy, size: size, grid: _grid),
    together: false,
  );

  /// Changes the box of each chosen control with [change]: as one box
  /// around them all when they move [together], so that they keep their
  /// places to one another and stop together at the form's edge; else
  /// each on its own.
  void _arrow(
    ControlBox Function(ControlBox box, ({int width, int height}) size)
    change, {
    required bool together,
  }) {
    final chosen = _chosenPlaced;
    if (!_canEdit || chosen.isEmpty || _change != null) return;
    if (_groupChange != null) return;
    final form = _form;
    // The controls in a chosen Frame move with it (D105).
    final moving = outermost(form, [for (final c in chosen) c.name]);
    final space = _space(moving);
    final boxes = {
      for (final n in moving)
        n: shiftedBox(boxOn(form, form.control(n)!), space.origin, back: true),
    };
    final changed = together
        ? movedTogether(boxes, (b) => change(b, space.size))
        : {for (final e in boxes.entries) e.key: change(e.value, space.size)};
    if (changed.entries.every((e) => boxes[e.key] == e.value)) return;
    _apply(
      withBoxes(form, {
        for (final e in changed.entries)
          e.key: shiftedBox(e.value, space.origin),
      }),
      choose: [for (final c in chosen) c.name],
    );
  }

  /// What the controls named [names] move in: their Frame when they are
  /// all in the same one, else the form (D105); where it starts on the
  /// form, and its size.
  ({({int left, int top}) origin, ({int width, int height}) size}) _space(
    Iterable<String> names,
  ) {
    final form = _form;
    final containers = {
      for (final n in names) form.control(n)?.container?.toLowerCase(),
    };
    final shared = containers.length == 1 ? containers.single : null;
    return (origin: originOf(form, shared), size: roomOf(form, shared));
  }

  ControlDecl? get _selectedControl =>
      _selected == null ? null : _form.control(_selected!);

  void _chooseTool(ComponentSpec? tool) {
    _focus.requestFocus();
    if (tool != null && !_canEdit) return;
    setState(() => _tool = tool);
  }

  /// Places a control of [type] in the middle of the form.
  void _placeInMiddle(ComponentSpec type) {
    _focus.requestFocus();
    if (!_canEdit) return;
    final form = _form;
    final name = newControlName(form, type);
    _tool = null;
    if (!type.visual) return _placeInTray(type);
    _apply(
      withControl(form, type, name, centredBox(form, type, grid: _grid)),
      select: name,
    );
  }

  /// A control not seen on the form, a Timer (D100): it goes into the tray
  /// under the form, chosen; one step of undo.
  void _placeInTray(ComponentSpec type) {
    final form = _form;
    final name = newControlName(form, type);
    setState(() => _tool = null);
    _apply(withControl(form, type, name, _noBox), select: name);
  }

  static const ControlBox _noBox = (left: 0, top: 0, width: 0, height: 0);

  /// The form's area, where a tool dragged from the toolbox is dropped.
  final _dropArea = GlobalKey();

  /// A tool dragged from the toolbox and dropped on the form: a control of
  /// its default size there, its top left corner where the pointer was
  /// (D69).
  void _drop(DragTargetDetails<ComponentSpec> details) {
    _focus.requestFocus();
    final area = _dropArea.currentContext?.findRenderObject();
    if (!_canEdit || area is! RenderBox) return;
    // Through the area's transform: on a form shrunk to fit, the point on
    // the form the user sees.
    final p = area.globalToLocal(details.offset);
    final at = Point(p.dx, p.dy);
    final form = _form;
    final type = details.data;
    if (!type.visual) return _placeInTray(type);
    final name = newControlName(form, type);
    setState(() => _tool = null);
    final drawn = _drawn(type, at, at);
    _apply(
      withControl(form, type, name, drawn.box, container: drawn.frame),
      select: name,
    );
  }

  /// The box of a control of [type] drawn from [start] to [end], where it
  /// is seen on the form: in the Frame where the drag started, and inside
  /// it as far as it fits, if there is one there (D105).
  ({String? frame, ControlBox box, ControlBox own}) _drawn(
    ComponentSpec type,
    Point<double> start,
    Point<double> end,
  ) {
    final form = _form;
    final frame = frameAt(form, start);
    final o = originOf(form, frame);
    Point<double> local(Point<double> p) => Point(p.x - o.left, p.y - o.top);
    final own = drawnBox(
      form,
      type,
      start: local(start),
      end: local(end),
      grid: _grid,
      room: roomOf(form, frame),
    );
    return (frame: frame, box: shiftedBox(own, o), own: own);
  }

  // The mouse on the form.

  Point<double> _point(PointerEvent e) =>
      Point(e.localPosition.dx, e.localPosition.dy);

  /// How far apart, at most, the two presses of a double-click are: a
  /// mouse stays where it is, unlike a finger (kDoubleTapSlop is 100).
  static const _doubleClickReach = 8.0;

  /// The last two presses: on which control ('' for the form) and where,
  /// so that a double-click opens code only when both were on the same
  /// control, at the same place.
  ({String target, Offset at})? _press, _pressBefore;

  void _down(PointerDownEvent e) {
    _focus.requestFocus();
    // The right button, a two-finger click, or Control and a click on
    // Apple systems: the context menu.
    final secondary =
        e.buttons & kSecondaryButton != 0 ||
        (_isApple &&
            e.buttons & kPrimaryButton != 0 &&
            HardwareKeyboard.instance.isControlPressed);
    if (secondary) {
      _contextMenu(e.position, e.localPosition);
      return;
    }
    if (e.buttons & kPrimaryButton == 0) return;
    _pressBefore = _press;
    _press = (
      target: _controlAt(e.localPosition)?.name ?? '',
      at: e.localPosition,
    );
    if (_tool case final tool? when _canEdit) {
      // A Timer goes into the tray wherever the form is clicked (D100).
      if (!tool.visual) return _placeInTray(tool);
      setState(() => _dragStart = _dragEnd = _point(e));
      return;
    }
    final p = e.localPosition;
    if (HardwareKeyboard.instance.isAltPressed) {
      // Option / Alt and a click: the control under the selected one
      // there, round again from the top (D42).
      final under = _controlsAt(p);
      final i = under.indexWhere((c) => c.name == _selected);
      final c = under.isEmpty ? null : under[(i + 1) % under.length];
      setState(() {
        _selected = c?.name;
        if (c != null && _canEdit) {
          _change = (
            name: c.name,
            start: boxOn(_form, c),
            handle: null,
            from: p,
          );
        }
      });
      return;
    }
    // Shift, or ⌘ (Ctrl elsewhere), and a click: the control joins the
    // chosen ones, or leaves them; on the form, a rubber band adds to them.
    final keys = HardwareKeyboard.instance;
    final adding =
        keys.isShiftPressed ||
        (_isApple ? keys.isMetaPressed : keys.isControlPressed);
    final c = _controlAt(p);
    if (adding) {
      setState(() {
        if (c == null) {
          _band = (from: _point(e), to: _point(e), before: List.of(_chosen));
        } else if (_isChosen(c.name)) {
          _chosen = [
            for (final n in _chosen)
              if (n.toLowerCase() != c.name.toLowerCase()) n,
          ];
        } else {
          _chosen = [..._chosen, c.name];
        }
      });
      return;
    }
    final selected = _selectedPlaced;
    final handle = selected == null
        ? null
        : _handleAt(p, boxOn(_form, selected));
    if (handle != null && _canEdit) {
      setState(
        () => _change = (
          name: selected!.name,
          start: boxOn(_form, selected),
          handle: handle,
          from: p,
        ),
      );
      return;
    }
    if (c != null && _chosen.length > 1 && _isChosen(c.name)) {
      // A drag on one of several chosen controls moves them all; a click
      // without a drag chooses that one alone.
      setState(() {
        _groupChange = (
          // The controls in a chosen Frame move with it (D105).
          start: {
            for (final n in outermost(_form, [
              for (final x in _chosenPlaced) x.name,
            ]))
              n: boxOn(_form, _form.control(n)!),
          },
          from: p,
          clicked: c.name,
        );
        if (_canEdit) _cursor = SystemMouseCursors.move;
      });
      return;
    }
    setState(() {
      _selected = c?.name;
      if (c != null && _canEdit) {
        _change = (name: c.name, start: boxOn(_form, c), handle: null, from: p);
        _cursor = SystemMouseCursors.move;
      }
      // A drag over the form chooses the controls it touches.
      if (c == null) _band = (from: _point(e), to: _point(e), before: const []);
    });
  }

  /// A double-click (Flutter's double tap, timed as the platform times
  /// it) on a control, or on the form, opens its handler.
  void _doubleClick() {
    final (a, b) = (_pressBefore, _press);
    if (_tool != null || a == null || b == null) return;
    // Option-clicks go down through the controls; they open nothing.
    if (HardwareKeyboard.instance.isAltPressed) return;
    if (a.target != b.target || (a.at - b.at).distance > _doubleClickReach) {
      return;
    }
    _endChange();
    widget.onOpenHandler?.call(b.target.isEmpty ? null : b.target);
  }

  void _move(PointerMoveEvent e) {
    if (_dragStart != null) {
      setState(() => _dragEnd = _point(e));
      return;
    }
    if (_band case final band?) {
      final to = _point(e);
      final before = {for (final n in band.before) n.toLowerCase()};
      // A click that moves a pixel or two draws no band.
      final small =
          (to.x - band.from.x).abs() < clickDistance &&
          (to.y - band.from.y).abs() < clickDistance;
      setState(() {
        _band = (from: band.from, to: to, before: band.before);
        _chosen = [
          ...band.before,
          if (!small)
            for (final c in placedControls(_form))
              if (!before.contains(c.name.toLowerCase()) &&
                  touches(boxOn(_form, c), band.from, to))
                c.name,
        ];
      });
      return;
    }
    if (_groupChange case final group?) {
      final d = e.localPosition - group.from;
      if (!_canEdit ||
          (_groupLive == null &&
              d.dx.abs() < clickDistance &&
              d.dy.abs() < clickDistance)) {
        return;
      }
      final space = _space(group.start.keys);
      final live = {
        for (final e in movedTogether(
          {
            for (final e in group.start.entries)
              e.key: shiftedBox(e.value, space.origin, back: true),
          },
          (b) => movedBox(b, d.dx, d.dy, size: space.size, grid: _grid),
        ).entries)
          e.key: shiftedBox(e.value, space.origin),
      };
      if (mapEquals(live, _groupLive)) return;
      // The runtime's widgets follow at once; the file changes at the end.
      live.forEach(_showLive);
      setState(() => _groupLive = live);
      return;
    }
    final change = _change;
    if (change == null) return;
    final d = e.localPosition - change.from;
    // A click that moves a pixel or two only selects.
    if (_live == null &&
        change.handle == null &&
        d.dx.abs() < clickDistance &&
        d.dy.abs() < clickDistance) {
      return;
    }
    // In its Frame, if it is in one: it stays in it (D105).
    final space = _space([change.name]);
    final size = space.size;
    final start = shiftedBox(change.start, space.origin, back: true);
    final box = shiftedBox(switch (change.handle) {
      null => movedBox(start, d.dx, d.dy, size: size, grid: _grid),
      final h => resizedBox(start, h, d.dx, d.dy, size: size, grid: _grid),
    }, space.origin);
    // Said in the status line while the form's edge stops it (D77).
    final pastEdge = dragPastEdge(
      start,
      change.handle,
      d.dx,
      d.dy,
      size: size,
      grid: _grid,
    );
    if (pastEdge != _pastEdge) setState(() => _pastEdge = pastEdge);
    if (box == _live) return;
    // The runtime's widget follows at once; the file changes at the end.
    _showLive(change.name, box);
    setState(() => _live = box);
  }

  /// Shows control [name] at [box] on the form while it is dragged: the
  /// runtime's widget is placed in its Frame, if it is in one (D105).
  void _showLive(String name, ControlBox box) {
    final form = _form;
    final own = shiftedBox(
      box,
      originOf(form, form.control(name)?.container),
      back: true,
    );
    _model.control(name)!
      ..set('Left', own.left)
      ..set('Top', own.top)
      ..set('Width', own.width)
      ..set('Height', own.height);
  }

  void _up(PointerUpEvent e) {
    if (_band != null) {
      setState(() => _band = null);
      return;
    }
    if (_groupChange case final group?) {
      final live = _groupLive;
      _endChange();
      if (live == null) {
        setState(() => _selected = group.clicked);
      } else if (!mapEquals(live, group.start)) {
        _apply(withBoxes(_form, live), choose: [...group.start.keys]);
      } else {
        setState(() {});
      }
      _hover(e.localPosition);
      return;
    }
    final change = _change;
    if (change != null) {
      final live = _live;
      _endChange();
      if (live != null && live != change.start) {
        _apply(withBox(_form, change.name, live), select: change.name);
      } else {
        setState(() {});
      }
      _hover(e.localPosition);
      return;
    }
    final start = _dragStart;
    final tool = _tool;
    if (start == null || tool == null) return;
    final form = _form;
    final name = newControlName(form, tool);
    final drawn = _drawn(tool, start, _point(e));
    _dragStart = _dragEnd = null;
    _tool = null;
    _apply(
      withControl(form, tool, name, drawn.box, container: drawn.frame),
      select: name,
    );
    _hover(e.localPosition);
  }

  void _cancel(PointerCancelEvent e) => setState(() {
    _dragStart = _dragEnd = null;
    _band = null;
    _endChange();
  });

  /// Whether the control being dragged is stopped at the form's edge.
  var _pastEdge = false;

  /// Forgets a move or resize; the form is shown from its file again.
  void _endChange() {
    _pastEdge = false;
    if (_live != null || _liveForm != null || _groupLive != null) {
      _readText = null;
    }
    _change = null;
    _live = null;
    _groupChange = null;
    _groupLive = null;
    _formChange = null;
    _liveForm = null;
  }

  /// Sets the cursor for the mouse at [p] on the form.
  void _hover(Offset p) {
    final selected = _selectedPlaced;
    final handle = selected == null
        ? null
        : _handleAt(p, boxOn(_form, selected));
    final cursor = !_canEdit
        ? MouseCursor.defer
        : _tool != null
        ? SystemMouseCursors.precise
        : handle != null
        ? _resizeCursor(handle)
        : _controlAt(p) != null
        ? SystemMouseCursors.move
        : MouseCursor.defer;
    if (cursor != _cursor) setState(() => _cursor = cursor);
  }

  /// The handle of [box] at [p], if any.
  static Handle? _handleAt(Offset p, ControlBox box) {
    for (final h in handles) {
      final c = _handleCentre(box, h);
      if ((p.dx - c.dx).abs() <= _handleReach &&
          (p.dy - c.dy).abs() <= _handleReach) {
        return h;
      }
    }
    return null;
  }

  /// How far from a handle's centre the mouse still takes it.
  static const _handleReach = 5.0;

  static Offset _handleCentre(ControlBox b, Handle h) => Offset(
    b.left + (h.x + 1) / 2 * b.width,
    b.top + (h.y + 1) / 2 * b.height,
  );

  // The form's own handles, at its right and bottom edges.

  void _formDown(Handle handle, PointerDownEvent e) {
    _focus.requestFocus();
    if (!_canEdit || e.buttons & kPrimaryButton == 0) return;
    setState(
      () => _formChange = (
        start: formSizeOf(_form),
        from: e.position,
        handle: handle,
      ),
    );
  }

  void _formMove(PointerMoveEvent e) {
    final change = _formChange;
    if (change == null) return;
    // The handle follows the pointer as the user sees the form.
    final d = (e.position - change.from) / _scale;
    final size = resizedForm(
      change.start,
      change.handle.x == 0 ? 0 : d.dx,
      change.handle.y == 0 ? 0 : d.dy,
      grid: _grid,
    );
    if (size == _liveForm) return;
    _model.form
      ..set('Width', size.width)
      ..set('Height', size.height);
    final boxes = anchoredBoxes(_form, size, _resizeBase);
    for (final c in _model.controls) {
      final b = boxes[c.name!.toLowerCase()]!;
      c
        ..set('Left', b.left)
        ..set('Top', b.top)
        ..set('Width', b.width)
        ..set('Height', b.height);
    }
    setState(() => _liveForm = size);
  }

  void _formUp(PointerUpEvent e) {
    final change = _formChange;
    final live = _liveForm;
    if (change == null) return;
    _endChange();
    if (live != null && live != change.start) {
      _resizeForm(live);
    } else {
      setState(() {});
    }
  }

  /// The control drawn at [p], the one on top where they overlap.
  ControlDecl? _controlAt(Offset p) => _controlsAt(p).firstOrNull;

  /// The controls drawn at [p], from the top down: the order the runtime
  /// draws them in (D41); in a Frame, the controls in it over the Frame,
  /// where the Frame is (D105).
  List<ControlDecl> _controlsAt(Offset p) {
    final form = _form;
    Iterable<ControlDecl> at(String? container) sync* {
      for (final drawn in _model.drawnIn(container).reversed) {
        final c = form.control(drawn.name!);
        if (c == null || !_contains(boxOn(form, c), p)) continue;
        if (c.component.container) yield* at(c.name);
        yield c;
      }
    }

    return at(null).toList();
  }

  static bool _contains(ControlBox b, Offset p) =>
      p.dx >= b.left &&
      p.dx < b.left + b.width &&
      p.dy >= b.top &&
      p.dy < b.top + b.height;

  /// Tab / Shift+Tab: the next or the previous control in the form file,
  /// round again at the end (D42).
  void _selectNext(int step) {
    final controls = designedControls(_form).toList();
    if (controls.isEmpty) return;
    final i = controls.indexWhere((c) => c.name == _selected);
    final n = controls.length;
    final next = i < 0 ? (step > 0 ? 0 : n - 1) : (i + step + n) % n;
    setState(() => _selected = controls[next].name);
  }

  /// ⌘E, Ctrl+E: the menu editor (D106); its menu bar is one step of
  /// undo.
  Future<void> _editMenus() async {
    if (!_canEdit) return;
    final rows = await showMenuEditor(context, _form, widget.strings);
    _focus.requestFocus();
    if (rows == null || !mounted || !_canEdit) return;
    final form = withMenuRows(_form, rows);
    if (writeFormFile(form) == _text) return;
    _apply(form, choose: _chosen);
  }

  /// ⌘J / ⌘K, Ctrl+J / Ctrl+K: the selected control on top of the others
  /// of its layer, or under them (D42); one step of undo.
  void _order({required bool front}) {
    final names = [for (final c in _chosenControls) c.name];
    if (!_canEdit || names.isEmpty) return;
    _apply(withOrderOf(_form, names, front: front), choose: names);
  }

  /// ⌘A, Ctrl+A: every control of the form.
  void _chooseAll() => setState(
    () => _chosen = [for (final c in designedControls(_form)) c.name],
  );

  /// ⌘C, Ctrl+C: the chosen controls go to the designer's clipboard, which
  /// any form of any project can take them from while the IDE runs.
  void _copy() {
    final chosen = _chosenControls;
    if (chosen.isEmpty) return;
    // A Frame with the controls in it (D105).
    _clipboard = copiedControls(_form, [for (final c in chosen) c.name]);
    setState(() {});
  }

  /// ⌘X, Ctrl+X: copies the chosen controls, then deletes them, asking
  /// first as Delete does when the code uses them.
  Future<void> _cut() async {
    if (!_canEdit || _chosenControls.isEmpty) return;
    _copy();
    await _delete();
  }

  /// ⌘V, Ctrl+V: copies of the clipboard's controls on top of the form,
  /// chosen; one step of undo. A picture the project does not have is left
  /// out, saying so.
  void _paste() {
    final copied = _clipboard;
    if (!_canEdit || copied == null || copied.isEmpty) return;
    final pictures = {
      for (final name in widget.project.pictures.keys) name.toLowerCase(),
    };
    bool has(String picture) => pictures.contains(picture.toLowerCase());
    // Into the one chosen Frame, if a Frame is chosen (D105).
    final frame = _selectedControl;
    final pasted = withPasted(
      _form,
      copied,
      hasPicture: has,
      into: frame != null && frame.component.container ? frame.name : null,
    );
    _apply(pasted.form, choose: pasted.names);
    final missing = missingPictures(copied, hasPicture: has);
    if (missing.isNotEmpty) {
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(
            widget.strings.pastedWithoutPicture.replaceAll(
              '{0}',
              missing.toSet().join(', '),
            ),
          ),
        ),
      );
    }
  }

  /// The designer's context menu at [global], for what is at [local] on
  /// the form: a right click, a two-finger click, Control and a click on
  /// Apple systems, and later a long press on a touch screen. A control
  /// there is selected first. While a program runs only View Code works.
  Future<void> _contextMenu(Offset global, Offset local) async {
    final c = _controlAt(local);
    setState(() {
      // A click on one of several chosen controls keeps them chosen.
      if (c == null || !_isChosen(c.name)) _selected = c?.name;
      _change = null;
      _groupChange = null;
      _band = null;
      _dragStart = _dragEnd = null;
    });
    final s = widget.strings;
    final editable = _canEdit;
    final apple = _isApple;
    String key(String k) => apple ? '⌘$k' : 'Ctrl+$k';
    PopupMenuItem<VoidCallback> item(
      Key id,
      String label,
      VoidCallback action, {
      bool enabled = true,
      String? shortcut,
    }) => PopupMenuItem(
      key: id,
      value: action,
      enabled: enabled,
      child: Row(
        children: [
          Expanded(child: Text(label)),
          if (shortcut != null)
            Padding(
              padding: const EdgeInsets.only(left: 24),
              child: Text(
                shortcut,
                style: TextStyle(color: Theme.of(context).hintColor),
              ),
            ),
        ],
      ),
    );
    final name = c?.name;
    final action = await showMenu<VoidCallback>(
      context: context,
      position: RelativeRect.fromLTRB(
        global.dx,
        global.dy,
        global.dx,
        global.dy,
      ),
      items: [
        item(
          designerMenuKey('viewCode'),
          s.viewCode,
          () => widget.onOpenHandler?.call(name),
        ),
        if (c != null) ...[
          const PopupMenuDivider(),
          item(
            designerMenuKey('cut'),
            s.cut,
            _cut,
            enabled: editable,
            shortcut: key('X'),
          ),
          item(designerMenuKey('copy'), s.copy, _copy, shortcut: key('C')),
          item(
            designerMenuKey('paste'),
            s.paste,
            _paste,
            enabled: editable && _clipboard != null,
            shortcut: key('V'),
          ),
          const PopupMenuDivider(),
          item(
            designerMenuKey('front'),
            s.bringToFront,
            () => _order(front: true),
            enabled: editable,
            shortcut: key('J'),
          ),
          item(
            designerMenuKey('back'),
            s.sendToBack,
            () => _order(front: false),
            enabled: editable,
            shortcut: key('K'),
          ),
          item(
            designerMenuKey('menus'),
            s.menuEditor,
            _editMenus,
            enabled: editable,
            shortcut: key('E'),
          ),
          const PopupMenuDivider(),
          item(
            designerMenuKey('delete'),
            s.delete,
            _delete,
            enabled: editable,
            shortcut: apple ? '⌫' : 'Delete',
          ),
          item(
            designerMenuKey('properties'),
            s.properties,
            _focusProperties,
            enabled: editable && _chosen.length == 1,
          ),
        ] else ...[
          const PopupMenuDivider(),
          item(
            designerMenuKey('paste'),
            s.paste,
            _paste,
            enabled: editable && _clipboard != null,
            shortcut: key('V'),
          ),
          item(
            designerMenuKey('selectAll'),
            s.selectAll,
            _chooseAll,
            enabled: designedControls(_form).isNotEmpty,
            shortcut: key('A'),
          ),
          const PopupMenuDivider(),
          CheckedPopupMenuItem(
            key: designerMenuKey('grid'),
            value: () => widget.grid.value = !widget.grid.value,
            enabled: editable,
            checked: _grid,
            child: Text(s.grid),
          ),
        ],
      ],
    );
    if (!mounted) return;
    if (action == null) {
      _focus.requestFocus();
      return;
    }
    action();
    if (!_propertiesAsked) _focus.requestFocus();
    _propertiesAsked = false;
  }

  /// The Properties window around its fields, to give the first one the
  /// focus.
  final _propertiesNode = FocusNode(skipTraversal: true);
  var _propertiesAsked = false;

  /// Properties in the context menu: the first field of the Properties
  /// window takes the focus, (Name) for a control.
  void _focusProperties() {
    _propertiesAsked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final n in _propertiesNode.traversalDescendants) {
        if (n.canRequestFocus &&
            n.context?.findAncestorWidgetOfExactType<TextField>() != null) {
          n.requestFocus();
          return;
        }
      }
    });
  }

  /// The box being drawn, as it will be placed.
  ControlBox? get _drawing {
    final (start, end, tool) = (_dragStart, _dragEnd, _tool);
    if (start == null || end == null || tool == null) return null;
    return _drawn(tool, start, end).box;
  }

  /// Sets a property from the Properties window: one step of undo for
  /// all the changes of the same [group].
  void _setProperty(
    String? control,
    String property,
    Object value,
    Object group,
  ) {
    if (!_canEdit) return;
    final before = _text;
    var form = withProperty(_form, control, property, value);
    if (value == true &&
        property == 'Checked' &&
        form.control(control ?? '')?.component.name == 'OptionButton') {
      // One OptionButton of the form, or of its Frame, is checked (D104,
      // D105).
      final frame = form.control(control!)!.container?.toLowerCase();
      for (final c in form.controls) {
        if (c.component.name == 'OptionButton' &&
            c.container?.toLowerCase() == frame &&
            c.name.toLowerCase() != control.toLowerCase() &&
            c.valueOf('Checked') == true) {
          form = withProperty(form, c.name, 'Checked', false);
        }
      }
    }
    final text = writeFormFile(form);
    widget.history.record(before, text, group: group);
    setState(() {});
    widget.project.setFile(widget.file, text);
  }

  /// The form's code file: `Form1.gbas` next to `Form1.form.yaml`.
  String get _codeFile => '$_formName.gbas';

  /// Renames a control, and its uses and handlers in the form's code with
  /// it (D39): one step of undo.
  void _rename(String name, String newName) {
    if (!_canEdit) return;
    final code = widget.project.files[_codeFile];
    final renamed = code == null ? null : renameInCode(code, name, newName);
    final before = _text;
    final text = writeFormFile(withName(_form, name, newName));
    widget.history.record(
      before,
      text,
      code: code == null || renamed == code
          ? null
          : (from: name, to: newName, before: code, after: renamed!),
    );
    setState(() => _selected = newName);
    widget.project.setFile(widget.file, text);
    if (renamed != null && renamed != code) {
      widget.project.setFile(_codeFile, renamed);
    }
  }

  /// Shows text being typed in the Properties window on the form at once,
  /// before the file has it (D35).
  void _preview(String? control, String property, String text) {
    _previewing = (control, property, text);
    _showPreview();
    setState(() {});
  }

  /// The text being typed in the Properties window, shown on the form.
  (String?, String, String)? _previewing;

  void _showPreview() {
    final (control, property, text) = _previewing ?? (null, '', '');
    if (_previewing == null) return;
    final state = control == null ? _model.form : _model.control(control);
    if (state != null && state[property] != text) state.set(property, text);
  }

  /// A field of the Properties window is done: one step of undo ends, and
  /// the form shows its file again, without what was only being typed.
  void _fieldDone() {
    widget.history.seal();
    if (_previewing != null) {
      _previewing = null;
      _readText = null;
      setState(() {});
    }
  }

  void _select(String? name) {
    setState(() => _selected = name);
    _focus.requestFocus();
  }

  @override
  Widget build(BuildContext context) {
    final form = _form;
    final s = widget.strings;
    final editable = _canEdit;
    // The designer's keys work while the form has the focus, never while
    // the user types in the Properties window: Backspace in an empty
    // field must not delete the control, and ⌘Z there undoes the text.
    final canvas = CallbackShortcuts(
      bindings: {
        if (editable) ...{
          const SingleActivator(LogicalKeyboardKey.delete): _delete,
          const SingleActivator(LogicalKeyboardKey.backspace): _delete,
          for (final a in _undoKeys) a: _undo,
          for (final a in _redoKeys) a: _redo,
          const ShortcutAt(PhysicalKeyboardKey.keyJ): () => _order(front: true),
          const ShortcutAt(PhysicalKeyboardKey.keyK): () =>
              _order(front: false),
          const ShortcutAt(PhysicalKeyboardKey.keyX): _cut,
          const ShortcutAt(PhysicalKeyboardKey.keyE): _editMenus,
          const ShortcutAt(PhysicalKeyboardKey.keyV): _paste,
        },
        const ShortcutAt(PhysicalKeyboardKey.keyC): _copy,
        const ShortcutAt(PhysicalKeyboardKey.keyA): _chooseAll,
        // Tab chooses controls while the form has the focus; in the
        // Properties window and the code editor it stays theirs.
        const SingleActivator(LogicalKeyboardKey.tab): () => _selectNext(1),
        const SingleActivator(LogicalKeyboardKey.tab, shift: true): () =>
            _selectNext(-1),
        // Taken even when nothing can change: otherwise Ctrl+arrow went on
        // to scroll whichever view the app chose.
        for (final (key, dx, dy) in _arrows) ...{
          SingleActivator(key, meta: _isApple, control: !_isApple): () =>
              _nudge(dx, dy),
          SingleActivator(key, shift: true): () => _grow(dx, dy),
        },
        const SingleActivator(LogicalKeyboardKey.escape): _escape,
      },
      // The Edit menu on macOS's menu bar sends these (D110); a field of
      // the Properties window, below, takes them first as text.
      child: Actions(
        actions: {
          UndoTextIntent: CallbackAction<UndoTextIntent>(
            onInvoke: (_) => editable ? _undo() : null,
          ),
          RedoTextIntent: CallbackAction<RedoTextIntent>(
            onInvoke: (_) => editable ? _redo() : null,
          ),
          CopySelectionTextIntent: CallbackAction<CopySelectionTextIntent>(
            onInvoke: (intent) =>
                intent.collapseSelection ? (editable ? _cut() : null) : _copy(),
          ),
          PasteTextIntent: CallbackAction<PasteTextIntent>(
            onInvoke: (_) => editable ? _paste() : null,
          ),
          SelectAllTextIntent: CallbackAction<SelectAllTextIntent>(
            onInvoke: (_) => _chooseAll(),
          ),
        },
        child: Focus(
          focusNode: _focus,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Toolbox(
                tool: _tool,
                enabled: editable,
                strings: s,
                onChoose: _chooseTool,
                onPlace: _placeInMiddle,
              ),
              const VerticalDivider(width: 1),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(child: _canvas(context, form, editable)),
                    ?_tray(context, form),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return ListenableBuilder(
      listenable: Listenable.merge([widget.grid, ?widget.fit]),
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _toolbar(context, editable),
          const Divider(height: 1),
          if (widget.locked)
            _banner(context, Icons.lock_outline, [s.lockedWhileRunning])
          else if (_read.hasErrors)
            _banner(context, Icons.error_outline, [
              s.formHasErrors,
              for (final d in _read.diagnostics)
                if (d.isError) s.problem(widget.file, d),
            ]),
          Expanded(
            child: _showText
                ? SingleChildScrollView(
                    padding: const EdgeInsets.all(12),
                    child: SelectableText(_text, style: codeStyle),
                  )
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: canvas),
                      const VerticalDivider(width: 1),
                      Focus(
                        focusNode: _propertiesNode,
                        canRequestFocus: false,
                        child: PropertiesPanel(
                          form: form,
                          selected: _selectedControl,
                          chosen: _chosen.length,
                          editable: editable,
                          strings: s,
                          onSelect: _select,
                          onChange: _setProperty,
                          onPreview: _preview,
                          onDone: _fieldDone,
                          onLeave: _focus.requestFocus,
                          code: widget.project.files[_codeFile] ?? '',
                          codeFile: _codeFile,
                          onRename: _rename,
                          pictures: widget.project.pictures.keys.toList(),
                          onAddPicture: widget.onAddPicture,
                        ),
                      ),
                    ],
                  ),
          ),
          const Divider(height: 1),
          _status(context, form),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, bool editable) {
    final s = widget.strings;
    final apple = _isApple;
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          // Scrolls when the designer is too narrow for all of it.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  const SizedBox(width: 4),
                  IconButton(
                    tooltip: '${s.undo} (${apple ? '⌘Z' : 'Ctrl+Z'})',
                    icon: const Icon(Icons.undo),
                    onPressed: editable && widget.history.canUndo
                        ? _undo
                        : null,
                  ),
                  IconButton(
                    tooltip: '${s.redo} (${apple ? '⇧⌘Z' : 'Ctrl+Y'})',
                    icon: const Icon(Icons.redo),
                    onPressed: editable && widget.history.canRedo
                        ? _redo
                        : null,
                  ),
                  const SizedBox(width: 8),
                  Tooltip(
                    message: s.gridTip,
                    child: FilterChip(
                      avatar: const Icon(Icons.grid_4x4, size: 18),
                      label: Text(s.grid),
                      selected: _grid,
                      showCheckmark: false,
                      onSelected: (on) {
                        widget.grid.value = on;
                        _focus.requestFocus();
                      },
                    ),
                  ),
                  if (widget.fit case final fit?) ...[
                    const SizedBox(width: 8),
                    Tooltip(
                      message: s.fitTip,
                      child: FilterChip(
                        key: designerMenuKey('toolbar.fit'),
                        avatar: const Icon(Icons.fit_screen, size: 18),
                        label: Text(s.fit),
                        selected: fit.value,
                        showCheckmark: false,
                        onSelected: (on) {
                          fit.value = on;
                          _focus.requestFocus();
                        },
                      ),
                    ),
                  ],
                  const SizedBox(width: 8),
                  _sizeMenu(context, editable),
                  IconButton(
                    key: designerMenuKey('toolbar.turn'),
                    tooltip: s.turnForm,
                    icon: const Icon(Icons.screen_rotation_alt),
                    onPressed: editable
                        ? () {
                            final size = formSizeOf(_form);
                            _resizeForm((
                              width: size.height,
                              height: size.width,
                            ));
                          }
                        : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: designerMenuKey('toolbar.front'),
                    tooltip: '${s.bringToFront} (${apple ? '⌘J' : 'Ctrl+J'})',
                    icon: const Icon(Icons.flip_to_front),
                    onPressed: editable && _chosenControls.isNotEmpty
                        ? () => _order(front: true)
                        : null,
                  ),
                  IconButton(
                    key: designerMenuKey('toolbar.back'),
                    tooltip: '${s.sendToBack} (${apple ? '⌘K' : 'Ctrl+K'})',
                    icon: const Icon(Icons.flip_to_back),
                    onPressed: editable && _chosenControls.isNotEmpty
                        ? () => _order(front: false)
                        : null,
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    key: designerMenuKey('toolbar.menus'),
                    tooltip: '${s.menuEditor} (${apple ? '⌘E' : 'Ctrl+E'})',
                    icon: const Icon(Icons.menu_open),
                    onPressed: editable ? _editMenus : null,
                  ),
                ],
              ),
            ),
          ),
          TextButton.icon(
            onPressed: () => setState(() {
              _showText = !_showText;
              _dragStart = _dragEnd = null;
            }),
            icon: Icon(_showText ? Icons.design_services : Icons.description),
            label: Text(_showText ? s.viewDesigner : s.viewFormFile),
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  /// The form size presets (D60): phone, tablet and desktop, each shown
  /// with its size; choosing one makes the form that size, upright, the
  /// controls moving as their Anchor says. The button names the preset
  /// the form is at, if any, upright or turned, and the form's size.
  Widget _sizeMenu(BuildContext context, bool editable) {
    final s = widget.strings;
    String name(FormSizePreset p) => switch (p) {
      FormSizePreset.phone => s.phonePreset,
      FormSizePreset.tablet => s.tabletPreset,
      FormSizePreset.desktop => s.desktopPreset,
    };
    final size = formSizeOf(_form);
    final now = presetOf(size);
    return MenuAnchor(
      menuChildren: [
        for (final p in formSizePresets)
          MenuItemButton(
            key: designerMenuKey('preset.${p.name.name}'),
            trailingIcon: Text('${p.width}×${p.height}'),
            onPressed: () {
              _resizeForm((width: p.width, height: p.height));
              _focus.requestFocus();
            },
            child: Text(name(p.name)),
          ),
      ],
      builder: (context, menu, _) => Tooltip(
        message: s.formSize,
        child: TextButton.icon(
          key: designerMenuKey('toolbar.size'),
          onPressed: editable
              ? () => menu.isOpen ? menu.close() : menu.open()
              : null,
          icon: const Icon(Icons.devices),
          label: Text(
            '${now == null ? '' : '${name(now.name)} · '}'
            '${size.width}×${size.height}',
          ),
        ),
      ),
    );
  }

  /// The controls that reach outside the form (D72): how many, their
  /// names (a click selects one, also one that cannot be seen), and a
  /// button that brings them all inside in one step of undo.
  Widget _outsideBanner(
    BuildContext context,
    List<ControlDecl> outside,
    bool editable,
  ) {
    final s = widget.strings;
    final scheme = Theme.of(context).colorScheme;
    final text = TextStyle(color: scheme.onErrorContainer);
    return Container(
      key: designerOutsideKey,
      height: outsideBarHeight,
      color: scheme.errorContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.warning_amber, size: 18, color: scheme.onErrorContainer),
          const SizedBox(width: 8),
          Text(
            outside.length == 1
                ? s.outsideOne
                : s.outsideMany.replaceAll('{0}', '${outside.length}'),
            style: text,
          ),
          // One line however many there are: the names scroll sideways.
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final c in outside)
                    TextButton(
                      key: ValueKey('designer.outside.${c.name}'),
                      onPressed: () {
                        _focus.requestFocus();
                        setState(() => _selected = c.name);
                      },
                      child: Text(
                        c.name,
                        style: text.copyWith(
                          decoration: TextDecoration.underline,
                          decorationColor: scheme.onErrorContainer,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Tooltip(
            message: s.fitInsideTip,
            child: OutlinedButton(
              key: designerFitInsideKey,
              onPressed: editable ? _fitInside : null,
              child: Text(s.fitInside),
            ),
          ),
        ],
      ),
    );
  }

  void _fitInside() {
    _focus.requestFocus();
    if (!_canEdit) return;
    _apply(withControlsInside(_form), select: _selected);
  }

  Widget _banner(BuildContext context, IconData icon, List<String> lines) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.secondaryContainer,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: scheme.onSecondaryContainer),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final l in lines)
                  Text(l, style: TextStyle(color: scheme.onSecondaryContainer)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _canvas(BuildContext context, FormFile form, bool editable) {
    final size = _liveForm ?? formSizeOf(form);
    final width = size.width.toDouble();
    final height = size.height.toDouble();
    final scheme = Theme.of(context).colorScheme;
    final selected = _selectedPlaced;
    // While the form's size is dragged, the controls are where their
    // Anchor puts them.
    final live = _liveForm == null
        ? null
        : boxesOn(form, anchoredBoxes(form, _liveForm!, _resizeBase));
    // Where each control is seen now: a control in a Frame moves with it
    // (D105).
    ControlBox boxNow(ControlDecl c) {
      if (_live != null && c.name == _change?.name) return _live!;
      if (_groupLive?[c.name] ?? live?[c.name.toLowerCase()] case final b?) {
        return b;
      }
      final frame = c.container == null ? null : form.control(c.container!);
      if (frame == null) return boxOf(c);
      final at = boxNow(frame);
      return shiftedBox(boxOf(c), (left: at.left, top: at.top));
    }

    // What the selected control's Anchor is to: its Frame's edges, or the
    // form's.
    final selectedFrame = selected?.container == null
        ? null
        : form.control(selected!.container!);
    final selectedRoom = selectedFrame == null
        ? (box: (left: 0, top: 0, width: size.width, height: size.height))
        : (box: boxNow(selectedFrame));
    final area = SizedBox(
      key: designerFormKey,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: _cursor,
        onHover: (e) => _hover(e.localPosition),
        // On the web, the right button opens the designer's menu here,
        // not the browser's.
        onEnter: (_) {
          if (kIsWeb) BrowserContextMenu.disableContextMenu();
        },
        onExit: (_) {
          if (kIsWeb) BrowserContextMenu.enableContextMenu();
          setState(() => _cursor = MouseCursor.defer);
        },
        child: DragTarget<ComponentSpec>(
          onWillAcceptWithDetails: (_) => _canEdit,
          onAcceptWithDetails: _drop,
          builder: (context, _, _) => Listener(
            key: _dropArea,
            behavior: HitTestBehavior.opaque,
            onPointerDown: _down,
            onPointerMove: _move,
            onPointerUp: _up,
            onPointerCancel: _cancel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onDoubleTap: _doubleClick,
              child: Stack(
                children: [
                  if (_grid)
                    Positioned.fill(
                      child: CustomPaint(
                        painter: _GridPainter(scheme.outlineVariant),
                      ),
                    ),
                  // Drawn by the runtime, as in the run window, but it takes
                  // no clicks, typing or focus.
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ExcludeFocus(
                        child: GbFormView(
                          key: ValueKey(_modelVersion),
                          model: _model,
                        ),
                      ),
                    ),
                  ),
                  Positioned.fill(
                    child: CustomPaint(
                      painter: _MarksPainter(
                        edges: [
                          for (final c in form.controls)
                            if (c.component.name == 'Label') boxNow(c),
                        ],
                        edgeColor: scheme.outline,
                        outside: [
                          for (final c in placedControls(form))
                            if (c.container == null &&
                                isOutside(boxNow(c), size))
                              boxNow(c),
                        ],
                        outsideColor: scheme.error,
                        selected: selected == null ? null : boxNow(selected),
                        chosen: _chosen.length > 1
                            ? [for (final c in _chosenPlaced) boxNow(c)]
                            : const [],
                        band: _band == null
                            ? null
                            : Rect.fromPoints(
                                Offset(_band!.from.x, _band!.from.y),
                                Offset(_band!.to.x, _band!.to.y),
                              ),
                        anchorLines: selected == null
                            ? const []
                            : [
                                for (final (a, b) in anchorLines(
                                  shiftedBox(boxNow(selected), (
                                    left: selectedRoom.box.left,
                                    top: selectedRoom.box.top,
                                  ), back: true),
                                  selected.valueOf('Anchor') as String,
                                  (
                                    width: selectedRoom.box.width,
                                    height: selectedRoom.box.height,
                                  ),
                                ))
                                  (
                                    a +
                                        Point(
                                          selectedRoom.box.left.toDouble(),
                                          selectedRoom.box.top.toDouble(),
                                        ),
                                    b +
                                        Point(
                                          selectedRoom.box.left.toDouble(),
                                          selectedRoom.box.top.toDouble(),
                                        ),
                                  ),
                              ],
                        drawing: _drawing,
                        color: scheme.primary,
                        handleFill: scheme.surface,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    // The menu bar as the window draws it, above the form (D106).
    final bar = _model.menuItems.isEmpty ? 0.0 : gbMenuBarHeight;
    final frame = FormWindowFrame(
      caption: _model.form.text('Caption'),
      width: width,
      child: bar == 0
          ? area
          : Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ExcludeFocus(child: GbMenuBar(model: _model)),
                area,
              ],
            ),
    );
    // The form's handles sit on its right and bottom edges, half outside
    // the window; the padding lets the mouse take that half too.
    const reach = _MarksPainter.handleSize;
    Widget formHandle(Handle h, MouseCursor cursor) {
      final centre = Offset(
        h.x == 0 ? width / 2 : width,
        formTitleHeight + bar + (h.y == 0 ? height / 2 : height),
      );
      return Positioned(
        key: ValueKey('designer.formHandle.${h.x}.${h.y}'),
        left: centre.dx - reach,
        top: centre.dy - reach,
        width: reach * 2,
        height: reach * 2,
        child: MouseRegion(
          cursor: editable ? cursor : MouseCursor.defer,
          child: Listener(
            behavior: HitTestBehavior.opaque,
            onPointerDown: (e) => _formDown(h, e),
            onPointerMove: _formMove,
            onPointerUp: _formUp,
            onPointerCancel: (_) => setState(_endChange),
            child: Center(
              child: Container(
                width: reach,
                height: reach,
                decoration: BoxDecoration(
                  color: scheme.surface,
                  border: Border.all(
                    color: editable ? scheme.outline : scheme.outlineVariant,
                  ),
                ),
              ),
            ),
          ),
        ),
      );
    }

    final framed = Stack(
      clipBehavior: Clip.none,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: reach, bottom: reach),
          child: frame,
        ),
        formHandle((x: 1, y: 0), SystemMouseCursors.resizeLeftRight),
        formHandle((x: 0, y: 1), SystemMouseCursors.resizeUpDown),
        formHandle((x: 1, y: 1), SystemMouseCursors.resizeUpLeftDownRight),
      ],
    );
    // The window with its handles, as it is laid out unshrunk.
    final natural = Size(width + reach, formTitleHeight + bar + height + reach);
    // The bar about controls outside the form (D72) lies over the canvas,
    // in a strip above the form kept free for it whether it shows or not:
    // so that it never moves the form, its scale or the Properties window,
    // and never covers the form or its handles (D75).
    final outside = _read.hasErrors
        ? const <ControlDecl>[]
        : controlsOutside(form);
    return LayoutBuilder(
      builder: (context, constraints) {
        const padding = 24.0;
        const top = outsideBarHeight + 8;
        _scale = widget.fit?.value ?? false
            ? fitScale(
                natural,
                Size(
                  max(0, constraints.maxWidth - 2 * padding),
                  max(0, constraints.maxHeight - top - padding),
                ),
              )
            : 1.0;
        return Stack(
          children: [
            Positioned.fill(
              child: SingleChildScrollView(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minWidth: constraints.maxWidth),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(
                        padding,
                        top,
                        padding,
                        padding,
                      ),
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: fitted(framed, natural, _scale),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (_scale < 1)
              Positioned(right: 8, bottom: 8, child: FitPercent(_scale)),
            if (outside.isNotEmpty)
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                child: _outsideBanner(context, outside, editable),
              ),
          ],
        );
      },
    );
  }

  /// The tray under the form (D100): the controls not seen on it, its
  /// Timers, each a chip that a click chooses and a double-click opens the
  /// handler of; null when there are none.
  Widget? _tray(BuildContext context, FormFile form) {
    final hidden = [
      for (final c in designedControls(form))
        if (!c.component.visual) c,
    ];
    if (hidden.isEmpty) return null;
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: designerTrayKey,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(top: BorderSide(color: scheme.outlineVariant)),
      ),
      padding: const EdgeInsets.all(8),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final c in hidden)
            _TrayChip(
              key: ValueKey('designer.tray.${c.name}'),
              name: c.name,
              icon: ControlIcon.of(c.component, size: 16),
              chosen: _isChosen(c.name),
              onTap: () {
                _focus.requestFocus();
                setState(() => _selected = c.name);
              },
              onDoubleTap: () => widget.onOpenHandler?.call(c.name),
            ),
        ],
      ),
    );
  }

  /// The selected control, the control being drawn, or else the form:
  /// its name, type, place and size.
  Widget _status(BuildContext context, FormFile form) {
    String describe(String name, String type, ControlBox b) =>
        '$name ($type) · Left ${b.left}, Top ${b.top} · '
        '${b.width}×${b.height}';
    // In a Frame, from its corner, as the Properties window says (D105).
    final (start, end, tool) = (_dragStart, _dragEnd, _tool);
    final drawing = start == null || end == null || tool == null
        ? null
        : _drawn(tool, start, end).own;
    final selected = _selectedControl;
    final size = _liveForm ?? formSizeOf(form);
    final text = drawing != null
        ? describe(newControlName(form, _tool!), _tool!.name, drawing)
        : _chosen.length > 1
        ? widget.strings.chosenControls.replaceAll(
            '{0}',
            '${_chosenControls.length}',
          )
        : selected != null && !selected.component.visual
        ? '${selected.name} (${selected.component.name})'
        : selected != null
        ? describe(
            selected.name,
            selected.component.name,
            _live == null
                ? boxOf(selected)
                : shiftedBox(
                    _live!,
                    originOf(form, selected.container),
                    back: true,
                  ),
          )
        : '${form.name} (Form) · ${size.width}×${size.height}';
    final theme = Theme.of(context);
    final edge = _pastEdge && _live != null;
    return Container(
      height: 24,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        edge ? widget.strings.stoppedAtEdge : text,
        key: edge ? designerEdgeHintKey : null,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.labelSmall?.copyWith(
          color: edge ? theme.colorScheme.error : null,
        ),
      ),
    );
  }
}

/// The controls last copied or cut in a designer, kept while the IDE runs,
/// to be pasted onto any form of any project.
List<ControlDecl>? _clipboard;

/// Empties the designer's clipboard, for tests.
@visibleForTesting
void clearDesignerClipboard() => _clipboard = null;

bool get _isApple => switch (defaultTargetPlatform) {
  TargetPlatform.macOS || TargetPlatform.iOS => true,
  _ => false,
};

/// The arrow keys and the way each one moves: (key, dx, dy).
const _arrows = [
  (LogicalKeyboardKey.arrowLeft, -1, 0),
  (LogicalKeyboardKey.arrowRight, 1, 0),
  (LogicalKeyboardKey.arrowUp, 0, -1),
  (LogicalKeyboardKey.arrowDown, 0, 1),
];

/// The cursor over [handle] of a control's frame.
MouseCursor _resizeCursor(Handle handle) => switch (handle) {
  (x: 0, y: _) => SystemMouseCursors.resizeUpDown,
  (x: _, y: 0) => SystemMouseCursors.resizeLeftRight,
  (x: final x, y: final y) when x == y =>
    SystemMouseCursors.resizeUpLeftDownRight,
  _ => SystemMouseCursors.resizeUpRightDownLeft,
};

/// ⌘Z on Apple systems, Ctrl+Z elsewhere.
List<SingleActivator> get _undoKeys => [
  SingleActivator(LogicalKeyboardKey.keyZ, meta: _isApple, control: !_isApple),
];

/// ⇧⌘Z on Apple systems; Ctrl+Y and Ctrl+Shift+Z elsewhere.
List<SingleActivator> get _redoKeys => _isApple
    ? const [SingleActivator(LogicalKeyboardKey.keyZ, meta: true, shift: true)]
    : const [
        SingleActivator(LogicalKeyboardKey.keyY, control: true),
        SingleActivator(LogicalKeyboardKey.keyZ, control: true, shift: true),
      ];

/// Dots on the grid.
class _GridPainter extends CustomPainter {
  _GridPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.square;
    final points = [
      for (var x = 0; x <= size.width; x += gridStep)
        for (var y = 0; y <= size.height; y += gridStep)
          Offset(x + 0.5, y + 0.5),
    ];
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  bool shouldRepaint(_GridPainter old) => old.color != color;
}

/// A dotted edge around each control that draws none itself (a Label,
/// which may even be empty), the selected control's frame and handles,
/// and the box being drawn.
class _MarksPainter extends CustomPainter {
  _MarksPainter({
    required this.edges,
    required this.edgeColor,
    required this.outside,
    required this.outsideColor,
    required this.selected,
    this.chosen = const [],
    this.band,
    required this.anchorLines,
    required this.drawing,
    required this.color,
    required this.handleFill,
  });

  final List<ControlBox> edges;
  final Color edgeColor;

  /// The controls that reach outside the form (D72): a red edge on the
  /// part of each that is inside.
  final List<ControlBox> outside;
  final Color outsideColor;
  final ControlBox? selected;

  /// Several chosen controls: a frame around each, without handles.
  final List<ControlBox> chosen;

  /// A rubber band being dragged over the form.
  final Rect? band;

  /// The selected control's Anchor: a dashed line from each edge it is
  /// anchored to out to the form's edge (D59).
  final List<(Point<double>, Point<double>)> anchorLines;
  final ControlBox? drawing;
  final Color color;
  final Color handleFill;

  static const handleSize = 7.0;

  static Rect _rect(ControlBox b) => Rect.fromLTWH(
    b.left.toDouble(),
    b.top.toDouble(),
    b.width.toDouble(),
    b.height.toDouble(),
  );

  /// Dots along the inside of [r], 2 pixels on, 2 off.
  static void _dotted(Canvas canvas, Rect r, Paint paint) {
    final points = <Offset>[];
    final (left, top) = (r.left + 0.5, r.top + 0.5);
    final (right, bottom) = (r.right - 0.5, r.bottom - 0.5);
    for (var x = left; x <= right; x += 4) {
      points.addAll([Offset(x, top), Offset(x, bottom)]);
    }
    for (var y = top; y <= bottom; y += 4) {
      points.addAll([Offset(left, y), Offset(right, y)]);
    }
    canvas.drawPoints(PointMode.points, points, paint);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final dots = Paint()
      ..color = edgeColor
      ..strokeWidth = 1;
    for (final b in edges) {
      _dotted(canvas, _rect(b), dots);
    }
    final red = Paint()
      ..color = outsideColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    final form = Offset.zero & size;
    final fill = Paint()..color = outsideColor;
    final formSize = (width: size.width.round(), height: size.height.round());
    for (final b in outside) {
      final r = _rect(b).intersect(form);
      if (r.width > 2 && r.height > 2) {
        canvas.drawRect(r.deflate(1), red);
      } else if (outsideMarker(b, formSize) case (:final at, :final towards)) {
        // Wholly outside: an arrow on the form's edge, pointing to it.
        final tip = Offset(at.x, at.y);
        final way = Offset(towards.x, towards.y);
        final back = tip - way * 12;
        final side = Offset(-way.dy, way.dx) * 7;
        canvas.drawPath(
          Path()
            ..moveTo(tip.dx, tip.dy)
            ..lineTo(back.dx + side.dx, back.dy + side.dy)
            ..lineTo(back.dx - side.dx, back.dy - side.dy)
            ..close(),
          fill,
        );
      }
    }
    final line = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    if (drawing case final b?) {
      final r = _rect(b);
      canvas
        ..drawRect(r, Paint()..color = color.withValues(alpha: 0.12))
        ..drawRect(r.deflate(0.5), line);
    }
    final dashes = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final (from, to) in anchorLines) {
      // 4 pixels on, 3 off, at the middle of a pixel.
      final length = from.distanceTo(to);
      final points = <Offset>[];
      for (var d = 0.0; d < length; d += 7) {
        for (var i = d; i < min(d + 4, length); i++) {
          final t = i / length;
          points.add(
            Offset(
              (from.x + (to.x - from.x) * t).floorToDouble() + 0.5,
              (from.y + (to.y - from.y) * t).floorToDouble() + 0.5,
            ),
          );
        }
      }
      canvas.drawPoints(PointMode.points, points, dashes);
    }
    for (final b in chosen) {
      canvas.drawRect(
        _rect(b).deflate(0.5),
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2,
      );
    }
    if (band case final r?) {
      canvas
        ..drawRect(r, Paint()..color = color.withValues(alpha: 0.08))
        ..drawRect(r, line);
    }
    if (selected case final b?) {
      final r = _rect(b);
      canvas.drawRect(r.deflate(0.5), line);
      final fill = Paint()..color = handleFill;
      for (final x in [r.left, r.center.dx, r.right]) {
        for (final y in [r.top, r.center.dy, r.bottom]) {
          if (x == r.center.dx && y == r.center.dy) continue;
          final h = Rect.fromCenter(
            center: Offset(x, y),
            width: handleSize,
            height: handleSize,
          );
          canvas
            ..drawRect(h, fill)
            ..drawRect(h, line);
        }
      }
    }
  }

  @override
  bool shouldRepaint(_MarksPainter old) =>
      !listEquals(old.edges, edges) ||
      old.edgeColor != edgeColor ||
      !listEquals(old.outside, outside) ||
      old.outsideColor != outsideColor ||
      old.selected != selected ||
      !listEquals(old.chosen, chosen) ||
      old.band != band ||
      !listEquals(old.anchorLines, anchorLines) ||
      old.drawing != drawing ||
      old.color != color ||
      old.handleFill != handleFill;
}

/// ⌘ and [key] on Apple systems, Ctrl and [key] elsewhere, by where the
/// key is on the keyboard: with a Korean input method on, Chrome on a Mac
/// reports Ctrl+K as ㅏ, which a shortcut by the letter does not match.
@visibleForTesting
class ShortcutAt extends ShortcutActivator {
  const ShortcutAt(this.key);

  final PhysicalKeyboardKey key;

  @override
  Iterable<LogicalKeyboardKey>? get triggers => null;

  @override
  bool accepts(KeyEvent event, HardwareKeyboard state) {
    if (event is KeyUpEvent || event.physicalKey != key) return false;
    final apple = _isApple;
    return state.isMetaPressed == apple &&
        state.isControlPressed == !apple &&
        !state.isAltPressed &&
        !state.isShiftPressed;
  }

  @override
  String debugDescribeKeys() =>
      '${_isApple ? 'Meta' : 'Control'}+${key.debugName}';
}

/// A control in the designer's tray (D100): its icon and name.
class _TrayChip extends StatelessWidget {
  const _TrayChip({
    super.key,
    required this.name,
    required this.icon,
    required this.chosen,
    required this.onTap,
    required this.onDoubleTap,
  });

  final String name;
  final Widget icon;
  final bool chosen;
  final VoidCallback onTap;
  final VoidCallback onDoubleTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Material(
      color: chosen ? scheme.primaryContainer : scheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: chosen ? scheme.primary : scheme.outline),
      ),
      child: InkWell(
        onTap: onTap,
        onDoubleTap: onDoubleTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [icon, const SizedBox(width: 6), Text(name)],
          ),
        ),
      ),
    );
  }
}
