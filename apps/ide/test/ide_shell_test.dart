import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/run/run_window.dart';
import 'package:gubasic_ide/src/strings.dart';

void main() {
  Future<void> open(
    WidgetTester tester,
    Map<String, String> files, {
    IdeStrings strings = IdeStrings.en,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': files}, strings: strings),
    );
  }

  final hello = exampleProjects['hello']!;
  final typing = exampleProjects['typing']!;

  testWidgets('F5 runs hello: click, InputBox, MsgBox, close', (tester) async {
    await open(tester, hello);
    expect(find.text('Hello'), findsOneWidget, reason: 'the project name');

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsOneWidget);
    expect(find.text('Press the button'), findsOneWidget);

    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(find.text('What is your name?'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '구정모');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, 구정모! (1)'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(runWindowCloseKey));
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsNothing);
    expect(find.text(IdeStrings.en.closed), findsOneWidget);
  });

  testWidgets('typing in the TextBox runs Changed', (tester) async {
    await open(tester, typing);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '한글');
    await tester.pumpAndSettle();
    expect(find.text('Hello, 한글'), findsOneWidget);
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, 한글! (1)'), findsOneWidget);
  });

  testWidgets('Stop ends a program waiting in a dialog', (tester) async {
    await open(tester, hello);
    await tester.tap(find.text('Run (F5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(find.text('What is your name?'), findsOneWidget);

    // The dialog blocks the form, not the IDE's Stop button.
    await tester.tap(find.text('Stop (Shift+F5)'));
    await tester.pumpAndSettle();
    expect(find.text('What is your name?'), findsNothing);
    expect(find.byType(RunWindow), findsNothing);
    expect(find.text(IdeStrings.en.stopped), findsOneWidget);
  });

  testWidgets('Korean: dialog buttons and messages', (tester) async {
    await open(tester, hello, strings: IdeStrings.ko);
    await tester.tap(find.text('실행 (F5)'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    expect(find.text('확인'), findsOneWidget);
    expect(find.text('취소'), findsOneWidget);
    await tester.tap(find.text('취소'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, ! (1)'), findsOneWidget);
  });

  testWidgets('the menu opens another project', (tester) async {
    await tester.pumpWidget(
      IdeApp(projects: exampleProjects, strings: IdeStrings.en),
    );
    expect(find.text('Hello'), findsOneWidget);
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('typing').last);
    await tester.pumpAndSettle();
    expect(find.text('Typing'), findsOneWidget);
  });

  testWidgets('a project with errors does not start', (tester) async {
    await open(tester, {
      ...hello,
      'Form1.gbas': 'Sub Form_Load()\n    Dim x As Integer = "a"\nEnd Sub\n',
    });
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsNothing);
    expect(find.text(IdeStrings.en.cannotStart), findsOneWidget);
    expect(find.textContaining('Form1.gbas, line 2: '), findsOneWidget);
  });

  testWidgets('a run-time error names the file and the line', (tester) async {
    await open(tester, {
      ...hello,
      'Form1.gbas':
          'Sub Form_Load()\n    Dim n As Integer = 0\n'
          '    Debug.Print(1 \\ n)\nEnd Sub\n',
    });
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsNothing);
    expect(find.textContaining('Form1.gbas, line 3: '), findsOneWidget);
  });
}
