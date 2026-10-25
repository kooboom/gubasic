import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import '../form_window.dart';
import 'run_session.dart';

/// The key of the run window's close button.
const runWindowCloseKey = ValueKey('runWindow.close');

/// Where a running program is shown: the window with its form, centred
/// at the top of the area this widget fills. The area has its own
/// navigator, so MsgBox and InputBox cover the form and its close button
/// (D28) but not the IDE around it, whose Stop button keeps working.
/// Starts [session] once it is shown.
class RunWindow extends StatefulWidget {
  const RunWindow({super.key, required this.session});

  final RunSession session;

  @override
  State<RunWindow> createState() => _RunWindowState();
}

class _RunWindowState extends State<RunWindow> {
  final _navigator = GlobalKey<NavigatorState>();

  @override
  void initState() {
    super.initState();
    widget.session.host.dialogContext = () => _navigator.currentContext!;
    WidgetsBinding.instance.addPostFrameCallback((_) => widget.session.start());
  }

  @override
  Widget build(BuildContext context) => Navigator(
    key: _navigator,
    onGenerateRoute: (_) => PageRouteBuilder<void>(
      pageBuilder: (_, _, _) => SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Align(
          alignment: Alignment.topCenter,
          child: _Window(session: widget.session),
        ),
      ),
    ),
  );
}

/// The key of the run window's corner, which resizes the form (D59).
const runWindowResizeKey = ValueKey('runWindow.resize');

/// The smallest inside of a form the run window's corner makes.
const minRunFormSize = (width: 120, height: 24);

class _Window extends StatefulWidget {
  const _Window({required this.session});

  final RunSession session;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  GbFormModel get _model => widget.session.host.model;

  /// The size the form was drawn at, which a double-click on the title
  /// puts it back to: read when the window opens, before anything resizes
  /// it.
  late final ({int width, int height}) _drawn;

  @override
  void initState() {
    super.initState();
    _drawn = (
      width: _model.form.integer('Width'),
      height: _model.form.integer('Height'),
    );
  }

  /// The form's size when the corner was taken, and where.
  ({int width, int height})? _start;
  var _from = Offset.zero;

  void _dragStart(DragStartDetails d) {
    _start = (
      width: _model.form.integer('Width'),
      height: _model.form.integer('Height'),
    );
    _from = d.globalPosition;
  }

  void _drag(DragUpdateDetails d) {
    final start = _start;
    if (start == null) return;
    final dragged = d.globalPosition - _from;
    // The controls follow as the corner moves; Form_Resize runs once it
    // is let go (D58).
    _model.resize(
      max(minRunFormSize.width, (start.width + dragged.dx).round()),
      max(minRunFormSize.height, (start.height + dragged.dy).round()),
      raise: false,
    );
  }

  void _dragEnd() {
    final start = _start;
    _start = null;
    if (start == null) return;
    if (_model.form.integer('Width') != start.width ||
        _model.form.integer('Height') != start.height) {
      _model.raise(null, 'Resize');
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    final form = _model.form;
    const reach = 14.0;
    return ListenableBuilder(
      listenable: Listenable.merge([session, form]),
      builder: (context, _) => Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: reach, bottom: reach),
            child: FormWindowFrame(
              caption: form.text('Caption'),
              width: form.integer('Width').toDouble(),
              onTitleDoubleTap: session.formShown
                  ? () => _model.resize(_drawn.width, _drawn.height)
                  : null,
              trailing: IconButton(
                key: runWindowCloseKey,
                tooltip: session.strings.closeForm,
                iconSize: 18,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints.tightFor(
                  width: formTitleHeight,
                  height: formTitleHeight,
                ),
                icon: const Icon(Icons.close),
                onPressed: session.closeForm,
              ),
              // The form appears when Form_Load has finished.
              child: session.formShown ? GbFormView(model: _model) : null,
            ),
          ),
          // The corner, just outside the window's, resizes the form.
          if (session.formShown)
            Positioned(
              right: 0,
              bottom: 0,
              width: reach,
              height: reach,
              child: MouseRegion(
                cursor: SystemMouseCursors.resizeUpLeftDownRight,
                child: GestureDetector(
                  key: runWindowResizeKey,
                  behavior: HitTestBehavior.opaque,
                  // The corner follows the pointer from where it was
                  // taken, not from where the drag was recognised.
                  dragStartBehavior: DragStartBehavior.down,
                  onPanStart: _dragStart,
                  onPanUpdate: _drag,
                  onPanEnd: (_) => _dragEnd(),
                  onPanCancel: _dragEnd,
                  child: CustomPaint(
                    painter: _GripPainter(
                      Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Three short slanted lines, as a window's resizing corner shows.
class _GripPainter extends CustomPainter {
  _GripPainter(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..strokeWidth = 1;
    for (final d in [4.0, 8.0, 12.0]) {
      canvas.drawLine(
        Offset(size.width - d, size.height - 1),
        Offset(size.width - 1, size.height - d),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_GripPainter old) => old.color != color;
}
