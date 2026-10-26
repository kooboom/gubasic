import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/pictures_dialog.dart';
import 'package:gubasic_ide/src/project/project_pictures.dart';
import 'package:gubasic_player/gubasic_player.dart';
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
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Hello')),
      findsOneWidget,
      reason: 'the project name',
    );

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

  testWidgets('MsgBox and InputBox without a title show the project\'s name '
      '(D68)', (tester) async {
    await open(tester, hello);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    Finder title(String text) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.text(text),
    );
    expect(title('Hello'), findsOneWidget, reason: 'the InputBox');
    await tester.enterText(find.byType(TextField), 'Kim');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Kim! (1)'), findsOneWidget);
    expect(title('Hello'), findsOneWidget, reason: 'the MsgBox');
  });

  testWidgets('the open file is in the accent colour; the pictures are a '
      'group that opens File → Pictures (D68)', (tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        examplePictures: decodeExamplePictures(examplePictures),
        strings: IdeStrings.en,
        open: 'quiz',
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Form1.gbas'));
    await tester.pumpAndSettle();
    final tile = tester.widget<ListTile>(
      find.ancestor(
        of: find.text('Form1.gbas'),
        matching: find.byType(ListTile),
      ),
    );
    final scheme = Theme.of(tester.element(find.byType(IdeShell))).colorScheme;
    expect(tile.selected, isTrue);
    expect(tile.selectedColor, scheme.primary);

    expect(find.byKey(const ValueKey('files.pictures')), findsOneWidget);
    expect(find.text('triangle.png'), findsOneWidget);
    expect(find.text('pentagon.png'), findsOneWidget);
    await tester.tap(find.text('triangle.png'));
    await tester.pumpAndSettle();
    expect(find.byType(PicturesDialog), findsOneWidget);
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

  /// Runs hello up to its MsgBox: click, a name in the InputBox, OK.
  Future<void> upToMsgBox(WidgetTester tester) async {
    await open(tester, hello);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Ann');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Ann! (1)'), findsOneWidget, reason: 'MsgBox');
  }

  testWidgets('a MsgBox blocks the form, not the IDE', (tester) async {
    await upToMsgBox(tester);
    expect(find.text('Say hello').hitTestable(), findsNothing);
    expect(find.text('Form1.gbas').hitTestable(), findsOneWidget);
    expect(find.text('Stop (Shift+F5)').hitTestable(), findsOneWidget);
  });

  testWidgets('a MsgBox is still there after looking at a file', (
    tester,
  ) async {
    await upToMsgBox(tester);
    await tester.tap(find.text('Form1.form.yaml'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Ann! (1)'), findsNothing);
    expect(find.byType(FormDesigner), findsOneWidget, reason: 'the file');

    await tester.tap(find.text('Run window'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Ann! (1)'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Ann! (1)'), findsNothing);
    expect(find.text('Say hello').hitTestable(), findsOneWidget);
  });

  for (final where in ['the run window', 'a file']) {
    testWidgets('Stop with a MsgBox open, looking at $where', (tester) async {
      await upToMsgBox(tester);
      if (where == 'a file') {
        await tester.tap(find.text('Form1.gbas'));
        await tester.pumpAndSettle();
      }
      await tester.tap(find.text('Stop (Shift+F5)'));
      await tester.pumpAndSettle();
      expect(find.text('Hello, Ann! (1)', skipOffstage: false), findsNothing);
      expect(find.byType(RunWindow, skipOffstage: false), findsNothing);
      expect(find.text('Run window'), findsNothing);
      expect(find.text(IdeStrings.en.stopped), findsOneWidget);
    });
  }

  testWidgets('files are read-only while a program runs', (tester) async {
    await upToMsgBox(tester);
    await tester.tap(find.text('Form1.gbas'));
    await tester.pumpAndSettle();
    final shown = tester.widgetList<EditableText>(find.byType(EditableText));
    expect(shown, isNotEmpty);
    expect(shown.every((e) => e.readOnly), isTrue);
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
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Hello')),
      findsOneWidget,
    );
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('typing').last);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(AppBar), matching: find.text('Typing')),
      findsOneWidget,
    );
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
