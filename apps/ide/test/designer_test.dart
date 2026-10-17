import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/run/run_window.dart';
import 'package:gubasic_ide/src/strings.dart';

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

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;
  String formText(WidgetTester tester) => current(tester).files[formFile]!;

  Future<void> chooseTool(WidgetTester tester, String type) async {
    await tester.tap(find.byKey(ValueKey('toolbox.$type')));
    // Past the time a second click would make it a double-click.
    await tester.pump(kDoubleTapTimeout);
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
    expect(find.text('Button1'), findsOneWidget, reason: 'drawn');
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
