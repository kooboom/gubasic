import 'package:flutter/material.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'fit_view.dart';
import 'run_session.dart';
import 'run_window.dart';

/// A running program as an exported app shows it (D84): the form alone,
/// with no window frame of its own (the browser's page, or the app's
/// window, is its frame) and no switch, centred at the top, and shrunk
/// when the page is smaller than the form. With several forms (D88), the
/// form in front that is not a dialog, and any dialog over it. The area
/// has its own navigator, so MsgBox and InputBox cover the form (D28).
/// Starts [session] once it is shown.
class AppView extends StatefulWidget {
  const AppView({super.key, required this.session});

  final RunSession session;

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
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

  Widget _page() {
    final session = widget.session;
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => ListenableBuilder(
        listenable: session.host.windowModel.form,
        builder: (context, _) => LayoutBuilder(
          builder: (context, constraints) {
            final model = session.host.windowModel;
            final form = model.form;
            final natural = Size(
              form.integer('Width').toDouble(),
              menuBarHeight(model) + form.integer('Height'),
            );
            final scale = fitScale(natural, constraints.biggest);
            return Stack(
              children: [
                Align(
                  alignment: Alignment.topCenter,
                  child: fitted(
                    SizedBox.fromSize(
                      size: natural,
                      // The form appears when Form_Load has finished.
                      child: session.formShown
                          ? withMenuBar(
                              model,
                              KeyedSubtree(
                                key: runFormKey(session.host.windowForm),
                                child: GbFormView(
                                  key: appFormKey,
                                  model: model,
                                ),
                              ),
                            )
                          : null,
                    ),
                    natural,
                    scale,
                  ),
                ),
                ...dialogLayers(context, session),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// The key of the form an [AppView] shows.
const appFormKey = ValueKey('app.form');
