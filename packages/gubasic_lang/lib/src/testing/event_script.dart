import 'dart:async';

import '../analyzer/compile.dart';
import '../forms/form_file.dart';
import '../interpreter/host.dart';
import '../interpreter/interpreter.dart';
import '../interpreter/run_result.dart';

/// One step of an event script (`NAME.events`, docs/DESIGN.md §9.1).
sealed class ScriptStep {
  const ScriptStep(this.text);

  /// The line as written, without its comment: echoed as `> text`.
  final String text;
}

/// `btnSave.Click`: the user causes an event.
class EventStep extends ScriptStep {
  const EventStep(super.text, this.control, this.event);

  /// The control's name, or null for `Form`.
  final String? control;
  final String event;
}

/// `txtName.Type "Kim"`: the user changes a TextBox's text to "Kim"; its
/// Changed event runs if the text changed.
class TypeStep extends ScriptStep {
  const TypeStep(super.text, this.control, this.value);

  final String control;
  final String value;
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

final _event = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.([A-Za-z][A-Za-z0-9_]*)$');
final _type = RegExp(r'^([A-Za-z][A-Za-z0-9_]*)\.Type\s+"((?:[^"]|"")*)"$');
final _answer = RegExp(r'^Answer\s+"((?:[^"]|"")*)"$');

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
    } else if ((m = _type.firstMatch(line)) != null) {
      steps.add(TypeStep(line, m![1]!, m[2]!.replaceAll('""', '"')));
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

/// A [FormHost] for tests: properties start as in the form file, dialogs
/// stay open until the script closes them, and everything the program
/// shows is recorded:
///
///     Debug.Print: <text>
///     MsgBox: <prompt>        (or "MsgBox [<title>]: <prompt>")
///     InputBox: <prompt>      (or "InputBox [<title>]: <prompt>")
///     Set <control>.<property>: <value>
class ScriptedHost implements FormHost {
  ScriptedHost(FormFile form) {
    for (final p in form.component.properties.values) {
      _properties[_key(null, p.name)] = form.valueOf(p.name);
    }
    for (final c in form.controls) {
      for (final p in c.component.properties.values) {
        _properties[_key(c.name, p.name)] = c.valueOf(p.name);
      }
    }
  }

  final transcript = <String>[];
  final _properties = <String, Object>{};
  final _dialogs = <_Dialog>[];
  var shown = false;

  static String _key(String? control, String property) =>
      '${(control ?? 'form').toLowerCase()}.${property.toLowerCase()}';

  bool get hasOpenDialog => _dialogs.isNotEmpty;

  @override
  void debugPrint(String line) => transcript.add('Debug.Print: $line');

  @override
  Future<void> msgBox(String prompt, String title) {
    transcript
        .add(title.isEmpty ? 'MsgBox: $prompt' : 'MsgBox [$title]: $prompt');
    final d = _Dialog(false);
    _dialogs.add(d);
    return d.answer.future;
  }

  @override
  Future<String> inputBox(
      String prompt, String title, String defaultValue) async {
    transcript.add(
        title.isEmpty ? 'InputBox: $prompt' : 'InputBox [$title]: $prompt');
    final d = _Dialog(true);
    _dialogs.add(d);
    return (await d.answer.future) as String;
  }

  @override
  Future<void> yieldNow() => Future<void>.delayed(Duration.zero);

  @override
  Object getProperty(String? control, String property) =>
      _properties[_key(control, property)]!;

  @override
  void setProperty(String? control, String property, Object value) {
    _properties[_key(control, property)] = value;
    transcript.add('Set ${control ?? 'Form'}.$property: $value');
  }

  @override
  void showForm() => shown = true;

  @override
  void endProgram() {
    for (final d in _dialogs.reversed) {
      d.answer.complete(d.isInputBox ? '' : null);
    }
    _dialogs.clear();
  }

  /// The user changes a property (the text of a TextBox).
  void userSets(String control, String property, Object value) =>
      _properties[_key(control, property)] = value;

  /// Closes the topmost dialog; false if it is not of that kind.
  bool answer({required bool inputBox, Object? value}) {
    if (_dialogs.isEmpty || _dialogs.last.isInputBox != inputBox) return false;
    _dialogs.removeLast().answer.complete(value);
    return true;
  }
}

/// Runs [source] with [form] and drives it with [script] (an event
/// script). Returns the transcript: each step echoed as `> step`, what the
/// program showed, and a last line saying how it ended:
///
///     Closed | Ended | Stopped | Error <code> @ <line>
///
/// A step runs only when the program waits for the user (see
/// [Interpreter.isWaitingForUser]), so the transcript is the same on every
/// platform.
Future<List<String>> runEventScript(
    String source, FormFile form, String script) async {
  final steps = parseEventScript(script);
  final program = compile(source, form: form);
  final host = ScriptedHost(form);
  if (program.hasErrors) {
    return [
      for (final d in program.diagnostics)
        if (d.isError) 'Not started: ${d.code.code} @ ${d.line}'
    ];
  }
  final interpreter = Interpreter(program, host);
  RunResult? result;
  final run = interpreter.run().then((r) => result = r);

  // Waits until the program waits for the user. Each check comes after a
  // timer, so that everything the last step started (a closed dialog
  // lets its handler go on) has run as far as it can.
  Future<void> settle() async {
    for (var i = 0; i < 1000000; i++) {
      await Future<void>.delayed(Duration.zero);
      if (result != null) return;
      if (host.hasOpenDialog || (host.shown && interpreter.isWaitingForUser)) {
        return;
      }
    }
    throw StateError('the program never waits for the user');
  }

  final out = host.transcript;
  for (final step in steps) {
    await settle();
    if (result != null) {
      out.add('Script not finished: ${step.text} was not run');
      break;
    }
    out.add('> ${step.text}');
    switch (step) {
      case EventStep(:final control, :final event):
        _record(out, step.text, interpreter.raiseEvent(control, event));
      case TypeStep(:final control, :final value):
        if (host.hasOpenDialog) {
          out.add('Blocked: ${step.text}');
        } else if (host.getProperty(control, 'Text') != value) {
          host.userSets(control, 'Text', value);
          _record(out, step.text, interpreter.raiseEvent(control, 'Changed'));
        }
      case OkStep():
        if (!host.answer(inputBox: false)) {
          throw StateError('"OK" but no MsgBox is open');
        }
      case AnswerStep(:final value):
        if (!host.answer(inputBox: true, value: value ?? '')) {
          throw StateError('"${step.text}" but no InputBox is open');
        }
      case CloseStep():
        if (host.hasOpenDialog) {
          out.add('Blocked: ${step.text}');
        } else {
          interpreter.closeForm();
        }
    }
  }
  await settle();
  if (result == null) {
    out.add('Still open');
    interpreter.closeForm();
  }
  await run;
  out.add(switch (result!) {
    RunCompleted() => 'Closed',
    RunEnded() => 'Ended',
    RunStopped() => 'Stopped',
    RunFailed(:final error) => 'Error ${error.code.code} @ ${error.line}',
    RunNotStarted(:final reason) => 'Not started: ${reason.name}',
  });
  return out;
}

void _record(List<String> out, String step, EventOutcome outcome) {
  switch (outcome) {
    case EventOutcome.ignored:
      out.add('Ignored: $step');
    case EventOutcome.blocked:
      out.add('Blocked: $step');
    case EventOutcome.started ||
          EventOutcome.noHandler ||
          EventOutcome.notRunning:
      break;
  }
}
