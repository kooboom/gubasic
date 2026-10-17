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

class _Window extends StatelessWidget {
  const _Window({required this.session});

  final RunSession session;

  @override
  Widget build(BuildContext context) {
    final form = session.host.model.form;
    return ListenableBuilder(
      listenable: Listenable.merge([session, form]),
      builder: (context, _) => FormWindowFrame(
        caption: form.text('Caption'),
        width: form.integer('Width').toDouble(),
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
        child: session.formShown ? GbFormView(model: session.host.model) : null,
      ),
    );
  }
}
