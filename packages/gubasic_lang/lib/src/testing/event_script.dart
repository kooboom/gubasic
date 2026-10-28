import 'dart:async';

import '../analyzer/compile.dart';
import '../analyzer/forms.dart';
import '../forms/anchor.dart';
import '../forms/form_file.dart';
import '../forms/keys.dart';
import '../interpreter/host.dart';
import '../interpreter/interpreter.dart';
import '../interpreter/run_result.dart';
import '../interpreter/values.dart';

/// One step of an event script (`NAME.events`, docs/DESIGN.md §9.1).
sealed class ScriptStep {
  const ScriptStep(this.text);

  /// The line as written, without its comment: echoed as `> text`.
  final String text;
}

/// `btnSave.Click`: the user causes an event. On a CheckBox, `Click` is
/// the user's click: it changes Checked, and Changed runs (D44).
class EventStep extends ScriptStep {
  const EventStep(super.text, this.control, this.event, {this.form});

  /// The control's name, or null for `Form`.
  final String? control;
  final String event;

  /// `Form2.btnOK.Click`: the form the user acts on, which must be in
  /// front (D88); null for the one in front.
  final String? form;
}

/// `txtName.Type "Kim"`: the user changes a TextBox's text to "Kim"; its
/// Changed event runs if the text changed.
class TypeStep extends ScriptStep {
  const TypeStep(super.text, this.control, this.value);

  final String control;
  final String value;
}

/// `lstCity.Select 2`: the user picks item 2 of a ListBox; its Changed
/// runs if ListIndex changed (D46).
class SelectStep extends ScriptStep {
  const SelectStep(super.text, this.control, this.index);

  final String control;
  final int index;
}

/// `Form.KeyDown Left`, `Form.KeyUp Shift+A`, `txtName.KeyDown A`: the
/// user presses or lets go a key (D101), with the form in front focused,
/// or while typing in TextBox [control].
class KeyStep extends ScriptStep {
  const KeyStep(super.text, this.event, this.key,
      {this.control, this.shift = false, this.ctrl = false, this.alt = false});

  /// `KeyDown` or `KeyUp`.
  final String event;

  /// The key's name in Keys (`Left`, `A`, `D1`).
  final String key;

  /// The TextBox typed in; null for the form.
  final String? control;
  final bool shift;
  final bool ctrl;
  final bool alt;
}

/// `OK`: closes the open MsgBox.
class OkStep extends ScriptStep {
  const OkStep(super.text);
}

/// `Answer "Kim"` or `Cancel`: closes the open InputBox.
class AnswerStep extends ScriptStep {
  const AnswerStep(super.text, this.value);

  /// Null for Cancel, which gives "".
  final String? value;
}

/// `Close`: the user closes the form.
class CloseStep extends ScriptStep {
  const CloseStep(super.text);
}

/// `Form.Resize 600 400`: the user makes the inside of the form 600 x 400;
/// the controls move as their Anchor says (D57), then Form_Resize runs
/// (D58). Nothing happens when it already is that size.
class ResizeStep extends ScriptStep {
  const ResizeStep(super.text, this.width, this.height);

  final int width;
  final int height;
}

final _event = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)$');
final _formEvent = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)$');
final _type = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.Type\s+"((?:[^"]|"")*)"$');
final _select = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.Select\s+(\d+)$');
final _answer = RegExp(r'^Answer\s+"((?:[^"]|"")*)"$');
final _key = RegExp(
    r'^([A-Za-z][A-Za-z0-9_]*)\.(KeyDown|KeyUp)\s+((?:(?:Shift|Ctrl|Alt)\+)*)([A-Za-z0-9]+)$');
final _resize = RegExp(r'^Form\.Resize\s+(\d+)\s+(\d+)$', caseSensitive: false);

