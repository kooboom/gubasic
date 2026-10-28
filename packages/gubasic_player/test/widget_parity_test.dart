import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
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
      // Form1, and the project's other forms (D88): NAME.Form2.form.yaml
      // and NAME.Form2.gbas.
      final others =
          dir
              .listSync()
              .whereType<File>()
              .map((f) => f.path)
              .where((p) => p.startsWith('$base.') && p.endsWith('.form.yaml'))
              .where((p) => p != '$base.form.yaml')
              .toList()
            ..sort();
      final sources = <FormSource>[
        for (final (formName, path) in [
          ('Form1', '$base.form.yaml'),
          for (final p in others)
            (p.substring(base.length + 1, p.length - '.form.yaml'.length), p),
        ])
          (
            file: readFormFile(
              File(path).readAsStringSync(),
              name: formName,
              pictures: pictures,
            ).form,
            source: File(path.replaceFirst('.form.yaml', '.gbas'))
                .readAsStringSync(),
          ),
      ];
      final project = compileProject(sources, pictures: pictures);
      final startup = project.startup;
      final several = sources.length > 1;
      final expected = File('$base.out').readAsStringSync().trimRight();
      final settings = File('$base.settings');
      final host = _RecordingHost(startup.file, [
        for (final f in sources.skip(1)) f.file,
      ], settings.existsSync() ? settings.readAsStringSync().trim() : null);
      final session = RunSession(
        StartupForm(
          startup.file,
          startup.codeFile,
          startup.program,
          several ? project : null,
        ),
        strings: PlayerStrings.en,
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
        namesFile: several,
      );
      expect(transcript.join('\n'), expected);
      session.dispose();
    });
  }
}

/// Records what the program shows, as [ScriptedHost] does.
class _RecordingHost extends RunHost {
  _RecordingHost(super.form, List<FormFile> others, String? settings)
    : _several = others.isNotEmpty,
      super(
        others: others,
        settings: GbMemorySettings()..values.addAll({'': ?settings}),
      );

  /// A program with several forms names the form in its lines (D88).
  final bool _several;

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
  void setProperty(
    String form,
    String? control,
    String property,
    Object value,
  ) {
    transcript.add(
      TranscriptLine.setProperty(
        control,
        property,
        value,
        form: _several ? form : null,
      ),
    );
    super.setProperty(form, control, property, value);
  }

  @override
  void showForms(List<ShownForm> forms) {
    if (_several) transcript.add(TranscriptLine.forms(forms));
    super.showForms(forms);
  }

  @override
  void addControl(
    String form,
    String control,
    String component,
    Map<String, Object> properties,
  ) {
    transcript.add(
      TranscriptLine.addControl(
        control,
        component,
        form: _several ? form : null,
      ),
    );
    super.addControl(form, control, component, properties);
  }

  @override
  void removeControl(String form, String control) {
    transcript.add(
      TranscriptLine.removeControl(control, form: _several ? form : null),
    );
    super.removeControl(form, control);
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

  /// Control [name] of the form in front (D88).
  Finder _control(String name) => find.descendant(
    of: find.byKey(runFormKey(host.front!.name)),
    matching: find.byWidgetPredicate(
      (w) => switch (w) {
        GbButton(:final state) ||
        GbLabel(:final state) ||
        GbTextBox(:final state) ||
        GbCheckBox(:final state) ||
        GbListBox(:final state) ||
        GbImage(
          :final state,
        ) => state.name?.toLowerCase() == name.toLowerCase(),
        _ => false,
      },
    ),
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
  Future<EventOutcome> raise(
    String? control,
    String event, {
    String? form,
  }) async {
    if (control != null && event == 'Tick') {
      // A Timer's tick, as its clock would make it (D100).
      return host.tick(form ?? host.front?.name ?? host.windowForm, control);
    }
    if (control == null || event != 'Click') {
      throw UnsupportedError('no widget for $control.$event');
    }
    // Before Form_Load has finished, the form is not on the screen.
    if (!session.formShown) return EventOutcome.blocked;
    // A form behind the one in front cannot be clicked: in the run
    // window it is not even drawn, or a dialog's barrier covers it.
    if (form != null && form.toLowerCase() != host.front!.name.toLowerCase()) {
      return EventOutcome.blocked;
    }
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
        matching: find.text(PlayerStrings.en.runtime.ok),
      ),
    );
  }

  @override
  Future<bool> answer(String? value) async {
    if (!host.dialogs.hasOpenDialog || !_dialogIsInputBox) return false;
    final strings = PlayerStrings.en.runtime;
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
    if (!session.formShown) return EventOutcome.blocked;
    final form = host.windowModel.form;
    final dx = width - form.integer('Width');
    final dy = height - form.integer('Height');
    if (dx == 0 && dy == 0) return null;
    // The run window's corner, dragged as the user would; an open
    // dialog covers it.
    final corner = find.byKey(runWindowResizeKey);
    await tester.ensureVisible(corner);
    if (corner.hitTestable().evaluate().isEmpty) return EventOutcome.blocked;
    host.lastOutcome = null;
    await tester.drag(corner, Offset(dx.toDouble(), dy.toDouble()));
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
