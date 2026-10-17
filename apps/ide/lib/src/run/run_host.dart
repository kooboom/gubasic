import 'package:flutter/widgets.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import '../form_window.dart';

/// Connects the interpreter to gubasic_runtime (docs/DESIGN.md §2.3): the
/// form's properties live in [model], which the run window shows, and
/// MsgBox and InputBox are [dialogs]. What the user does on the form goes
/// to the interpreter as events.
class RunHost implements FormHost {
  RunHost(FormFile form, {GbStrings strings = GbStrings.en})
    : dialogs = GbDialogs(strings: strings) {
    model = formModelOf(form, onEvent: _onEvent);
  }

  late final GbFormModel model;
  final GbDialogs dialogs;

  /// Set before the program starts.
  late final Interpreter interpreter;

  /// Where dialogs open: the run window's own navigator, so that a dialog
  /// blocks the form but not the IDE's Stop button. Set by the run window.
  BuildContext Function()? dialogContext;

  /// Called for each `Debug.Print` line.
  void Function(String line)? onDebugPrint;

  /// Called when Form_Load has finished and the form is shown.
  VoidCallback? onShowForm;

  /// What the interpreter did with the last event the user caused; tests
  /// read it.
  EventOutcome? lastOutcome;

  void _onEvent(String? control, String event) =>
      lastOutcome = interpreter.raiseEvent(control, event);

  BuildContext get _context =>
      dialogContext?.call() ?? (throw StateError('no run window'));

  @override
  void debugPrint(String line) => onDebugPrint?.call(line);

  @override
  Future<void> msgBox(String prompt, String title) =>
      dialogs.msgBox(_context, prompt, title);

  @override
  Future<String> inputBox(String prompt, String title, String defaultValue) =>
      dialogs.inputBox(_context, prompt, title, defaultValue);

  /// Lets frames be drawn and the Stop button work.
  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);

  @override
  Object getProperty(String? control, String property) =>
      model.control(control)![property];

  @override
  void setProperty(String? control, String property, Object value) =>
      model.control(control)!.set(property, value);

  @override
  void showForm() => onShowForm?.call();

  @override
  void endProgram() => dialogs.closeAll();
}
