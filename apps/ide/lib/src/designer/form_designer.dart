import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import '../fit_view.dart';
import '../form_window.dart';
import '../project/open_project.dart';
import '../project/project_pictures.dart';
import '../strings.dart';
import '../theme.dart';
import 'form_edit.dart';
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

  /// The selected control's name; null for none.
  String? _selected;

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
        onEvent: (_, _) {},
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

  /// Writes [form] as the form file: one step of the history.
  void _apply(FormFile form, {String? select}) {
    final before = _text;
    final text = writeFormFile(form);
    widget.history.record(before, text);
    setState(() => _selected = select);
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

  /// Deletes the selected control. When the code uses it or has its
  /// handlers, asks first, naming the lines (D64).
  Future<void> _delete() async {
    final name = _selectedControl?.name;
    if (!_canEdit || name == null) return;
    final uses = usesOfControl(widget.project.files[_codeFile] ?? '', name);
    if (uses.lines.isNotEmpty || uses.handlers.isNotEmpty) {
      final s = widget.strings;
      final message = [
        if (uses.lines.isNotEmpty)
          s.deleteUsedControl
              .replaceAll('{0}', name)
              .replaceAll('{1}', _codeFile)
              .replaceAll('{2}', uses.lines.join(', ')),
        if (uses.handlers.isNotEmpty)
          s.deleteHandlersStay.replaceAll('{0}', uses.handlers.join(', ')),
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
      if (_form.control(name) == null) return;
    }
    _apply(withoutControl(_form, name));
  }

  void _escape() => setState(() {
    _tool = null;
    _selected = null;
    _dragStart = _dragEnd = null;
    _endChange();
  });

  /// Moves the selected control one step, [dx] and [dy] being -1, 0 or 1.
  void _nudge(int dx, int dy) =>
      _arrow((b) => nudgedBox(b, dx, dy, size: formSizeOf(_form), grid: _grid));

  /// Makes the selected control one step wider or narrower, taller or
  /// shorter.
  void _grow(int dx, int dy) =>
      _arrow((b) => grownBox(b, dx, dy, size: formSizeOf(_form), grid: _grid));

  void _arrow(ControlBox Function(ControlBox) change) {
    final c = _selectedControl;
    if (!_canEdit || c == null || _change != null) return;
    final box = change(boxOf(c));
    if (box != boxOf(c)) _apply(withBox(_form, c.name, box), select: c.name);
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
    _apply(
      withControl(form, type, name, centredBox(form, type, grid: _grid)),
      select: name,
    );
  }

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
    final name = newControlName(form, type);
    setState(() => _tool = null);
    _apply(
      withControl(
        form,
        type,
        name,
        drawnBox(form, type, start: at, end: at, grid: _grid),
      ),
      select: name,
    );
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
    if (_tool != null && _canEdit) {
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
          _change = (name: c.name, start: boxOf(c), handle: null, from: p);
        }
      });
      return;
    }
    final selected = _selectedControl;
    final handle = selected == null ? null : _handleAt(p, boxOf(selected));
    if (handle != null && _canEdit) {
      setState(
        () => _change = (
          name: selected!.name,
          start: boxOf(selected),
          handle: handle,
          from: p,
        ),
      );
      return;
    }
    final c = _controlAt(p);
    setState(() {
      _selected = c?.name;
      if (c != null && _canEdit) {
        _change = (name: c.name, start: boxOf(c), handle: null, from: p);
        _cursor = SystemMouseCursors.move;
      }
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
    final size = formSizeOf(_form);
    final box = switch (change.handle) {
      null => movedBox(change.start, d.dx, d.dy, size: size, grid: _grid),
      final h => resizedBox(
        change.start,
        h,
        d.dx,
        d.dy,
        size: size,
        grid: _grid,
      ),
    };
    if (box == _live) return;
    // The runtime's widget follows at once; the file changes at the end.
    _model.control(change.name)!
      ..set('Left', box.left)
      ..set('Top', box.top)
      ..set('Width', box.width)
      ..set('Height', box.height);
    setState(() => _live = box);
  }

  void _up(PointerUpEvent e) {
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
    final box = drawnBox(form, tool, start: start, end: _point(e), grid: _grid);
    _dragStart = _dragEnd = null;
    _tool = null;
    _apply(withControl(form, tool, name, box), select: name);
    _hover(e.localPosition);
  }

  void _cancel(PointerCancelEvent e) => setState(() {
    _dragStart = _dragEnd = null;
    _endChange();
  });

  /// Forgets a move or resize; the form is shown from its file again.
  void _endChange() {
    if (_live != null || _liveForm != null) _readText = null;
    _change = null;
    _live = null;
    _formChange = null;
    _liveForm = null;
  }

  /// Sets the cursor for the mouse at [p] on the form.
  void _hover(Offset p) {
    final selected = _selectedControl;
    final handle = selected == null ? null : _handleAt(p, boxOf(selected));
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
  /// draws them in (D41).
  List<ControlDecl> _controlsAt(Offset p) {
    final form = _form;
    return [
      for (final drawn in _model.drawingOrder.reversed)
        if (form.control(drawn.name!) case final c?)
          if (_contains(boxOf(c), p)) c,
    ];
  }

  static bool _contains(ControlBox b, Offset p) =>
      p.dx >= b.left &&
      p.dx < b.left + b.width &&
      p.dy >= b.top &&
      p.dy < b.top + b.height;

  /// Tab / Shift+Tab: the next or the previous control in the form file,
  /// round again at the end (D42).
  void _selectNext(int step) {
    final controls = _form.controls;
    if (controls.isEmpty) return;
    final i = controls.indexWhere((c) => c.name == _selected);
    final n = controls.length;
    final next = i < 0 ? (step > 0 ? 0 : n - 1) : (i + step + n) % n;
    setState(() => _selected = controls[next].name);
  }

  /// ⌘J / ⌘K, Ctrl+J / Ctrl+K: the selected control on top of the others
  /// of its layer, or under them (D42); one step of undo.
  void _order({required bool front}) {
    final name = _selectedControl?.name;
    if (!_canEdit || name == null) return;
    _apply(withOrder(_form, name, front: front), select: name);
  }

  /// The designer's context menu at [global], for what is at [local] on
  /// the form: a right click, a two-finger click, Control and a click on
  /// Apple systems, and later a long press on a touch screen. A control
  /// there is selected first. While a program runs only View Code works.
  Future<void> _contextMenu(Offset global, Offset local) async {
    final c = _controlAt(local);
    setState(() {
      _selected = c?.name;
      _change = null;
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
            enabled: editable,
          ),
        ] else ...[
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
    return drawnBox(_form, tool, start: start, end: end, grid: _grid);
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
    final text = writeFormFile(withProperty(_form, control, property, value));
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
        },
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
            Expanded(child: _canvas(context, form, editable)),
          ],
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
                    onPressed: editable && _selectedControl != null
                        ? () => _order(front: true)
                        : null,
                  ),
                  IconButton(
                    key: designerMenuKey('toolbar.back'),
                    tooltip: '${s.sendToBack} (${apple ? '⌘K' : 'Ctrl+K'})',
                    icon: const Icon(Icons.flip_to_back),
                    onPressed: editable && _selectedControl != null
                        ? () => _order(front: false)
                        : null,
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
    final selected = _selectedControl;
    // While the form's size is dragged, the controls are where their
    // Anchor puts them.
    final live = _liveForm == null
        ? null
        : anchoredBoxes(form, _liveForm!, _resizeBase);
    ControlBox boxNow(ControlDecl c) => _live != null && c.name == _change?.name
        ? _live!
        : live?[c.name.toLowerCase()] ?? boxOf(c);
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
                          for (final c in form.controls)
                            if (isOutside(boxNow(c), size)) boxNow(c),
                        ],
                        outsideColor: scheme.error,
                        selected: selected == null ? null : boxNow(selected),
                        anchorLines: selected == null
                            ? const []
                            : anchorLines(
                                boxNow(selected),
                                selected.valueOf('Anchor') as String,
                                size,
                              ),
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
    final frame = FormWindowFrame(
      caption: _model.form.text('Caption'),
      width: width,
      child: area,
    );
    // The form's handles sit on its right and bottom edges, half outside
    // the window; the padding lets the mouse take that half too.
    const reach = _MarksPainter.handleSize;
    Widget formHandle(Handle h, MouseCursor cursor) {
      final centre = Offset(
        h.x == 0 ? width / 2 : width,
        formTitleHeight + (h.y == 0 ? height / 2 : height),
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
    final natural = Size(width + reach, formTitleHeight + height + reach);
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

  /// The selected control, the control being drawn, or else the form:
  /// its name, type, place and size.
  Widget _status(BuildContext context, FormFile form) {
    String describe(String name, String type, ControlBox b) =>
        '$name ($type) · Left ${b.left}, Top ${b.top} · '
        '${b.width}×${b.height}';
    final drawing = _drawing;
    final selected = _selectedControl;
    final size = _liveForm ?? formSizeOf(form);
    final text = drawing != null
        ? describe(newControlName(form, _tool!), _tool!.name, drawing)
        : selected != null
        ? describe(
            selected.name,
            selected.component.name,
            _live ?? boxOf(selected),
          )
        : '${form.name} (Form) · ${size.width}×${size.height}';
    return Container(
      height: 24,
      alignment: Alignment.centerLeft,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Text(
        text,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

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
    for (final b in outside) {
      final r = _rect(b).intersect(form);
      if (r.width > 2 && r.height > 2) canvas.drawRect(r.deflate(1), red);
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
