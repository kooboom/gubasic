import 'package:flutter/widgets.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'bench/probe.dart';
import 'form_window.dart';

/// Connects the interpreter to gubasic_runtime (docs/DESIGN.md §2.3): the
/// form's properties live in [model], which the run window shows, and
/// MsgBox and InputBox are [dialogs]. What the user does on the form goes
/// to the interpreter as events.
class RunHost implements FormHost {
  RunHost(
    FormFile form, {
    GbStrings strings = GbStrings.en,
    this.project = '',
    String? settingsKey,
    this._settings,
    GbPictureSource? pictures,
  }) : settingsKey = settingsKey ?? project,
       dialogs = GbDialogs(strings: strings) {
    model = formModelOf(
      form,
      onEvent: _onEvent,
      accepts: _accepts,
      pictures: pictures,
    );
  }

  late final GbFormModel model;
  final GbDialogs dialogs;

  /// The project's name, shown in a dialog with no title (D68).
  final String project;

  /// What the program's settings are kept under (D48): the project's name
  /// in the IDE, the app ID in an exported app, so that two apps on one
  /// web site, or two apps of the same name, keep theirs apart (D83).
  final String settingsKey;

  /// Where the program's settings are kept; shared_preferences unless
  /// given, made only when the program uses them.
  GbSettingsStore? _settings;
  GbSettingsStore get settings => _settings ??= GbPreferencesSettings();

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

  /// A CheckBox asks before a click changes it (D44).
  bool _accepts(String? control, String event) {
    final refused = interpreter.refusal(control, event);
    if (refused != null) lastOutcome = refused;
    return refused == null;
  }

  BuildContext get _context =>
      dialogContext?.call() ?? (throw StateError('no run window'));

  @override
  void debugPrint(String line) => onDebugPrint?.call(line);

  @override
  Future<void> msgBox(String prompt, String title) =>
      dialogs.msgBox(_context, prompt, _title(title));

  @override
  Future<String> inputBox(String prompt, String title, String defaultValue) =>
      dialogs.inputBox(_context, prompt, _title(title), defaultValue);

  /// A dialog's title: the one given, or the project's name, as Visual
  /// Basic puts the application's name there (D68).
  String _title(String title) => title.isEmpty ? project : title;

  /// Lets frames be drawn and the Stop button work.
  @override
  Future<void> yieldNow() async {
    // Measuring builds only (STAGE2_PLAN §7); compiled away elsewhere.
    if (benchEnabled) BenchProbe.current?.yieldStarted();
    await Future<void>.delayed(Duration.zero);
    if (benchEnabled) BenchProbe.current?.yieldEnded();
  }

  @override
  Object getProperty(String? control, String property) =>
      model.control(control)![property];

  @override
  void setProperty(String? control, String property, Object value) =>
      model.setProperty(control, property, value);

  @override
  Future<String?> loadSettings() => settings.load(settingsKey);

  @override
  Future<void> saveSettings(String text) => settings.save(settingsKey, text);

  @override
  void showForm() => onShowForm?.call();

  @override
  void endProgram() => dialogs.closeAll();
}