/// Reads an event script. Each line is one step; `'` starts a comment.
/// Throws a [FormatException] for a line it cannot read.
List<ScriptStep> parseEventScript(String text) {
  final steps = <ScriptStep>[];
  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final line = _withoutComment(lines[i]).trim();
    if (line.isEmpty) continue;
    RegExpMatch? m;
    if (line == 'OK') {
      steps.add(OkStep(line));
    } else if (line == 'Cancel') {
      steps.add(AnswerStep(line, null));
    } else if (line == 'Close') {
      steps.add(CloseStep(line));
    } else if ((m = _answer.firstMatch(line)) != null) {
      steps.add(AnswerStep(line, m![1]!.replaceAll('""', '"')));
    } else if ((m = _key.firstMatch(line)) != null) {
      final target = m![1]!;
      final modifiers = m[3]!.split('+');
      final key = keyCodesByLowerName[m[4]!.toLowerCase()];
      if (key == null) {
        throw FormatException('line ${i + 1}: no key named "${m[4]}"');
      }
      steps.add(KeyStep(line, m[2]!, key.$1,
          control: target.toLowerCase() == 'form' ? null : target,
          shift: modifiers.contains('Shift'),
          ctrl: modifiers.contains('Ctrl'),
          alt: modifiers.contains('Alt')));
    } else if ((m = _resize.firstMatch(line)) != null) {
      steps.add(ResizeStep(line, int.parse(m![1]!), int.parse(m[2]!)));
    } else if ((m = _select.firstMatch(line)) != null) {
      steps.add(SelectStep(line, m![1]!, int.parse(m[2]!)));
    } else if ((m = _type.firstMatch(line)) != null) {
      steps.add(TypeStep(line, m![1]!, m[2]!.replaceAll('""', '"')));
    } else if ((m = _formEvent.firstMatch(line)) != null) {
      final control = m![2]!;
      steps.add(EventStep(
          line, control.toLowerCase() == 'form' ? null : control, m[3]!,
          form: m[1]));
    } else if ((m = _event.firstMatch(line)) != null) {
      final control = m![1]!;
      steps.add(EventStep(
          line, control.toLowerCase() == 'form' ? null : control, m[2]!));
    } else {
      throw FormatException('line ${i + 1}: cannot read "$line"');
    }
  }
  return steps;
}

/// [line] without a `'` comment outside a string.
String _withoutComment(String line) {
  var inString = false;
  for (var i = 0; i < line.length; i++) {
    final c = line[i];
    if (c == '"') inString = !inString;
    if (c == "'" && !inString) return line.substring(0, i);
  }
  return line;
}

class _Dialog {
  _Dialog(this.isInputBox);

  final bool isInputBox;
  final answer = Completer<Object?>();
}

/// The transcript lines for what a program shows. [ScriptedHost] and the
/// IDE's run window both write them, so that one `.out` file checks both.
abstract final class TranscriptLine {
  static String debugPrint(String line) => 'Debug.Print: $line';

  static String msgBox(String prompt, String title) =>
      title.isEmpty ? 'MsgBox: $prompt' : 'MsgBox [$title]: $prompt';

  static String inputBox(String prompt, String title) =>
      title.isEmpty ? 'InputBox: $prompt' : 'InputBox [$title]: $prompt';

  static String saveSettings(String text) => 'Settings: $text';

  /// [form] is named when the program has several forms (D88).
  static String setProperty(String? control, String property, Object value,
          {String? form}) =>
      'Set ${form == null ? '' : '$form.'}${control ?? 'Form'}.$property: '
      '${value is bool ? (value ? 'True' : 'False') : value}';

  /// The program put a control made with New on a form (D98).
  static String addControl(String control, String component, {String? form}) =>
      'Add ${form == null ? '' : '$form.'}$control ($component)';

  /// The program took a control off a form (D98).
  static String removeControl(String control, {String? form}) =>
      'Remove ${form == null ? '' : '$form.'}$control';

  /// The forms shown changed, in a program with several forms (D88): from
  /// the back to the front.
  static String forms(List<ShownForm> forms) =>
      forms.isEmpty ? 'Forms: (none)' : 'Forms: ${forms.join(' > ')}';
}

/// A [FormHost] for tests: properties start as in the form files, dialogs
/// stay open until the script closes them, and everything the program
/// shows is recorded ([TranscriptLine]):
///
///     Debug.Print: <text>
///     MsgBox: <prompt>        (or "MsgBox [<title>]: <prompt>")
///     InputBox: <prompt>      (or "InputBox [<title>]: <prompt>")
///     Set <control>.<property>: <value>
///     Settings: <the settings as SaveSetting left them>
///
/// A program with several forms (D88) names the form in `Set` lines
/// (`Set Form2.txtName.Text: Kim`) and records each change of the forms
/// shown (`Forms: Form1 > Form2 (dialog)`).
///
/// The program's settings start as [settings] (a test's NAME.settings),
/// as if an earlier run had saved them.
class ScriptedHost implements FormHost {
  /// A host for a program with one form.
  ScriptedHost(FormFile form, {String? settings})
      : this.forms([form], settings: settings);

