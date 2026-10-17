import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/code/handlers.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

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
    final field = tester.getTopLeft(find.byKey(codeFieldKey));
    expect(
      tester.getTopLeft(mark).dy - field.dy,
      2 * codeFontSize * codeLineHeight,
    );

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
    await tester.tap(find.text(codeFile));
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
