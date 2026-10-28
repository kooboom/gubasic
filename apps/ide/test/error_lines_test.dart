import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/code/handlers.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const codeFile = 'Form1.gbas';
  const failing =
      'Sub Form_Load()\n'
      '    Dim a(2) As Integer\n'
      '    a(5) = 1\n'
      'End Sub\n';

  Future<void> open(WidgetTester tester, String code) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'hello': {...hello, codeFile: code},
        },
        strings: s,
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> run(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
  }

  TextEditingController editor(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(codeFieldKey)).controller!;
  String code(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[codeFile]!;

  /// Where the first character of line [line] of [code] is drawn in the
  /// field, on the screen.
  Rect lineText(WidgetTester tester, String code, int line) {
    RenderEditable? editable;
    void visit(RenderObject o) {
      if (o is RenderEditable) {
        editable = o;
      } else {
        o.visitChildren(visit);
      }
    }

    visit(tester.renderObject(find.byKey(codeFieldKey)));
    final start = caretAtLine(code, line);
    final box = editable!
        .getBoxesForSelection(
          TextSelection(baseOffset: start, extentOffset: start + 1),
        )
        .single;
    final r = box.toRect();
    return Rect.fromPoints(
      editable!.localToGlobal(r.topLeft),
      editable!.localToGlobal(r.bottomRight),
    );
  }

  /// Whether [mark] lies behind line [line] of [code] as the field draws
  /// it: the middle of that line's first character is inside it.
  void expectOnLine(WidgetTester tester, Finder mark, String code, int line) {
    final band = tester.getRect(mark);
    final text = lineText(tester, code, line);
    // A character's box reaches a little past its line's slot.
    expect(band.contains(text.center), isTrue, reason: '$band, $text');
    expect(band.height, closeTo(text.height, 1));
  }

  test('the caret for a line goes after its indentation', () {
    expect(caretAtLine(failing, 1), 0);
    expect(caretAtLine(failing, 3), failing.indexOf('a(5)'));
    expect(caretAtLine(failing, 99), failing.length);
  });

  testWidgets('a run-time error: its line is marked, and a click goes '
      'there', (tester) async {
    await open(tester, failing);
    await run(tester);
    final error = find.textContaining('$codeFile, line 3:');
    expect(error, findsOneWidget);
    await tester.tap(error);
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(editor(tester).selection.baseOffset, failing.indexOf('a(5)'));
    final mark = find.byKey(codeErrorLineKey);
    expect(mark, findsOneWidget);
    expectOnLine(tester, mark, failing, 3);

    // A change to the code: the line may be another one now.
    tester.testTextInput.enterText(failing.replaceFirst('a(5)', 'a(1)'));
    await tester.pumpAndSettle();
    expect(mark, findsNothing);
    // Back as it was run: marked again; a new run without the error: not.
    tester.testTextInput.enterText(failing);
    await tester.pumpAndSettle();
    expect(mark, findsOneWidget);
    tester.testTextInput.enterText(failing.replaceFirst('a(5)', 'a(1)'));
    await tester.pumpAndSettle();
    await run(tester);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    expect(mark, findsNothing);
    expect(code(tester), contains('a(1)'));
  });

  testWidgets('an error that stops the start goes to its line too', (
    tester,
  ) async {
    const broken = 'Sub Form_Load()\n    x = \nEnd Sub\n';
    await open(tester, broken);
    await run(tester);
    expect(find.text(s.cannotStart), findsOneWidget);
    await tester.tap(find.textContaining('$codeFile, line 2:').first);
    await tester.pumpAndSettle();
    expect(editor(tester).selection.baseOffset, broken.indexOf('x ='));
    expect(find.byKey(codeErrorLineKey), findsNothing, reason: 'not a run');
  });

  testWidgets('errors that keep the project from starting: their lines are '
      'marked while the code is as it was, gone after a run (D76)', (
    tester,
  ) async {
    const broken =
        'Sub Form_Load()\n'
        '    x = \n'
        '    Dim a As Integer\n'
        '    y = 1\n'
        'End Sub\n';
    await open(tester, broken);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    await run(tester);
    expect(find.text(s.cannotStart), findsOneWidget);
    final line2 = find.byKey(codeProblemLineKey(2));
    final line4 = find.byKey(codeProblemLineKey(4));
    expect(line2, findsOneWidget);
    expect(line4, findsOneWidget, reason: 'y is not declared');
    expect(find.byKey(codeProblemLineKey(3)), findsNothing);
    expectOnLine(tester, line2, broken, 2);
    expectOnLine(tester, line4, broken, 4);

    // A change: the lines may be others now. Back as it was: marked again.
    tester.testTextInput.enterText(broken.replaceFirst('x = ', 'x = 1'));
    await tester.pumpAndSettle();
    expect(line2, findsNothing);
    tester.testTextInput.enterText(broken);
    await tester.pumpAndSettle();
    expect(line2, findsOneWidget);

    // Fixed and run: no marks.
    const fixed =
        'Sub Form_Load()\n'
        '    Dim x As Integer\n'
        '    x = 1\n'
        'End Sub\n';
    tester.testTextInput.enterText(fixed);
    await tester.pumpAndSettle();
    await run(tester);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    expect(find.byKey(codeProblemLineKey(2)), findsNothing);
    expect(find.byKey(codeProblemLineKey(4)), findsNothing);
  });

  /// A long program: [error] on line 280 of 300.
  String long(String error) => [
    'Sub Form_Load()',
    '    Dim a(2) As Integer',
    '    Dim x As Integer',
    for (var i = 4; i < 280; i++) '    x = x + 1',
    '    $error',
    for (var i = 281; i < 300; i++) '    x = x + 1',
    'End Sub',
  ].join('\n');

  /// Whether [mark] shows inside the code editor's view, not scrolled
  /// away.
  void expectInView(WidgetTester tester, Finder mark) {
    final view = tester.getRect(
      find.descendant(
        of: find.byType(CodeEditor),
        matching: find.byType(Scrollbar),
      ),
    );
    final rect = tester.getRect(mark);
    expect(rect.top, greaterThanOrEqualTo(view.top));
    expect(rect.bottom, lessThanOrEqualTo(view.bottom));
  }

  Color flashColour(WidgetTester tester) => tester
      .widget<ColoredBox>(
        find.descendant(
          of: find.byKey(codeFlashLineKey),
          matching: find.byType(ColoredBox),
        ),
      )
      .color;

  testWidgets('far down a long file: a click on a run-time error scrolls to '
      'its line and lights it for a moment (D70)', (tester) async {
    final code = long('a(5) = 1');
    await open(tester, code);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    await run(tester);
    await tester.tap(find.textContaining('$codeFile, line 280:'));
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(editor(tester).selection.baseOffset, code.indexOf('a(5)'));
    expectInView(tester, find.byKey(codeErrorLineKey));
    expectInView(tester, find.byKey(codeFlashLineKey));
    // Level with the line, however high a line is drawn.
    expectOnLine(tester, find.byKey(codeFlashLineKey), code, 280);
    expectOnLine(tester, find.byKey(codeErrorLineKey), code, 280);
    expect(flashColour(tester).a, greaterThan(0.2));
    await tester.pumpAndSettle();
    expect(flashColour(tester).a, 0, reason: 'faded out');
  });

  testWidgets('far down a long file: an error that stops the start scrolls '
      'to its line too', (tester) async {
    final code = long('y = ');
    await open(tester, code);
    await tester.tap(explorerItem(codeFile));
    await tester.pumpAndSettle();
    await run(tester);
    await tester.tap(find.textContaining('$codeFile, line 280:').first);
    await tester.pumpAndSettle();
    expect(editor(tester).selection.baseOffset, code.indexOf('y ='));
    expectInView(tester, find.byKey(codeFlashLineKey));
  });

  testWidgets('Korean words', (tester) async {
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'hello': {...hello, codeFile: failing},
        },
        strings: IdeStrings.ko,
      ),
    );
    await tester.pumpAndSettle();
    await run(tester);
    expect(find.textContaining('$codeFile 파일 3번째 줄:'), findsOneWidget);
    expect(find.byTooltip('$codeFile 파일 3번째 줄로 갑니다'), findsOneWidget);
  });
}
