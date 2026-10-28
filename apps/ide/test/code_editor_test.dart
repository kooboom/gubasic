import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_controller.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/code/code_font.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_ide/src/theme.dart';

import 'support/explorer.dart';

void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const codeFile = 'Form1.gbas';

  Future<void> open(WidgetTester tester, {String? code}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'hello': {...hello, codeFile: ?code},
        },
        strings: s,
      ),
    );
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;
  String file(WidgetTester tester) => current(tester).files[codeFile]!;
  TextEditingController controller(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(codeFieldKey)).controller!;

  Future<void> type(WidgetTester tester, TextEditingValue value) async {
    tester.testTextInput.updateEditingValue(value);
    await tester.pump();
  }

  Future<void> key(
    WidgetTester tester,
    LogicalKeyboardKey k, {
    bool shift = false,
    bool control = false,
  }) async {
    if (control) await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(k);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    if (control) await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  group('colours from the lexer', () {
    String marks(String text, [Set<String> controls = const {}]) =>
        codeKinds(text, controls).map((k) => 'pkscnC'[k]).join();

    test('keywords, strings, comments, numbers and controls', () {
      const code = 'If x = 12 Then btnOk.Caption = "a\'b" \' 한글';
      expect(
        marks(code, {'btnok'}),
        'kk p p nn kkkk CCCCCpppppppp p sssss cccc'.replaceAll(' ', 'p'),
      );
    });

    test('a string or comment being typed is coloured as one', () {
      expect(marks('x = "한'), 'ppppss');
      expect(marks("' 한글 ㄱ"), 'cccccc');
    });
  });

  testWidgets('the editor shows the code; typing writes the file', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(controller(tester).text, hello[codeFile]);
    await tester.tap(find.byKey(codeFieldKey));
    await tester.pump();
    await tester.enterText(find.byKey(codeFieldKey), "' new\n");
    await tester.pump();
    expect(file(tester), "' new\n");
    expect(find.text('Hello — Edited'), findsOneWidget);
  });

  testWidgets('the code font loads when the editor first opens', (
    tester,
  ) async {
    CodeFont.reset();
    addTearDown(CodeFont.reset);
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdeApp(projects: {'hello': hello}, strings: s));
    await tester.pumpAndSettle();
    expect(CodeFont.loaded.value, isFalse, reason: 'not on the first view');
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    await tester.runAsync(() => CodeFont.load());
    await tester.pumpAndSettle();
    expect(CodeFont.loaded.value, isTrue);
    expect(codeStyle.fontFamily, CodeFont.family);
    expect(
      tester.widget<TextField>(find.byKey(codeFieldKey)).style!.fontFamily,
      CodeFont.family,
    );
  });

  testWidgets('Tab goes to the next stop; Shift+Tab takes it back', (
    tester,
  ) async {
    await open(tester, code: 'ab\ncd\n');
    await tester.tap(find.byKey(codeFieldKey));
    await tester.pump();
    controller(tester).selection = const TextSelection.collapsed(offset: 1);
    await key(tester, LogicalKeyboardKey.tab);
    expect(file(tester), 'a   b\ncd\n', reason: 'to column 4');
    expect(controller(tester).selection.baseOffset, 4);
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>(),
      isNotNull,
      reason: 'the focus stays',
    );

    // Several lines: each one.
    controller(tester).selection = const TextSelection(
      baseOffset: 0,
      extentOffset: 8,
    );
    await key(tester, LogicalKeyboardKey.tab);
    expect(file(tester), '    a   b\n    cd\n');
    await key(tester, LogicalKeyboardKey.tab, shift: true);
    expect(file(tester), 'a   b\ncd\n');
  });

  testWidgets('Enter keeps the indentation of the line', (tester) async {
    await open(tester, code: 'Sub x()\n    y = 1\nEnd Sub\n');
    await tester.tap(find.byKey(codeFieldKey));
    await tester.pump();
    const before = 'Sub x()\n    y = 1';
    controller(tester).selection = const TextSelection.collapsed(
      offset: before.length,
    );
    await tester.pump();
    await type(
      tester,
      const TextEditingValue(
        text: '$before\n\nEnd Sub\n',
        selection: TextSelection.collapsed(offset: before.length + 1),
      ),
    );
    expect(file(tester), '$before\n    \nEnd Sub\n');
    expect(controller(tester).selection.baseOffset, before.length + 5);
  });

  testWidgets('⌘Z / Ctrl+Z undoes the typing', (tester) async {
    await open(tester, code: 'x = 1\n');
    await tester.tap(find.byKey(codeFieldKey));
    await tester.pump();
    await tester.enterText(find.byKey(codeFieldKey), 'x = 12\n');
    await tester.pump(const Duration(seconds: 1));
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(file(tester), 'x = 1\n');
    await key(tester, LogicalKeyboardKey.keyZ, control: true, shift: true);
    expect(file(tester), 'x = 12\n');
  });

  testWidgets('read-only while the program runs', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(find.byKey(codeFieldKey)).readOnly, isTrue);
    await tester.enterText(find.byKey(codeFieldKey), 'changed');
    await tester.pump();
    expect(file(tester), hello[codeFile]);
  });

  testWidgets('a change made elsewhere shows', (tester) async {
    await open(tester);
    current(tester).setFile(codeFile, "' from elsewhere\n");
    await tester.pumpAndSettle();
    expect(controller(tester).text, "' from elsewhere\n");
  });

  testWidgets('F5 works after going from the form to the code', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdeApp(projects: {'hello': hello}, strings: s));
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsNothing, reason: 'the form first');
    for (final f in [codeFile, 'Hello.gbproj']) {
      await tester.tap(explorerItem(f));
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Stop (Shift+F5)'),
            )
            .onPressed,
        isNotNull,
        reason: 'running, from $f',
      );
      await tester.tap(find.text('Stop (Shift+F5)'));
      await tester.pumpAndSettle();
    }
  });

  for (final via in ['the run window', 'the code', 'the code, then back']) {
    testWidgets('Shift+F5 stops the program, looking at $via', (tester) async {
      await open(tester);
      bool running() =>
          tester
              .widget<TextButton>(
                find.widgetWithText(TextButton, 'Stop (Shift+F5)'),
              )
              .onPressed !=
          null;
      await tester.sendKeyEvent(LogicalKeyboardKey.f5);
      await tester.pumpAndSettle();
      expect(running(), isTrue, reason: 'F5 from the code editor');
      if (via != 'the run window') {
        await tester.tap(explorerItem(codeFile));
        await tester.pumpAndSettle();
      }
      if (via == 'the code, then back') {
        await tester.tap(find.text(s.runWindow));
        await tester.pumpAndSettle();
      }
      await key(tester, LogicalKeyboardKey.f5, shift: true);
      expect(running(), isFalse);
    });
  }

  testWidgets('after a run, choosing the code gives it the focus', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.f5, shift: true);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    expect(
      FocusManager.instance.primaryFocus?.context
          ?.findAncestorWidgetOfExactType<TextField>(),
      isNotNull,
    );
  });

  testWidgets('a run keeps the caret and the undo history', (tester) async {
    await open(tester, code: 'x = 1\n');
    await tester.tap(find.byKey(codeFieldKey));
    await tester.pump();
    await tester.enterText(find.byKey(codeFieldKey), 'x = 12\n');
    await tester.pump(const Duration(seconds: 1));
    TextEditingController c() => tester
        .widget<TextField>(find.byKey(codeFieldKey, skipOffstage: false))
        .controller!;
    c().selection = const TextSelection.collapsed(offset: 3);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await key(tester, LogicalKeyboardKey.f5, shift: true);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    expect(c().selection, const TextSelection.collapsed(offset: 3));
    await key(tester, LogicalKeyboardKey.keyZ, control: true);
    expect(file(tester), 'x = 1\n', reason: 'the typing before the run');
  });

  testWidgets('the edited code runs', (tester) async {
    await open(tester, code: 'Sub Form_Load()\nEnd Sub\n');
    await tester.tap(find.byKey(codeFieldKey));
    await tester.enterText(
      find.byKey(codeFieldKey),
      'Sub Form_Load()\n    Debug.Print("편집됨")\nEnd Sub\n',
    );
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.text('편집됨'), findsOneWidget, reason: 'the output');
  });
}