  /// A host for a program with [forms] (D88).
  ScriptedHost.forms(List<FormFile> forms, {this.settings})
      : _files = {for (final f in forms) f.name.toLowerCase(): f},
        _several = forms.length > 1 {
    for (final f in forms) {
      _start(f);
    }
  }

  final Map<String, FormFile> _files;
  final bool _several;

  /// Gives [form]'s properties the values of its form file.
  void _start(FormFile form) {
    final name = form.name;
    for (final p in form.component.properties.values) {
      _properties[_key(name, null, p.name)] = form.valueOf(p.name);
    }
    for (final c in form.controls) {
      _components[_key(name, c.name, '')] = c.component.name;
      for (final p in c.component.properties.values.where((p) => p.isStored)) {
        _properties[_key(name, c.name, p.name)] = c.valueOf(p.name);
      }
      if (c.component.properties.values.any((p) => p.anchor)) {
        _rebase(name, c.name);
      }
    }
  }

  /// For each control with an Anchor: where it was, and the form's size
  /// then, last set in the form file or by the program (D57).
  final _bases = <String, (AnchorRect, int, int)>{};

  static const _placing = {'left', 'top', 'width', 'height', 'anchor'};

  int _int(String form, String? control, String property) =>
      _properties[_key(form, control, property)] as int;

  void _rebase(String form, String control) {
    _bases[_key(form, control, '')] = (
      (
        left: _int(form, control, 'Left'),
        top: _int(form, control, 'Top'),
        width: _int(form, control, 'Width'),
        height: _int(form, control, 'Height'),
      ),
      _int(form, null, 'Width'),
      _int(form, null, 'Height'),
    );
  }

  /// Moves [form]'s controls as their Anchor says, for its size now.
  void _place(String form) {
    final prefix = '${form.toLowerCase()}.';
    for (final MapEntry(key: key, value: (base, width, height))
        in _bases.entries) {
      if (!key.startsWith(prefix)) continue;
      final control = key.substring(prefix.length, key.length - 1);
      final r = anchoredRect(
        base,
        _properties[_key(form, control, 'Anchor')] as String,
        baseWidth: width,
        baseHeight: height,
        width: _int(form, null, 'Width'),
        height: _int(form, null, 'Height'),
      );
      _properties[_key(form, control, 'Left')] = r.left;
      _properties[_key(form, control, 'Top')] = r.top;
      _properties[_key(form, control, 'Width')] = r.width;
      _properties[_key(form, control, 'Height')] = r.height;
    }
  }

  /// The user makes the inside of the form in front [width] x [height].
  /// False when it already was that size, so that nothing happens.
  bool resize(int width, int height) {
    final form = front;
    if (_int(form, null, 'Width') == width &&
        _int(form, null, 'Height') == height) {
      return false;
    }
    _properties[_key(form, null, 'Width')] = width;
    _properties[_key(form, null, 'Height')] = height;
    _place(form);
    return true;
  }

  final _components = <String, String>{};

  /// The component of [control] of [form], or of the form in front
  /// (`CheckBox`); null if there is none.
  String? componentOf(String control, {String? form}) =>
      _components[_key(form ?? front, control, '')];

  final transcript = <String>[];

  /// The program's saved settings: what [saveSettings] was given last.
  String? settings;
  final _properties = <String, Object>{};
  final _dialogs = <_Dialog>[];

  /// The forms shown, from the back to the front.
  var forms = const <ShownForm>[];

  /// Whether a form has been shown.
  bool get shown => forms.isNotEmpty;

  /// The form in front, which takes what the user does.
  String get front =>
      forms.isEmpty ? _files.values.first.name : forms.last.name;

  static String _key(String form, String? control, String property) =>
      '${form.toLowerCase()}.${(control ?? 'form').toLowerCase()}.'
      '${property.toLowerCase()}';

  bool get hasOpenDialog => _dialogs.isNotEmpty;

  @override
  void debugPrint(String line) =>
      transcript.add(TranscriptLine.debugPrint(line));

  @override
  Future<void> msgBox(String prompt, String title) {
    transcript.add(TranscriptLine.msgBox(prompt, title));
    final d = _Dialog(false);
    _dialogs.add(d);
    return d.answer.future;
  }

