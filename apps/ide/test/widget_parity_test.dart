import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/project.dart';
import 'package:gubasic_ide/src/run/run_host.dart';
import 'package:gubasic_ide/src/run/run_session.dart';
import 'package:gubasic_ide/src/run/run_window.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The event scripts of test/parity/ (docs/DESIGN.md §9.1), run through the
/// real run window: clicks and typing go through the widgets, dialogs are
/// closed with their buttons, and the form with its close button. The
/// transcript must be the same `.out` that the interpreter's own parity
/// test checks.
void main() {
  final dir = Directory('../../test/parity');
  final scripts =
      dir
          .listSync()
          .whereType<File>()
          .where((f) => f.path.endsWith('.events'))
          .toList()
        ..sort((a, b) => a.path.compareTo(b.path));

  for (final script in scripts) {
    final base = script.path.substring(0, script.path.length - 7);
    final name = base.split('/').last;
    testWidgets('$name runs the same in the run window', (tester) async {
      final picturesFile = File('$base.pictures');
      final pictures = picturesFile.existsSync()
          ? picturesFile.readAsLinesSync().where((l) => l.isNotEmpty).toList()
          : <String>[];
      final form = readFormFile(
        File('$base.form.yaml').readAsStringSync(),
        name: 'Form1',
        pictures: pictures,
      ).form;
      final program = compile(
        File('$base.gbas').readAsStringSync(),
        form: form,
        pictures: pictures,
      );
      final expected = File('$base.out').readAsStringSync().trimRight();
      final settings = File('$base.settings');
      final host = _RecordingHost(
        form,
        settings.existsSync() ? settings.readAsStringSync().trim() : null,
      );
      final session = RunSession(
        StartupForm(form, '$name.gbas', program),
        strings: IdeStrings.en,
        host: host,
      );
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Center(child: RunWindow(session: session)),
          ),
        ),
      );
      final transcript = await driveEventScript(
        parseEventScript(script.readAsStringSync()),
        _WidgetDriver(tester, session, host),
      );
      expect(transcript.join('\n'), expected);
      session.dispose();
    });
  }
}

/// Records what the program shows, as [ScriptedHost] does.
class _RecordingHost extends RunHost {
  _RecordingHost(super.form, String? settings)
    : super(settings: GbMemorySettings()..values.addAll({'': ?settings}));

  final transcript = <String>[];
  final _yields = <Completer<void>>[];

  /// DoEvents and the regular yields wait here until the driver's next
  /// tick. Fake time cannot run RunHost's zero-length timers: a DoEvents
  /// loop keeps adding new ones, so elapsing time would never return.
  @override
  Future<void> yieldNow() {
    final c = Completer<void>();
    _yields.add(c);
    return c.future;
  }

  void resumeYields() {
    final waiting = List.of(_yields);
    _yields.clear();
    for (final c in waiting) {
      c.complete();
    }
  }

  @override
  void debugPrint(String line) {
    transcript.add(TranscriptLine.debugPrint(line));
    super.debugPrint(line);
  }

  @override
  Future<void> msgBox(String prompt, String title) {
    transcript.add(TranscriptLine.msgBox(prompt, title));
    return super.msgBox(prompt, title);
  }

  @override
  Future<String> inputBox(String prompt, String title, String defaultValue) {
    transcript.add(TranscriptLine.inputBox(prompt, title));
    return super.inputBox(prompt, title, defaultValue);
  }

  @override
  Future<void> saveSettings(String text) {
    transcript.add(TranscriptLine.saveSettings(text));
    return super.saveSettings(text);
  }

  @override
  void setProperty(String? control, String property, Object value) {
    transcript.add(TranscriptLine.setProperty(control, property, value));
    super.setProperty(control, property, value);
  }
}

/// Does what the script says on the screen. A step whose widget is covered
/// (by an open dialog's barrier) does not reach the program: Blocked.
class _WidgetDriver implements ScriptDriver {
  _WidgetDriver(this.tester, this.session, this.host);

  final WidgetTester tester;
  final RunSession session;
  final _RecordingHost host;

  @override
  List<String> get transcript => host.transcript;

  @override
  RunResult? get result => session.result;

  @override
  bool get waitsForUser =>
      host.dialogs.hasOpenDialog ||
      (session.formShown && session.interpreter.isWaitingForUser);

