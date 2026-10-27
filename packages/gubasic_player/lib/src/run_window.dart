import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart' show ShownForm;
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'fit_view.dart';
import 'form_window.dart';
import 'run_session.dart';

/// The key of the run window's close button.
const runWindowCloseKey = ValueKey('runWindow.close');

/// The key of the view of form [name] in the run window or an app (D88).
ValueKey<String> runFormKey(String name) =>
    ValueKey('run.form.${name.toLowerCase()}');

/// Of the forms shown (D88), the one drawn as the window's, or the page's:
/// the frontmost that is not a dialog; and the dialogs shown over it.
({ShownForm? base, List<ShownForm> dialogs}) formLayers(List<ShownForm> shown) {
  final i = shown.lastIndexWhere((f) => !f.dialog);
  return (
    base: i < 0 ? null : shown[i],
    dialogs: shown.sublist(i < 0 ? 0 : i + 1),
  );
}

/// The forms shown as dialogs over the window or the page (D88): each
/// over a dim barrier that takes the clicks meant for what is behind,
/// centred, shrunk when larger than the area. A dialog has no close
/// button: its code closes it.
List<Widget> dialogLayers(BuildContext context, RunSession session) {
  final scrim = Theme.of(context).colorScheme.scrim.withValues(alpha: 0.32);
  return [
    for (final dialog in formLayers(session.host.shown).dialogs) ...[
      ModalBarrier(color: scrim, dismissible: false),
      LayoutBuilder(
        builder: (context, constraints) {
          final model = session.host.modelOf(dialog.name);
          return ListenableBuilder(
            listenable: model.form,
            builder: (context, _) {
              final natural = Size(
                model.form.integer('Width').toDouble(),
                formTitleHeight + model.form.integer('Height'),
              );
              final scale = fitScale(natural, inside(constraints, 16));
              return Center(
                child: fitted(
                  FormWindowFrame(
                    caption: model.form.text('Caption'),
                    width: natural.width,
                    child: GbFormView(
                      key: runFormKey(dialog.name),
                      model: model,
                    ),
                  ),
                  natural,
                  scale,
                ),
              );
            },
          );
        },
      ),
    ],
  ];
}

/// Where a running program is shown: the window with its form, centred
/// at the top of the area this widget fills. The area has its own
/// navigator, so MsgBox and InputBox cover the form and its close button
/// (D28) but not the IDE around it, whose Stop button keeps working.
/// Starts [session] once it is shown.
class RunWindow extends StatefulWidget {
  const RunWindow({super.key, required this.session, this.fit});

  final RunSession session;

  /// Whether a form larger than the area is shrunk to fit (D66), kept
  /// from run to run. Null: never, and no switch.
  final ValueNotifier<bool>? fit;

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
    onGenerateRoute: (_) =>
        PageRouteBuilder<void>(pageBuilder: (_, _, _) => _page()),
  );

  /// The window, shrunk to fit when [RunWindow.fit] is on and it is too
  /// large, and the switch for it.
  Widget _page() {
    final fit = widget.fit;
    final session = widget.session;
    const padding = 24.0;
    return ListenableBuilder(
      listenable: Listenable.merge([session, ?fit]),
      builder: (context, _) => ListenableBuilder(
        listenable: session.host.windowModel.form,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final form = session.host.windowModel.form;
            final natural = Size(
              form.integer('Width') + _cornerReach,
              formTitleHeight + form.integer('Height') + _cornerReach,
            );
            final scale = fit?.value ?? false
                ? fitScale(natural, inside(constraints, padding))
                : 1.0;
            return Stack(
              children: [
                Positioned.fill(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(padding),
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: fitted(
                        _Window(
                          // Another form in front: a window of its own.
                          key: ObjectKey(session.host.windowModel),
                          session: session,
                          scale: scale,
                        ),
                        natural,
                        scale,
                      ),
                    ),
                  ),
                ),
                if (fit != null)
                  Positioned(
                    top: 4,
                    right: 4,
                    child: IconButton(
                      key: runWindowFitKey,
                      tooltip: widget.session.strings.fitTip,
                      isSelected: fit.value,
                      icon: const Icon(Icons.fit_screen),
                      onPressed: () => fit.value = !fit.value,
                    ),
                  ),
                if (scale < 1)
                  Positioned(right: 8, bottom: 8, child: FitPercent(scale)),
                ...dialogLayers(context, session),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The key of the run window's switch that shrinks a large form to fit.
const runWindowFitKey = ValueKey('runWindow.fit');

/// The run window's corner, outside its window's.
const _cornerReach = 14.0;

/// The key of the run window's corner, which resizes the form (D59).
const runWindowResizeKey = ValueKey('runWindow.resize');

/// The smallest inside of a form the run window's corner makes.
const minRunFormSize = (width: 120, height: 24);

class _Window extends StatefulWidget {
  const _Window({super.key, required this.session, this.scale = 1});

  final RunSession session;

  /// The scale the window is shown at (D66): the corner follows the
  /// pointer as the user sees it.
  final double scale;

  @override
  State<_Window> createState() => _WindowState();
}

class _WindowState extends State<_Window> {
  /// The model of the form in front that is not a dialog (D88).
  GbFormModel get _model => widget.session.host.windowModel;

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
    final dragged = (d.globalPosition - _from) / widget.scale;
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
    const reach = _cornerReach;
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
              child: session.formShown
                  ? GbFormView(
                      key: runFormKey(session.host.windowForm),
                      model: _model,
                    )
                  : null,
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