  @override
  Future<String> inputBox(
      String prompt, String title, String defaultValue) async {
    transcript.add(TranscriptLine.inputBox(prompt, title));
    final d = _Dialog(true);
    _dialogs.add(d);
    return (await d.answer.future) as String;
  }

  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);

  @override
  Object getProperty(String form, String? control, String property) =>
      _properties[_key(form, control, property)]!;

  /// A property of the form in front.
  Object frontProperty(String? control, String property) =>
      getProperty(front, control, property);

  @override
  void setProperty(
      String form, String? control, String property, Object value) {
    _properties[_key(form, control, property)] = value;
    transcript.add(TranscriptLine.setProperty(control, property, value,
        form: _several ? form : null));
    final lower = property.toLowerCase();
    if (control == null && (lower == 'width' || lower == 'height')) {
      _place(form);
    } else if (control != null &&
        _placing.contains(lower) &&
        _bases.containsKey(_key(form, control, ''))) {
      _rebase(form, control);
    }
  }

  @override
  Future<String?> loadSettings() async => settings;

  @override
  Future<void> saveSettings(String text) async {
    settings = text;
    transcript.add(TranscriptLine.saveSettings(text));
  }

  @override
  void showForms(List<ShownForm> forms) {
    this.forms = List.unmodifiable(forms);
    if (_several) transcript.add(TranscriptLine.forms(forms));
  }

  @override
  void resetForm(String form) {
    final prefix = '${form.toLowerCase()}.';
    for (final map in [_properties, _components, _bases]) {
      map.removeWhere((key, _) => key.startsWith(prefix));
    }
    _start(_files[form.toLowerCase()]!);
  }

  @override
  void addControl(String form, String control, String component,
      Map<String, Object> properties) {
    _components[_key(form, control, '')] = component;
    for (final MapEntry(:key, :value) in properties.entries) {
      _properties[_key(form, control, key)] = value;
    }
    if (properties.containsKey('Anchor')) _rebase(form, control);
    transcript.add(TranscriptLine.addControl(control, component,
        form: _several ? form : null));
  }

  @override
  void removeControl(String form, String control) {
    final prefix = '${form.toLowerCase()}.${control.toLowerCase()}.';
    for (final map in [_properties, _components, _bases]) {
      map.removeWhere((key, _) => key.startsWith(prefix));
    }
    transcript.add(
        TranscriptLine.removeControl(control, form: _several ? form : null));
  }

  @override
  void endProgram() {
    for (final d in _dialogs.reversed) {
      d.answer.complete(d.isInputBox ? '' : null);
    }
    _dialogs.clear();
  }

  /// The user changes a property of the form in front (the text of a
  /// TextBox, a CheckBox's Checked).
  void userSets(String control, String property, Object value) =>
      _properties[_key(front, control, property)] = value;

  /// Closes the topmost dialog; false if it is not of that kind.
  bool answer({required bool inputBox, Object? value}) {
    if (_dialogs.isEmpty || _dialogs.last.isInputBox != inputBox) return false;
    _dialogs.removeLast().answer.complete(value);
    return true;
  }
}

/// What an event script needs from whatever runs the program: [ScriptedHost]
/// here, or the IDE's run window with its real widgets. [driveEventScript]
/// takes the steps and writes the transcript the same way for both.
abstract interface class ScriptDriver {
  /// What the program showed so far ([TranscriptLine]).
  List<String> get transcript;

  /// How the run ended; null while it runs.
  RunResult? get result;

  /// Whether the program waits for the user: a dialog is open, or the form
  /// is shown and no handler runs (see [Interpreter.isWaitingForUser]).
  bool get waitsForUser;

  /// Lets the program go on a little: a timer tick, or a frame.
  Future<void> tick();

  /// The user causes [event] of [control] (null: the form) of [form], or
  /// of the form in front when it is null (D88). `Click` on a CheckBox
  /// changes its Checked first, unless the program would ignore the
  /// Changed that follows.
  Future<EventOutcome> raise(String? control, String event, {String? form});

  /// The user changes the text of TextBox [control] to [value]. Null when
  /// it already was [value], so that nothing happens.
  Future<EventOutcome?> type(String control, String value);

  /// The user picks item [index] of ListBox [control]. Null when it was
  /// already chosen, so that nothing happens.
  Future<EventOutcome?> select(String control, int index);

  /// The user presses or lets go a key (D101), as [step] says.
  Future<EventOutcome> key(KeyStep step);

