import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const formFile = 'Form1.form.yaml';

  Future<void> open(
    WidgetTester tester, {
    Map<String, Map<String, String>>? projects,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: projects ?? {'hello': hello}, strings: s),
    );
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
  }

  Finder onForm(String text) => find.descendant(
    of: find.byKey(designerFormKey),
    matching: find.text(text),
  );

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;
  String formText(WidgetTester tester) => current(tester).files[formFile]!;

  Future<void> chooseTool(WidgetTester tester, String type) async {
    await tester.tap(find.byKey(ValueKey('toolbox.$type')));
    await tester.pump();
  }

  /// Drags with the mouse on the form, from [from] to [to] inside it.
  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    final mouse = await tester.startGesture(
      origin + from,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.moveTo(origin + (from + to) / 2);
    await tester.pump();
    await mouse.moveTo(origin + to);
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    // Past a double-click: the next press is a press of its own.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testWidgets('a form file opens in the designer, drawn by the runtime', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(FormDesigner), findsOneWidget);
    expect(find.text('Say hello'), findsOneWidget, reason: 'btnHello');
    for (final tool in ['Pointer', 'Button', 'Label', 'TextBox']) {
      expect(find.text(tool), findsOneWidget, reason: tool);
    }
    expect(find.text('Form1 (Form) · 320×120'), findsOneWidget);

    await tester.tap(find.text(s.viewFormFile));
    await tester.pumpAndSettle();
    expect(find.textContaining('name: btnHello'), findsOneWidget);
    await tester.tap(find.text(s.viewDesigner));
    await tester.pumpAndSettle();
    expect(find.text('Say hello'), findsOneWidget);
  });

  testWidgets('a drag with a tool draws a control, selected at once', (
    tester,
  ) async {
    await open(tester);
    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(300, 100), const Offset(200, 64));

    expect(formText(tester), contains('  - name: Button1\n'));
    expect(formText(tester), contains('      Caption: Button1\n'));
    expect(onForm('Button1'), findsOneWidget, reason: 'drawn');
    expect(
      find.text('Button1 (Button) · Left 200, Top 64 · 104×40'),
      findsOneWidget,
      reason: 'selected',
    );
    expect(find.text('Hello — Edited'), findsOneWidget);

    // The tool goes back to the pointer: a click selects.
    await drag(tester, const Offset(20, 60), const Offset(20, 60));
    expect(find.textContaining('btnHello (Button)'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    // Its handler stays in the code: asked first (D64).
    await tester.tap(find.widgetWithText(FilledButton, s.deleteControl));
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('btnHello')));

    await drag(tester, const Offset(250, 80), const Offset(250, 80));
    expect(find.textContaining('Button1 (Button)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('Button1')));
  });

  testWidgets('a click with a tool places the default size', (tester) async {
    await open(tester);
    await chooseTool(tester, 'TextBox');
    await drag(tester, const Offset(100, 50), const Offset(102, 51));
    expect(
      find.text('TextBox1 (TextBox) · Left 104, Top 48 · 160×32'),
      findsOneWidget,
    );
  });

  testWidgets('a double-click in the toolbox places in the middle', (
    tester,
  ) async {
    await open(tester);
    final label = find.byKey(const ValueKey('toolbox.Label'));
    await tester.tap(label);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(label);
    await tester.pumpAndSettle();
    expect(
      find.text('Label1 (Label) · Left 104, Top 48 · 120×24'),
      findsOneWidget,
    );
    expect(formText(tester), contains('  - name: Label1\n'));
  });

  testWidgets('a CheckBox: placed from the toolbox, Checked set in the '
      'Properties window; a click on the form only selects it', (tester) async {
    await open(tester);
    final tool = find.byKey(const ValueKey('toolbox.CheckBox'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    expect(
      // Below btnHello, which is in the middle (D68).
      find.text('CheckBox1 (CheckBox) · Left 104, Top 88 · 120×32'),
      findsOneWidget,
    );
    final onDesigner = find.descendant(
      of: find.byKey(designerFormKey),
      matching: find.byType(Checkbox),
    );
    bool shown() => tester.widget<Checkbox>(onDesigner).value!;
    expect(shown(), isFalse);

    await tester.tap(
      find.descendant(
        of: find.byType(PropertiesPanel),
        matching: find.byType(Checkbox),
      ),
    );
    await tester.pumpAndSettle();
    expect(formText(tester), contains('      Checked: true\n'));
    expect(shown(), isTrue);

    await tester.tap(onDesigner);
    await tester.pumpAndSettle();
    expect(shown(), isTrue, reason: 'the designer does not run the box');
  });

  testWidgets('a ListBox: placed from the toolbox, it shows its name; the '
      'Properties window has only where it is and its size', (tester) async {
    await open(tester);
    final tool = find.byKey(const ValueKey('toolbox.ListBox'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    expect(
      find.text('ListBox1 (ListBox) · Left 80, Top 0 · 160×120'),
      findsOneWidget,
    );
    expect(onForm('ListBox1'), findsOneWidget);
    for (final name in ['Left', 'Top', 'Width', 'Height']) {
      expect(find.byKey(propertyFieldKey(name)), findsOneWidget, reason: name);
    }
    for (final name in ['ListIndex', 'ListCount', 'Text', 'Items']) {
      expect(find.byKey(propertyFieldKey(name)), findsNothing, reason: name);
    }
    expect(formText(tester), isNot(contains('ListIndex')));
  });

  testWidgets('undo and redo, back to the saved text', (tester) async {
    await open(tester);
    final saved = formText(tester);
    await chooseTool(tester, 'Label');
    await drag(tester, const Offset(200, 80), const Offset(260, 100));
    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(100, 80), const Offset(100, 80));
    final both = formText(tester);
    expect(both, contains('Label1'));
    expect(both, contains('Button1'));

    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), isNot(contains('Button1')));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), saved);
    expect(find.text('Hello — Edited'), findsNothing);

    await ctrl(tester, LogicalKeyboardKey.keyY);
    expect(formText(tester), contains('Label1'));
    expect(find.text('Hello — Edited'), findsOneWidget);
    await tester.tap(find.byTooltip('${s.redo} (Ctrl+Y)'));
    await tester.pumpAndSettle();
    expect(formText(tester), both);
    await tester.tap(find.byTooltip('${s.undo} (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('Button1')));
  });

  testWidgets('the grid can be turned off', (tester) async {
    await open(tester);
    await tester.tap(find.text(s.grid));
    await tester.pumpAndSettle();
    await chooseTool(tester, 'Label');
    await drag(tester, const Offset(201, 83), const Offset(255, 101));
    expect(
      find.text('Label1 (Label) · Left 201, Top 83 · 54×18'),
      findsOneWidget,
    );
  });

  testWidgets('Esc goes back to the pointer and clears the selection', (
    tester,
  ) async {
    await open(tester);
    await chooseTool(tester, 'Button');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await drag(tester, const Offset(20, 60), const Offset(20, 60));
    expect(find.textContaining('btnHello (Button)'), findsOneWidget);
    expect(formText(tester), hello[formFile], reason: 'nothing placed');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Form1 (Form) · 320×120'), findsOneWidget);
  });

  testWidgets('F5 runs the form as drawn', (tester) async {
    await open(tester);
    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(200, 64), const Offset(296, 96));
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsOneWidget);
    expect(
      find.descendant(
        of: find.byType(RunWindow),
        matching: find.text('Button1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('the form cannot be changed while the program runs', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    expect(find.text(s.lockedWhileRunning), findsOneWidget);

    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(200, 64), const Offset(296, 96));
    final label = find.byKey(const ValueKey('toolbox.Label'));
    await tester.tap(label);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(label);
    await tester.pumpAndSettle();
    await drag(tester, const Offset(20, 60), const Offset(20, 60));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(formText(tester), hello[formFile]);

    await tester.tap(find.text('Stop (Shift+F5)'));
    await tester.pumpAndSettle();
    expect(find.text(s.lockedWhileRunning), findsNothing);
  });

  testWidgets('a form file with errors is only shown', (tester) async {
    final broken = hello[formFile]!.replaceFirst(
      '      Caption: Say hello\n',
      '      Caption: Say hello\n      Colour: red\n',
    );
    await open(
      tester,
      projects: {
        'hello': {...hello, formFile: broken},
      },
    );
    expect(find.text(s.formHasErrors), findsOneWidget);
    expect(find.textContaining('Colour'), findsWidgets, reason: 'the error');
    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(200, 64), const Offset(296, 96));
    expect(formText(tester), broken);
  });

  testWidgets('the undo history ends with the project', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdeApp(projects: exampleProjects, strings: s));
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(200, 64), const Offset(200, 64));

    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('typing').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.dontSave));
    await tester.pumpAndSettle();
    await tester.tap(find.text('typing'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('hello').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    expect(formText(tester), hello[formFile]);
    final undo = tester.widget<IconButton>(
      find.widgetWithIcon(IconButton, Icons.undo),
    );
    expect(undo.onPressed, isNull);
  });

  String status(WidgetTester tester) => tester
      .widgetList<Text>(
        find.descendant(
          of: find.byType(FormDesigner),
          matching: find.byType(Text),
        ),
      )
      .map((t) => t.data ?? '')
      .lastWhere((t) => t.contains(' · '));

  testWidgets('a control follows the mouse and lands on the grid', (
    tester,
  ) async {
    await open(tester);
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    final before = tester.getTopLeft(onForm('Say hello'));
    final mouse = await tester.startGesture(
      origin + const Offset(30, 70),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.moveTo(origin + const Offset(50, 80));
    await tester.pump();
    await mouse.moveTo(origin + const Offset(75, 91));
    await tester.pump();
    expect(
      tester.getTopLeft(onForm('Say hello')),
      before + const Offset(48, 24),
      reason: 'the widget follows at once',
    );
    expect(formText(tester), hello[formFile], reason: 'the file waits');
    expect(status(tester), 'btnHello (Button) · Left 64, Top 80 · 120×32');
    await mouse.up();
    await tester.pumpAndSettle();
    expect(formText(tester), contains('      Left: 64\n      Top: 80\n'));

    // A move of a pixel or two only selects.
    final moved = formText(tester);
    await drag(tester, const Offset(80, 90), const Offset(82, 91));
    expect(formText(tester), moved);

    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), hello[formFile]);
  });

  testWidgets('each of the eight handles resizes its own edges', (
    tester,
  ) async {
    await open(tester);
    await drag(tester, const Offset(30, 70), const Offset(30, 70));
    // btnHello: Left 16, Top 56, 120 x 32.
    for (final (hx, hy) in [
      (-1, -1),
      (0, -1),
      (1, -1),
      (-1, 0),
      (1, 0),
      (-1, 1),
      (0, 1),
      (1, 1),
    ]) {
      final at = Offset(16 + (hx + 1) / 2 * 120, 56 + (hy + 1) / 2 * 32);
      await drag(tester, at, at + Offset(8.0 * hx, 8.0 * hy));
      final left = 16 - (hx < 0 ? 8 : 0);
      final top = 56 - (hy < 0 ? 8 : 0);
      final width = 120 + 8 * hx.abs();
      final height = 32 + 8 * hy.abs();
      expect(
        status(tester),
        'btnHello (Button) · Left $left, Top $top · $width×$height',
        reason: 'handle ($hx, $hy)',
      );
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(formText(tester), hello[formFile]);
    }
  });

  testWidgets("the form's handles resize the form", (tester) async {
    await open(tester);
    final corner = find.byKey(const ValueKey('designer.formHandle.1.1'));
    await tester.dragFrom(
      tester.getCenter(corner),
      const Offset(43, 21),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(status(tester), 'Form1 (Form) · 360×144');
    expect(formText(tester), contains('  Width: 360\n  Height: 144\n'));

    final right = find.byKey(const ValueKey('designer.formHandle.1.0'));
    await tester.dragFrom(
      tester.getCenter(right),
      const Offset(-500, 30),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(status(tester), 'Form1 (Form) · 64×144', reason: 'only across');
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), hello[formFile]);
  });

  testWidgets('deleting a control the code uses asks first, naming the '
      'lines; undo brings it back (D64)', (tester) async {
    await open(tester);
    // lblMessage: the dotted box at the top of hello's form.
    await drag(tester, const Offset(100, 20), const Offset(100, 20));
    expect(find.textContaining('lblMessage (Label)'), findsOneWidget);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    final asked = s.deleteUsedControl
        .replaceAll('{0}', 'lblMessage')
        .replaceAll('{1}', 'Form1.gbas')
        .replaceAll('{2}', '4');
    expect(find.textContaining(asked), findsOneWidget);
    expect(
      find.textContaining(s.deleteUndo.replaceAll('{0}', 'Ctrl+Z')),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();
    expect(formText(tester), contains('lblMessage'));

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, s.deleteControl));
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('lblMessage')));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), hello[formFile]);
  });

  testWidgets('a control with only a handler says the handler stays; one '
      'the code does not use goes at once', (tester) async {
    await open(tester);
    await drag(tester, const Offset(30, 70), const Offset(30, 70));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(
      find.textContaining(
        s.deleteHandlersStay.replaceAll('{0}', 'btnHello_Click'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.textContaining('btnHello is used'),
      ),
      findsNothing,
      reason: 'only its handler is in the code',
    );
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();

    await chooseTool(tester, 'Button');
    await drag(tester, const Offset(200, 20), const Offset(260, 50));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsNothing);
    expect(formText(tester), hello[formFile]);
  });

  testWidgets('arrow keys move and resize the selected control', (
    tester,
  ) async {
    await open(tester);
    await drag(tester, const Offset(30, 70), const Offset(30, 70));
    await ctrl(tester, LogicalKeyboardKey.arrowRight);
    await ctrl(tester, LogicalKeyboardKey.arrowDown);
    expect(status(tester), 'btnHello (Button) · Left 24, Top 64 · 120×32');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(status(tester), 'btnHello (Button) · Left 24, Top 64 · 128×24');

    await tester.tap(find.text(s.grid));
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.arrowLeft);
    expect(status(tester), 'btnHello (Button) · Left 23, Top 64 · 128×24');

    // Each key is one step back.
    for (var i = 0; i < 5; i++) {
      await ctrl(tester, LogicalKeyboardKey.keyZ);
    }
    expect(formText(tester), hello[formFile]);
  });

  testWidgets('the cursor shows what the mouse would do', (tester) async {
    await open(tester);
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: origin + const Offset(200, 100));
    addTearDown(mouse.removePointer);
    MouseCursor cursorAt(Offset p) {
      return RendererBinding.instance.mouseTracker.debugDeviceActiveCursor(1)!;
    }

    Future<MouseCursor> at(Offset p) async {
      await mouse.moveTo(origin + p);
      await tester.pump();
      return cursorAt(p);
    }

    expect(await at(const Offset(30, 70)), SystemMouseCursors.move);
    await drag(tester, const Offset(30, 70), const Offset(30, 70));
    expect(await at(const Offset(136, 72)), SystemMouseCursors.resizeLeftRight);
    expect(await at(const Offset(76, 88)), SystemMouseCursors.resizeUpDown);
    expect(
      await at(const Offset(136, 88)),
      SystemMouseCursors.resizeUpLeftDownRight,
    );
    expect(
      await at(const Offset(16, 88)),
      SystemMouseCursors.resizeUpRightDownLeft,
    );
    expect(await at(const Offset(250, 100)), SystemMouseCursors.basic);
    await chooseTool(tester, 'Label');
    expect(await at(const Offset(250, 101)), SystemMouseCursors.precise);
    // Past the wait for a second click on the tool.
    await tester.pump(kDoubleTapTimeout);
  });

  testWidgets('nothing moves while the program runs', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    await drag(tester, const Offset(30, 70), const Offset(90, 100));
    await ctrl(tester, LogicalKeyboardKey.arrowRight);
    final corner = find.byKey(const ValueKey('designer.formHandle.1.1'));
    await tester.dragFrom(
      tester.getCenter(corner),
      const Offset(40, 40),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(formText(tester), hello[formFile]);
  });

  group('layers (D41)', () {
    // A Label over btnHello, later in the file: still drawn under it.
    final over = {
      ...hello,
      formFile:
          '${hello[formFile]}'
          '  - name: lblOver\n'
          '    type: Label\n'
          '    properties:\n'
          '      Left: 8\n'
          '      Top: 48\n'
          '      Width: 200\n'
          '      Height: 48\n',
    };

    testWidgets('a click where they overlap selects the Button', (
      tester,
    ) async {
      await open(tester, projects: {'hello': over});
      await drag(tester, const Offset(30, 70), const Offset(30, 70));
      expect(find.textContaining('btnHello (Button)'), findsOneWidget);
      await drag(tester, const Offset(180, 70), const Offset(180, 70));
      expect(find.textContaining('lblOver (Label)'), findsOneWidget);
    });

    testWidgets('in the run window, the Button takes the click', (
      tester,
    ) async {
      await open(tester, projects: {'hello': over});
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      final form = find.descendant(
        of: find.byType(RunWindow),
        matching: find.byType(GbFormView),
      );
      await tester.tapAt(tester.getTopLeft(form) + const Offset(30, 70));
      await tester.pumpAndSettle();
      expect(find.text('What is your name?'), findsOneWidget);
    });

    test('the examples look as they did: no controls overlap', () {
      for (final MapEntry(key: name, value: files) in exampleProjects.entries) {
        for (final MapEntry(key: file, value: text) in files.entries) {
          if (!file.endsWith('.form.yaml')) continue;
          final controls = readFormFile(text, name: 'Form1').form.controls;
          for (var i = 0; i < controls.length; i++) {
            for (final b in controls.skip(i + 1)) {
              final p = boxOf(controls[i]);
              final q = boxOf(b);
              final apart =
                  p.left + p.width <= q.left ||
                  q.left + q.width <= p.left ||
                  p.top + p.height <= q.top ||
                  q.top + q.height <= p.top;
              expect(
                apart,
                isTrue,
                reason: '$name: ${controls[i].name}, ${b.name}',
              );
            }
          }
        }
      }
    });
  });

  testWidgets('Korean words', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': hello}, strings: IdeStrings.ko),
    );
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    expect(find.text('포인터'), findsOneWidget);
    expect(find.text('격자'), findsOneWidget);
    expect(find.text('폼 파일 보기'), findsOneWidget);
  });
}
