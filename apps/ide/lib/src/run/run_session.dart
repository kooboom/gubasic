import 'package:flutter/foundation.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import '../project/project.dart';
import '../strings.dart';
import 'run_host.dart';

/// One run of a project's startup form: the interpreter, its [host], what
/// the program printed and how the run ended.
class RunSession extends ChangeNotifier {
  RunSession(this.startup, {required this.strings, RunHost? host})
    : host = host ?? RunHost(startup.form, strings: strings.runtime) {
    interpreter = Interpreter(
      startup.program,
      this.host,
      messages: strings.messages,
    );
    this.host
      ..interpreter = interpreter
      ..onDebugPrint = (line) {
        output.add(line);
        notifyListeners();
      }
      ..onShowForm = () {
        formShown = true;
        notifyListeners();
      };
  }

  final StartupForm startup;
  final IdeStrings strings;
  final RunHost host;
  late final Interpreter interpreter;

  /// `Debug.Print` lines.
  final output = <String>[];
  var formShown = false;
  var _started = false;

  /// How the run ended; null while it runs.
  RunResult? result;

  bool get isRunning => _started && result == null;

  /// Starts the program. The run window calls it once its navigator
  /// exists, so that a MsgBox in Form_Load has somewhere to open.
  void start() {
    if (_started) return;
    _started = true;
    interpreter.run().then((r) {
      result = r;
      notifyListeners();
    });
    notifyListeners();
  }

  /// The Stop button.
  void stop() => interpreter.stop();

  /// The user closes the form.
  void closeForm() => interpreter.closeForm();

  /// How the run ended, in words; null while it runs.
  String? get endMessage => switch (result) {
    null => null,
    RunCompleted() => strings.closed,
    RunEnded() => strings.ended,
    RunStopped() => strings.stopped,
    RunFailed(:final error) => strings.problem(startup.codeFile, error),
    RunNotStarted() => strings.cannotStart,
  };
}
