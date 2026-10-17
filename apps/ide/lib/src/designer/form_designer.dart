import 'dart:math';
import 'dart:ui' show PointMode;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import '../form_window.dart';
import '../project/open_project.dart';
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
/// read.
class FormDesigner extends StatefulWidget {
  const FormDesigner({
    super.key,
    required this.project,
    required this.file,
    required this.history,
    required this.grid,
    required this.locked,
    required this.strings,
  });

  final OpenProject project;

  /// The form file: `Form1.form.yaml`.
  final String file;
  final FormHistory history;

  /// Whether the grid is on; shared by all forms.
  final ValueNotifier<bool> grid;
  final bool locked;
  final IdeStrings strings;

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

  /// The mouse cursor over the form, from what is under the mouse.
  MouseCursor _cursor = MouseCursor.defer;

  /// Whether the form file's text is shown instead of the form.
  var _showText = false;

  // What was read from the file's text, kept until the text changes.
  String? _readText;
  late FormFileResult _read;
  late GbFormModel _model;

  /// Counts the models made, so that each one gets new widgets.
  var _modelVersion = 0;

  String get _text => widget.project.files[widget.file] ?? '';
  String get _formName =>
      widget.file.substring(0, widget.file.length - '.form.yaml'.length);

  FormFile get _form {
    final text = _text;
    if (text != _readText) {
      _readText = text;
      _read = readFormFile(text, name: _formName);
      // A new model each time, never changed: the designer only shows it.
      _model = formModelOf(_read.form, onEvent: (_, _) {});
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

  @override
  void initState() {
    super.initState();
    widget.history.follow(_text);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
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
  }

  void _delete() {
    final name = _selectedControl?.name;
    if (!_canEdit || name == null) return;
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

  // The mouse on the form.

  Point<double> _point(PointerEvent e) =>
      Point(e.localPosition.dx, e.localPosition.dy);

  void _down(PointerDownEvent e) {
    _focus.requestFocus();
    if (e.buttons & kPrimaryButton == 0) return;
    if (_tool != null && _canEdit) {
      setState(() => _dragStart = _dragEnd = _point(e));
      return;
    }
    final p = e.localPosition;
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
    final d = e.position - change.from;
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
    setState(() => _liveForm = size);
  }

  void _formUp(PointerUpEvent e) {
    final change = _formChange;
    final live = _liveForm;
    if (change == null) return;
    _endChange();
    if (live != null && live != change.start) {
      _apply(withFormSize(_form, live), select: _selected);
    } else {
      setState(() {});
    }
  }

  /// The control drawn at [p], the one on top where they overlap.
  ControlDecl? _controlAt(Offset p) {
    for (final c in _form.controls.reversed) {
      final b = boxOf(c);
      if (p.dx >= b.left &&
          p.dx < b.left + b.width &&
          p.dy >= b.top &&
          p.dy < b.top + b.height) {
        return c;
      }
    }
    return null;
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

  void _rename(String name, String newName) {
    if (!_canEdit) return;
    _apply(withName(_form, name, newName), select: newName);
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
        },
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
      listenable: widget.grid,
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
                      PropertiesPanel(
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
          const SizedBox(width: 4),
          IconButton(
            tooltip: '${s.undo} (${apple ? '⌘Z' : 'Ctrl+Z'})',
            icon: const Icon(Icons.undo),
            onPressed: editable && widget.history.canUndo ? _undo : null,
          ),
          IconButton(
            tooltip: '${s.redo} (${apple ? '⇧⌘Z' : 'Ctrl+Y'})',
            icon: const Icon(Icons.redo),
            onPressed: editable && widget.history.canRedo ? _redo : null,
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
          const Spacer(),
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
    ControlBox boxNow(ControlDecl c) =>
        _live != null && c.name == _change?.name ? _live! : boxOf(c);
    final area = SizedBox(
      key: designerFormKey,
      width: width,
      height: height,
      child: MouseRegion(
        cursor: _cursor,
        onHover: (e) => _hover(e.localPosition),
        onExit: (_) => setState(() => _cursor = MouseCursor.defer),
        child: Listener(
          behavior: HitTestBehavior.opaque,
          onPointerDown: _down,
          onPointerMove: _move,
          onPointerUp: _up,
          onPointerCancel: _cancel,
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
                    selected: selected == null ? null : boxNow(selected),
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
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Align(alignment: Alignment.topCenter, child: framed),
            ),
          ),
        ),
      ),
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
    required this.selected,
    required this.drawing,
    required this.color,
    required this.handleFill,
  });

  final List<ControlBox> edges;
  final Color edgeColor;
  final ControlBox? selected;
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
      old.selected != selected ||
      old.drawing != drawing ||
      old.color != color ||
      old.handleFill != handleFill;
}