  /// Closes the open MsgBox; false if there is none.
  Future<bool> ok();

  /// Closes the open InputBox with [value], or cancels it when [value] is
  /// null; false if there is none.
  Future<bool> answer(String? value);

  /// The user closes the form; false when an open dialog blocks it.
  Future<bool> close();

  /// The user makes the inside of the form [width] x [height]: the
  /// controls move as their Anchor says, then Form_Resize runs. Null when
  /// it already was that size, so that nothing happens.
  Future<EventOutcome?> resize(int width, int height);

  /// Closes the form if it is still open, and waits for the run to end.
  Future<RunResult> finish();
}

/// Runs a project's [forms], the first one or [startup] first (D88), and
/// drives them with [script] on a [ScriptedHost]. See [driveEventScript]
/// for the transcript.
Future<List<String>> runProjectScript(List<FormSource> forms, String script,
    {String? startup,
    String? settings,
    List<String> pictures = const []}) async {
  final steps = parseEventScript(script);
  final project = compileProject(forms, startup: startup, pictures: pictures);
  if (project.hasErrors) {
    return [
      for (final f in project.forms)
        for (final d in f.program.diagnostics)
          if (d.isError) 'Not started: ${d.code.code} @ ${f.codeFile}:${d.line}'
    ];
  }
  final host =
      ScriptedHost.forms([for (final f in forms) f.file], settings: settings);
  return driveEventScript(
      steps, _HostDriver(Interpreter.project(project, host), host),
      namesFile: forms.length > 1);
}

/// Runs [source] with [form] and drives it with [script] (an event
/// script) on a [ScriptedHost]. See [driveEventScript] for the transcript.
///
/// [pictures] are the project's pictures (a test's NAME.pictures).
Future<List<String>> runEventScript(String source, FormFile form, String script,
    {String? settings, List<String> pictures = const []}) async {
  final steps = parseEventScript(script);
  final program = compile(source, form: form, pictures: pictures);
  if (program.hasErrors) {
    return [
      for (final d in program.diagnostics)
        if (d.isError) 'Not started: ${d.code.code} @ ${d.line}'
    ];
  }
  final host = ScriptedHost(form, settings: settings);
  return driveEventScript(steps, _HostDriver(Interpreter(program, host), host));
}

/// Drives a running program with [steps]. Returns the transcript: each step
/// echoed as `> step`, what the program showed, and a last line saying how
/// it ended:
///
///     Closed | Ended | Stopped | Error <code> @ <line>
///
/// A step runs only when the program waits for the user, so the transcript
/// is the same on every platform.
///
/// [namesFile]: a program with several forms names the file an error is
/// in, `Error R0xx @ Form2.gbas:3` (D88).
Future<List<String>> driveEventScript(
    List<ScriptStep> steps, ScriptDriver driver,
    {bool namesFile = false}) async {
  // Waits until the program waits for the user. Each check comes after a
  // tick, so that everything the last step started (a closed dialog lets
  // its handler go on) has run as far as it can.
  Future<void> settle() async {
    for (var i = 0; i < 1000000; i++) {
      await driver.tick();
      if (driver.result != null || driver.waitsForUser) return;
    }
    throw StateError('the program never waits for the user');
  }

  final out = driver.transcript;
  for (final step in steps) {
    await settle();
    if (driver.result != null) {
      out.add('Script not finished: ${step.text} was not run');
      break;
    }
    out.add('> ${step.text}');
    switch (step) {
      case EventStep(:final control, :final event, :final form):
        _record(out, step.text, await driver.raise(control, event, form: form));
      case TypeStep(:final control, :final value):
        final outcome = await driver.type(control, value);
        if (outcome != null) _record(out, step.text, outcome);
      case SelectStep(:final control, :final index):
        final outcome = await driver.select(control, index);
        if (outcome != null) _record(out, step.text, outcome);
      case OkStep():
        if (!await driver.ok()) {
          throw StateError('"OK" but no MsgBox is open');
        }
      case AnswerStep(:final value):
        if (!await driver.answer(value)) {
          throw StateError('"${step.text}" but no InputBox is open');
        }
      case CloseStep():
        if (!await driver.close()) out.add('Blocked: ${step.text}');
      case ResizeStep(:final width, :final height):
        final outcome = await driver.resize(width, height);
        if (outcome != null) _record(out, step.text, outcome);
      case KeyStep():
        _record(out, step.text, await driver.key(step));
    }
  }
  await settle();
  if (driver.result == null) out.add('Still open');
  out.add(switch (await driver.finish()) {
    RunCompleted() => 'Closed',
    RunEnded() => 'Ended',
    RunStopped() => 'Stopped',
    RunFailed(:final error, :final file) => file == null || !namesFile
        ? 'Error ${error.code.code} @ ${error.line}'
        : 'Error ${error.code.code} @ $file:${error.line}',
    RunNotStarted(:final reason) => 'Not started: ${reason.name}',
  });
  return out;
}

