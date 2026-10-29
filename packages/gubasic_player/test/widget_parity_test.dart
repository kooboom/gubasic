import 'dart:async';
import 'dart:io';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
      // Its modules (D102): NAME.Module1.gbas, without a form file.
      final modules = <ModuleSource>[
        for (final p
            in dir
                .listSync()
                .whereType<File>()
                .map((f) => f.path)
                .where((p) => p.startsWith('$base.') && p.endsWith('.gbas'))
                .where((p) => p != '$base.gbas')
                .where(
                  (p) =>
                      !File(p.replaceFirst('.gbas', '.form.yaml')).existsSync(),
                )
                .toList()
              ..sort())
          (
            name: p.substring(base.length + 1, p.length - '.gbas'.length),
            source: File(p).readAsStringSync(),
          ),
      ];
      final startupFile = File('$base.startup');
      final project = compileProject(
        sources,
        pictures: pictures,
        modules: modules,
        startsWithMain:
            startupFile.existsSync() &&
            startupFile.readAsStringSync().trim() == startupSubMain,
      );
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
          several || modules.isNotEmpty ? project : null,
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
        namesFile: several || modules.isNotEmpty,
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
  Future<String?> popupMenu(String form, String menu) {
    transcript.add(TranscriptLine.popupMenu(menu));
    return super.popupMenu(form, menu);
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
        GbOptionButton(:final state) ||
        GbComboBox(:final state) ||
        GbFrame(:final state) ||
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
    final model = host.model;
    if (model.control(control) case final item?
        when item.kind == GbControlKind.menu) {
      return _choose(model, item);
    }
    host.lastOutcome = null;
    if (!await _tap(_control(control))) return EventOutcome.blocked;
    return host.lastOutcome ?? EventOutcome.noHandler;
  }

  /// Chooses menu item [item] in the window's menu bar (D106): opens the
  /// menus it is in, from the menu bar down, then clicks it. One that is
  /// grey, or in a menu that opens nothing, is not chosen.
  Future<EventOutcome> _choose(GbFormModel model, GbControlState item) async {
    final path = <GbControlState>[];
    for (GbControlState? m = item; m != null;) {
      path.insert(0, m);
      m = m.container == null ? null : model.control(m.container);
    }
    host.lastOutcome = null;
    for (final m in path) {
      final button = find.byKey(gbMenuKey(m.name!));
      if (button.hitTestable().evaluate().isEmpty) {
        // In a menu that is not Enabled: it opened nothing.
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        return EventOutcome.disabled;
      }
      if (m == item &&
          tester.widget<MenuItemButton>(button).onPressed == null) {
        await tester.sendKeyEvent(LogicalKeyboardKey.escape);
        await tester.pumpAndSettle();
        return EventOutcome.disabled;
      }
      await tester.tap(button);
      await tester.pumpAndSettle();
    }
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
    if (tester.widget(_control(control)) case GbComboBox(:final state)) {
      // A ComboBox opens, then its item is picked (D104).
      if (index >= (state['Items'] as List<String>).length) {
        throw StateError('$control has no item $index');
      }
      if (!await _tap(_control(control))) return EventOutcome.blocked;
      await tester.pumpAndSettle();
      final item = find.byKey(gbListItemKey(state.name!, index));
      host.lastOutcome = null;
      final before = state['ListIndex'];
      await tester.tap(item);
      await tester.pumpAndSettle();
      if (before == index) return null;
      return host.lastOutcome;
    }
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

  /// The keys of a script's names (D101).
  static final _keys = <String, LogicalKeyboardKey>{
    'Left': LogicalKeyboardKey.arrowLeft,
    'Right': LogicalKeyboardKey.arrowRight,
    'Up': LogicalKeyboardKey.arrowUp,
    'Down': LogicalKeyboardKey.arrowDown,
    'Space': LogicalKeyboardKey.space,
    'Enter': LogicalKeyboardKey.enter,
    'Escape': LogicalKeyboardKey.escape,
    'Back': LogicalKeyboardKey.backspace,
    for (var d = 0; d <= 9; d++) ...{
      'D$d': LogicalKeyboardKey(LogicalKeyboardKey.digit0.keyId + d),
      'NumPad$d': LogicalKeyboardKey(LogicalKeyboardKey.numpad0.keyId + d),
    },
    for (var c = 0; c < 26; c++)
      String.fromCharCode(65 + c): LogicalKeyboardKey(
        LogicalKeyboardKey.keyA.keyId + c,
      ),
  };

  /// The keys held down since their KeyDown step: a KeyDown of one again
  /// repeats it, its KeyUp lets it go.
  final _held = <LogicalKeyboardKey>{};

  @override
  Future<EventOutcome> key(KeyStep step) async {
    if (!session.formShown) return EventOutcome.blocked;
    // Where the keys go: the form in front, or the TextBox typed in.
    if (step.control case final control?) {
      final field = find.descendant(
        of: _control(control),
        matching: find.byType(EditableText),
      );
      if (field.hitTestable().evaluate().isEmpty) return EventOutcome.blocked;
      await tester.tap(field);
    } else {
      // The form takes the keys while it or one of its controls other than
      // a TextBox has the focus (a Button clicked keeps it).
      final focus = FocusManager.instance.primaryFocus?.context;
      if (focus == null ||
          focus.findAncestorWidgetOfExactType<GbFormView>() == null ||
          focus.findAncestorWidgetOfExactType<GbTextBox>() != null) {
        host.modelOf(host.front!.name).requestFocus?.call();
      }
    }
    await tester.pump();
    host.lastOutcome = null;
    final modifiers = [
      if (step.shift) LogicalKeyboardKey.shiftLeft,
      if (step.ctrl) LogicalKeyboardKey.controlLeft,
      if (step.alt) LogicalKeyboardKey.altLeft,
    ];
    for (final m in modifiers) {
      await tester.sendKeyDownEvent(m);
    }
    // What the modifiers' own KeyDown did is not the step's.
    host.lastOutcome = null;
    final key = _keys[step.key]!;
    if (step.event == 'KeyDown') {
      if (_held.add(key)) {
        await tester.sendKeyDownEvent(key);
      } else {
        await tester.sendKeyRepeatEvent(key);
      }
    } else {
      if (!_held.remove(key)) {
        throw StateError('${step.text}: the key was not pressed');
      }
      await tester.sendKeyUpEvent(key);
    }
    final outcome = host.lastOutcome;
    for (final m in modifiers.reversed) {
      await tester.sendKeyUpEvent(m);
    }
    await tester.pump();
    return outcome ?? EventOutcome.noHandler;
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

  /// The mouse buttons held down since their MouseDown step, by control.
  final _mice = <String?, TestGesture>{};

  /// A mouse button pressed on the control, or the form, at its place on
  /// it, or let go there (D111): a real pointer on the run window.
  @override
  Future<EventOutcome> mouse(MouseStep step) async {
    if (!session.formShown) return EventOutcome.blocked;
    final target = step.control == null
        ? find.byKey(runFormKey(host.front!.name))
        : _control(step.control!);
    final at =
        tester.getTopLeft(target) +
        Offset(step.x.toDouble(), step.y.toDouble());
    host.lastOutcome = null;
    if (step.event == 'MouseDown') {
      // An open dialog's barrier takes it.
      if (host.dialogs.hasOpenDialog) return EventOutcome.blocked;
      _mice[step.control] = await tester.startGesture(
        at,
        kind: PointerDeviceKind.mouse,
        buttons: switch (step.button) {
          'Right' => kSecondaryMouseButton,
          'Middle' => kMiddleMouseButton,
          _ => kPrimaryMouseButton,
        },
      );
    } else {
      final held =
          _mice.remove(step.control) ??
          (throw StateError('${step.text} without a MouseDown'));
      await held.moveTo(at);
      await held.up();
    }
    await tester.pump();
    return host.lastOutcome ?? EventOutcome.noHandler;
  }

  /// Chooses [item] in the open popup menu (D106), opening the items it
  /// is in first; or closes the menu with Escape.
  @override
  Future<bool> choose(String? item) async {
    final open = find.byWidgetPredicate(
      (w) =>
          w.key is ValueKey<String> &&
          (w.key! as ValueKey<String>).value.startsWith('gb.popup.'),
    );
    if (open.evaluate().isEmpty) return false;
    if (item == null) {
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      return true;
    }
    // The menus it is in, from the outermost; those not in the popup, as
    // the menu it shows, are passed over.
    final model = host.model;
    final path = <String>[];
    for (var m = model.control(item); m != null;) {
      path.insert(0, m.name!);
      m = m.container == null ? null : model.control(m.container);
    }
    for (final name in path) {
      final key = find.byKey(gbPopupKey(name));
      if (key.evaluate().isEmpty) continue;
      if (tester.widget<InkWell>(key).onTap == null) {
        throw StateError('$name cannot be chosen');
      }
      await tester.tap(key);
      await tester.pumpAndSettle();
    }
    return true;
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
