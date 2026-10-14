import 'package:gubasic_lang/gubasic_lang.dart';

import '../model/i18n.dart';
import '../model/run_state.dart';
import '../model/snapshot.dart';
import 'dialog.dart';

/// Runs the program shown in the editor and keeps the Run tab's state.
class RunController {
  RunController({required this.onStatus, required this.onOutput});

  final RunState state = RunState();

  /// Called when the status changes (the Run tab is redrawn).
  final void Function() onStatus;

  /// Called for each new output line (appended without a full redraw).
  final void Function(OutputEntry entry) onOutput;

  Interpreter? _interpreter;
  Locale _locale = Locale.en;

  bool get isRunning => state.isRunning;

  Future<void> run(Snapshot snapshot, Locale locale) async {
    if (isRunning || snapshot.compileResult.hasErrors) return;
    _locale = locale;
    state
      ..output.clear()
      ..status = RunStatus.running;
    onStatus();
    final interpreter = _interpreter = Interpreter(
        snapshot.compileResult, _PlaygroundHost(this),
        messages: locale.diagnosticMessages);
    final result = await interpreter.run();
    if (_interpreter != interpreter) return; // replaced by a newer run
    _interpreter = null;
    _openDialog?.cancel();
    state.finish(result);
    if (result is RunFailed) onOutput(state.output.last);
    onStatus();
  }

  /// Stops a running program at its next yield (I5: also when the code is
  /// edited).
  void stop() {
    _interpreter?.stop();
    // A program waiting in MsgBox / InputBox reaches its stop once the
    // dialog is closed.
    _openDialog?.cancel();
  }

  DialogHandle? _openDialog;

  void _print(String line) {
    final entry = PrintedLine(line);
    state.output.add(entry);
    onOutput(entry);
  }
}

class _PlaygroundHost implements Host {
  _PlaygroundHost(this._run);

  final RunController _run;

  @override
  void debugPrint(String line) => _run._print(line);

  @override
  Future<void> msgBox(String prompt, String title) async {
    await _dialog(title, prompt, withInput: false);
  }

  @override
  Future<String> inputBox(
      String prompt, String title, String defaultValue) async {
    return await _dialog(title, prompt,
            withInput: true, defaultValue: defaultValue) ??
        ''; // Cancel gives "".
  }

  Future<String?> _dialog(String title, String message,
      {required bool withInput, String defaultValue = ''}) async {
    final dialog = _run._openDialog = showDialog(
      locale: _run._locale,
      title: title,
      message: message,
      withInput: withInput,
      defaultValue: defaultValue,
    );
    final answer = await dialog.answer;
    _run._openDialog = null;
    return answer;
  }

  /// Gives the browser a turn (paint, clicks on Stop). A timer, not a
  /// microtask, so that events can run.
  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);
}