/// Drives a [ScriptedHost]: the user's actions go straight to the
/// interpreter.
class _HostDriver implements ScriptDriver {
  _HostDriver(this.interpreter, this.host) {
    _run = interpreter.run().then((r) => result = r);
  }

  final Interpreter interpreter;
  final ScriptedHost host;
  late final Future<RunResult> _run;

  @override
  RunResult? result;

  @override
  List<String> get transcript => host.transcript;

  @override
  bool get waitsForUser =>
      host.hasOpenDialog || (host.shown && interpreter.isWaitingForUser);

  @override
  Future<void> tick() => Future<void>.delayed(Duration.zero);

  @override
  Future<EventOutcome> raise(String? control, String event,
      {String? form}) async {
    if (control != null &&
        event == 'Tick' &&
        host.componentOf(control, form: form) == 'Timer') {
      // A Timer's tick, as its clock would make it (D100).
      return interpreter.raiseTick(control, form: form ?? host.front);
    }
    if (form != null && form.toLowerCase() != host.front.toLowerCase()) {
      return EventOutcome.blocked;
    }
    if (control != null &&
        event == 'Click' &&
        host.componentOf(control) == 'CheckBox') {
      // A click the program would ignore leaves the box as it was (D44).
      if (interpreter.refusal(control, 'Changed') case final refused?) {
        return refused;
      }
      final checked = host.frontProperty(control, 'Checked') as bool;
      host.userSets(control, 'Checked', !checked);
      return interpreter.raiseEvent(control, 'Changed');
    }
    return interpreter.raiseEvent(control, event);
  }

  @override
  Future<EventOutcome?> type(String control, String value) async {
    if (host.hasOpenDialog) return EventOutcome.blocked;
    if (host.frontProperty(control, 'Text') == value) return null;
    host.userSets(control, 'Text', value);
    return interpreter.raiseEvent(control, 'Changed');
  }

  @override
  Future<EventOutcome?> select(String control, int index) async {
    final items = host.frontProperty(control, 'Items') as List<String>;
    if (index >= items.length) {
      throw StateError('$control has no item $index');
    }
    if (host.hasOpenDialog) return EventOutcome.blocked;
    if (host.frontProperty(control, 'ListIndex') == index) return null;
    // A pick the program would ignore leaves the choice as it was.
    if (interpreter.refusal(control, 'Changed') case final refused?) {
      return refused;
    }
    host.userSets(control, 'ListIndex', index);
    return interpreter.raiseEvent(control, 'Changed');
  }

  @override
  Future<EventOutcome> key(KeyStep step) async => interpreter.raiseKey(
      step.event,
      GbKeyEvent(keyCodes[step.key]!,
          shift: step.shift, control: step.ctrl, alt: step.alt),
      inTextBox: step.control != null);

  @override
  Future<bool> ok() async => host.answer(inputBox: false);

  @override
  Future<bool> answer(String? value) async =>
      host.answer(inputBox: true, value: value ?? '');

  @override
  Future<bool> close() async {
    if (host.hasOpenDialog) return false;
    interpreter.closeForm();
    return true;
  }

  @override
  Future<EventOutcome?> resize(int width, int height) async {
    if (host.hasOpenDialog) return EventOutcome.blocked;
    if (!host.resize(width, height)) return null;
    return interpreter.raiseEvent(null, 'Resize');
  }

  @override
  Future<RunResult> finish() {
    if (result == null) interpreter.closeForm();
    return _run;
  }
}

void _record(List<String> out, String step, EventOutcome outcome) {
  switch (outcome) {
    case EventOutcome.ignored:
      out.add('Ignored: $step');
    case EventOutcome.blocked:
      out.add('Blocked: $step');
    case EventOutcome.disabled:
      out.add('Disabled: $step');
    case EventOutcome.started ||
          EventOutcome.noHandler ||
          EventOutcome.notRunning:
      break;
  }
}