  @override
  Future<void> tick() async {
    host.resumeYields();
    await tester.pump();
  }

  Finder _control(String name) => find.byWidgetPredicate(
    (w) => switch (w) {
      GbButton(:final state) ||
      GbLabel(:final state) ||
      GbTextBox(:final state) ||
      GbCheckBox(:final state) ||
      GbListBox(:final state) ||
      GbImage(:final state) => state.name?.toLowerCase() == name.toLowerCase(),
      _ => false,
    },
  );

  /// The topmost dialog, or nothing.
  Finder get _dialog => find.byType(AlertDialog).last;

  bool get _dialogIsInputBox => find
      .descendant(of: _dialog, matching: find.byType(TextField))
      .evaluate()
      .isNotEmpty;

  /// Taps [finder] if the user could: false when something covers it.
  Future<bool> _tap(Finder finder) async {
    expect(finder, findsOneWidget);
    if (finder.hitTestable().evaluate().isEmpty) return false;
    await tester.tap(finder);
    await tester.pump();
    return true;
  }

  @override
  Future<EventOutcome> raise(String? control, String event) async {
    if (control == null || event != 'Click') {
      throw UnsupportedError('no widget for $control.$event');
    }
    // Before Form_Load has finished, the form is not on the screen.
    if (!session.formShown) return EventOutcome.blocked;
    host.lastOutcome = null;
    if (!await _tap(_control(control))) return EventOutcome.blocked;
    return host.lastOutcome ?? EventOutcome.noHandler;
  }

  @override
  Future<EventOutcome?> type(String control, String value) async {
    if (!session.formShown) return EventOutcome.blocked;
    final field = find.descendant(
      of: _control(control),
      matching: find.byType(EditableText),
    );
    if (field.hitTestable().evaluate().isEmpty) return EventOutcome.blocked;
    if (tester.widget<EditableText>(field).controller.text == value) {
      return null;
    }
    host.lastOutcome = null;
    await tester.enterText(field, value);
    await tester.pump();
    return host.lastOutcome;
  }

  @override
  Future<EventOutcome?> select(String control, int index) async {
    if (!session.formShown) return EventOutcome.blocked;
    final box = tester.widget<GbListBox>(_control(control)).state;
    if (index >= (box['Items'] as List<String>).length) {
      throw StateError('$control has no item $index');
    }
    final item = find.byKey(gbListItemKey(box.name!, index));
    await tester.ensureVisible(item);
    if (item.hitTestable().evaluate().isEmpty) return EventOutcome.blocked;
    if (box['ListIndex'] == index) return null;
    host.lastOutcome = null;
    await tester.tap(item);
    await tester.pump();
    return host.lastOutcome;
  }

  @override
  Future<bool> ok() async {
    if (!host.dialogs.hasOpenDialog || _dialogIsInputBox) return false;
    return _tap(
      find.descendant(
        of: _dialog,
        matching: find.text(IdeStrings.en.runtime.ok),
      ),
    );
  }

  @override
  Future<bool> answer(String? value) async {
    if (!host.dialogs.hasOpenDialog || !_dialogIsInputBox) return false;
    final strings = IdeStrings.en.runtime;
    if (value != null) {
      await tester.enterText(
        find.descendant(of: _dialog, matching: find.byType(TextField)),
        value,
      );
    }
    return _tap(
      find.descendant(
        of: _dialog,
        matching: find.text(value == null ? strings.cancel : strings.ok),
      ),
    );
  }

  @override
  Future<bool> close() => _tap(find.byKey(runWindowCloseKey));

  @override
  Future<EventOutcome?> resize(int width, int height) async {
    if (host.dialogs.hasOpenDialog) return EventOutcome.blocked;
    final form = host.model.form;
    if (form.integer('Width') == width && form.integer('Height') == height) {
      return null;
    }
    host.lastOutcome = null;
    // As the run window does when its corner is dragged.
    host.model.resize(width, height);
    await tester.pump();
    return host.lastOutcome ?? EventOutcome.noHandler;
  }

  @override
  Future<RunResult> finish() async {
    if (session.result == null) session.closeForm();
    for (var i = 0; i < 1000 && session.result == null; i++) {
      await tester.pump();
    }
    return session.result!;
  }
}
