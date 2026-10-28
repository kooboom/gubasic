import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'bench/probe.dart';
import 'form_window.dart';

/// Connects the interpreter to gubasic_runtime (docs/DESIGN.md §2.3): each
/// form's properties live in a model ([modelOf]), which the run window
/// shows, and MsgBox and InputBox are [dialogs]. What the user does on a
/// form goes to the interpreter as events.
class RunHost implements FormHost {
  /// [form] is the startup form, [others] the project's other forms (D88).
  RunHost(
    FormFile form, {
    List<FormFile> others = const [],
    GbStrings strings = GbStrings.en,
    this.project = '',
    String? settingsKey,
    this._settings,
    this._pictures,
  }) : settingsKey = settingsKey ?? project,
       dialogs = GbDialogs(strings: strings),
       _startup = form.name {
    for (final f in [form, ...others]) {
      _files[f.name.toLowerCase()] = f;
      _models[f.name.toLowerCase()] = _modelOf(f);
      _timers[f.name.toLowerCase()] = _timersOf(f);
    }
  }

  /// Each form's Timers (D100), by lower-case form and Timer name: the
  /// Timer's name and its properties. They have no widget.
  final _timers = <String, Map<String, (String, Map<String, Object>)>>{};

  /// The clock of each Timer that is Enabled while the program runs, by
  /// lower-case `form.timer`.
  final _clocks = <String, Timer>{};

  /// Whether the clocks run: from the first form shown until the end.
  var _ticking = false;

  static Map<String, (String, Map<String, Object>)> _timersOf(FormFile f) => {
    for (final c in f.controls)
      if (!c.component.visual)
        c.name.toLowerCase(): (
          c.name,
          {
            for (final p in c.component.properties.values)
              if (p.isStored) p.name: c.valueOf(p.name),
          },
        ),
  };

  /// Starts, restarts or stops [timer]'s clock on [form], for its Enabled
  /// and Interval now.
  void _clock(String form, String timer) {
    final key = '${form.toLowerCase()}.${timer.toLowerCase()}';
    _clocks.remove(key)?.cancel();
    final (name, properties) =
        _timers[form.toLowerCase()]![timer.toLowerCase()]!;
    if (!_ticking || properties['Enabled'] != true) return;
    _clocks[key] = Timer.periodic(
      Duration(milliseconds: properties['Interval'] as int),
      (_) => tick(form, name),
    );
  }

  /// Starts the clocks of every form's Timers that are Enabled.
  void _startClocks() {
    for (final MapEntry(key: form, value: timers) in _timers.entries) {
      for (final timer in timers.keys) {
        if (!_clocks.containsKey('$form.$timer')) _clock(form, timer);
      }
    }
  }

  void _stopClocks({String? form}) {
    final prefix = form == null ? '' : '${form.toLowerCase()}.';
    for (final key
        in _clocks.keys.where((k) => k.startsWith(prefix)).toList()) {
      _clocks.remove(key)!.cancel();
    }
  }

  /// [timer] of [form] ticks (D100): what its clock does, and what a test
  /// does in its place.
  EventOutcome tick(String form, String timer) =>
      interpreter.raiseTick(timer, form: form);

  final _files = <String, FormFile>{};
  final _models = <String, GbFormModel>{};
  final GbPictureSource? _pictures;
  final String _startup;

  GbFormModel _modelOf(FormFile form) => formModelOf(
    form,
    onEvent: (control, event) => _onEvent(form.name, control, event),
    accepts: (control, event) => _accepts(form.name, control, event),
    pictures: _pictures,
    onKey:
        (
          event,
          keyCode, {
          required shift,
          required control,
          required alt,
          required inTextBox,
        }) => lastOutcome = interpreter.raiseKey(
          event,
          GbKeyEvent(keyCode, shift: shift, control: control, alt: alt),
          form: form.name,
          inTextBox: inTextBox,
        ),
  );

  /// The model of [form], shown or not.
  GbFormModel modelOf(String form) => _models[form.toLowerCase()]!;

  /// The model of the form in front ([front]), or of the startup form
  /// before one is shown.
  GbFormModel get model => modelOf(front?.name ?? _startup);

  /// The forms shown, from the back to the front (D88).
  List<ShownForm> shown = const [];

  /// The form in front, which takes what the user does; null before the
  /// first is shown.
  ShownForm? get front => shown.isEmpty ? null : shown.last;

  /// The form drawn as the run window's, or the app's page or window
  /// (D88): the frontmost shown that is not a dialog, or the startup form
  /// before one is shown.
  String get windowForm {
    final i = shown.lastIndexWhere((f) => !f.dialog);
    return i < 0 ? _startup : shown[i].name;
  }

  /// The model of [windowForm].
  GbFormModel get windowModel => modelOf(windowForm);

  /// Called when the forms shown change.
  VoidCallback? onFormsChanged;

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

  /// Called when the startup form's Form_Load has finished and it is
  /// shown.
  VoidCallback? onShowForm;

  /// What the interpreter did with the last event the user caused; tests
  /// read it.
  EventOutcome? lastOutcome;

  void _onEvent(String form, String? control, String event) =>
      lastOutcome = interpreter.raiseEvent(control, event, form: form);

  /// A CheckBox asks before a click changes it (D44).
  bool _accepts(String form, String? control, String event) {
    final refused = interpreter.refusal(control, event, form: form);
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
  Object getProperty(String form, String? control, String property) {
    final timer = _timers[form.toLowerCase()]?[control?.toLowerCase()];
    if (timer != null) return timer.$2[property]!;
    return modelOf(form).control(control)![property];
  }

  @override
  void setProperty(
    String form,
    String? control,
    String property,
    Object value,
  ) {
    final timer = _timers[form.toLowerCase()]?[control?.toLowerCase()];
    if (timer == null) {
      modelOf(form).setProperty(control, property, value);
      return;
    }
    timer.$2[property] = value;
    if (property == 'Enabled' || property == 'Interval') {
      _clock(form, timer.$1);
    }
  }

  @override
  Future<String?> loadSettings() => settings.load(settingsKey);

  @override
  Future<void> saveSettings(String text) => settings.save(settingsKey, text);

  @override
  void showForms(List<ShownForm> forms) {
    final first = shown.isEmpty;
    if (first) {
      _ticking = true;
      _startClocks();
    }
    shown = List.unmodifiable(forms);
    if (first) onShowForm?.call();
    onFormsChanged?.call();
  }

  @override
  void resetForm(String form) {
    final file = _files[form.toLowerCase()]!;
    _models[form.toLowerCase()] = _modelOf(file);
    _stopClocks(form: form);
    _timers[form.toLowerCase()] = _timersOf(file);
    _startClocks();
  }

  @override
  void addControl(
    String form,
    String control,
    String component,
    Map<String, Object> properties,
  ) => modelOf(form).addControl(
    controlStateOf(
      control,
      builtinComponents[component.toLowerCase()]!,
      properties,
    ),
  );

  @override
  void removeControl(String form, String control) =>
      modelOf(form).removeControl(control);

  @override
  void endProgram() {
    _ticking = false;
    _stopClocks();
    dialogs.closeAll();
  }
}
