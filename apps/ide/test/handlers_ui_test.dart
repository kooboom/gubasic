import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const formFile = 'Form1.form.yaml';
  const codeFile = 'Form1.gbas';

  Future<void> open(WidgetTester tester, {IdeStrings strings = s}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': hello}, strings: strings),
    );
    await tester.pumpAndSettle();
  }

  String code(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[codeFile]!;
  TextEditingController editor(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(codeFieldKey)).controller!;

  /// The line the caret is on.
  String caretLine(WidgetTester tester) {
    final c = editor(tester);
    final at = c.selection.baseOffset;
    final start = c.text.lastIndexOf('\n', at - 1) + 1;
    final end = c.text.indexOf('\n', at);
    return c.text.substring(start, end < 0 ? c.text.length : end);
  }

  String lineBefore(WidgetTester tester) {
    final c = editor(tester);
    final at = c.selection.baseOffset;
    final start = c.text.lastIndexOf('\n', at - 1) + 1;
    final before = c.text.lastIndexOf('\n', start - 2) + 1;
    return c.text.substring(before, start - 1);
  }

  Future<void> doubleClick(WidgetTester tester, Offset at) async {
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.tapAt(origin + at, kind: PointerDeviceKind.mouse);
    await tester.pump(kDoubleTapMinTime);
    await tester.tapAt(origin + at, kind: PointerDeviceKind.mouse);
    await tester.pumpAndSettle();
  }

  Future<void> placeFromToolbox(WidgetTester tester, String type) async {
    final tool = find.byKey(ValueKey('toolbox.$type'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('a double-click goes to the handler that is there', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(FormDesigner), findsOneWidget);
    await doubleClick(tester, const Offset(30, 70));
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(lineBefore(tester), 'Sub btnHello_Click()');
    expect(code(tester), hello[codeFile], reason: 'nothing added');
  });

  testWidgets('the empty form goes to Form_Load', (tester) async {
    await open(tester);
    await doubleClick(tester, const Offset(250, 100));
    expect(lineBefore(tester), 'Sub Form_Load()');
  });

  testWidgets('a new control gets its handler, the caret inside', (
    tester,
  ) async {
    await open(tester);
    await placeFromToolbox(tester, 'Button');
    // Button1 lands below btnHello, which is in the middle: Left 112,
    // Top 88 (D68).
    await doubleClick(tester, const Offset(150, 100));
    expect(
      code(tester),
      '${hello[codeFile]}\nSub Button1_Click()\n    \nEnd Sub\n',
    );
    expect(lineBefore(tester), 'Sub Button1_Click()');
    expect(caretLine(tester), '    ');
    // The editor has the focus: typing goes into the handler.
    tester.testTextInput.enterText(
      '${hello[codeFile]}\nSub Button1_Click()\n    MsgBox("1")\nEnd Sub\n',
    );
    await tester.pump();
    expect(code(tester), contains('    MsgBox("1")\n'));
  });

  testWidgets('a TextBox gets Changed', (tester) async {
    await open(tester);
    await placeFromToolbox(tester, 'TextBox');
    // TextBox1: Left 80, Top 88, 160 x 32.
    await doubleClick(tester, const Offset(150, 100));
    expect(lineBefore(tester), 'Sub TextBox1_Changed()');
  });

  testWidgets('while running, only a handler that is there opens', (
    tester,
  ) async {
    await open(tester);
    await placeFromToolbox(tester, 'Button');
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    await doubleClick(tester, const Offset(150, 100));
    expect(
      find.text(s.noHandlerWhileRunning.replaceAll('{0}', 'Button1_Click')),
      findsOneWidget,
    );
    expect(find.byType(FormDesigner), findsOneWidget, reason: 'stays');
    await tester.pump(const Duration(seconds: 1));
    await doubleClick(tester, const Offset(30, 70));
    expect(lineBefore(tester), 'Sub btnHello_Click()');
    expect(code(tester), hello[codeFile]);
  });

  testWidgets('the lists choose an object and its event', (tester) async {
    await open(tester);
    await tester.tap(find.text(codeFile));
    await tester.pumpAndSettle();
    // The caret in Form_Load: the lists follow it.
    final c = editor(tester);
    c.selection = TextSelection.collapsed(
      offset: c.text.indexOf('lblMessage.Caption'),
    );
    await tester.pumpAndSettle();
    DropdownButton<String> list(Key key) =>
        tester.widget<DropdownButton<String>>(find.byKey(key));
    expect(list(codeObjectsKey).value, 'Form');
    expect(list(codeEventsKey).value, 'Form_Load');

    // lblMessage, Click: a new handler.
    await tester.tap(find.byKey(codeObjectsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lblMessage').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(codeEventsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Click').last);
    await tester.pumpAndSettle();
    expect(code(tester), contains('Sub lblMessage_Click()\n    \nEnd Sub\n'));
    expect(lineBefore(tester), 'Sub lblMessage_Click()');
    expect(list(codeObjectsKey).value, 'lblMessage');

    // (General), (Declarations): the top of the code.
    await tester.tap(find.byKey(codeObjectsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.generalObject).last);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(codeEventsKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.declarations).last);
    await tester.pumpAndSettle();
    expect(editor(tester).selection.baseOffset, 0);
  });

  testWidgets('the handler made can be undone in one step', (tester) async {
    await open(tester);
    await placeFromToolbox(tester, 'Button');
    await doubleClick(tester, const Offset(150, 100));
    expect(code(tester), contains('Sub Button1_Click()'));
    await tester.pump(const Duration(seconds: 1));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(code(tester), hello[codeFile]);
  });

  testWidgets('Korean words', (tester) async {
    await open(tester, strings: IdeStrings.ko);
    await tester.tap(find.text(codeFile));
    await tester.pumpAndSettle();
    final c = editor(tester);
    c.selection = const TextSelection.collapsed(offset: 0);
    await tester.pumpAndSettle();
    expect(find.text('(일반)'), findsOneWidget);
  });
}
