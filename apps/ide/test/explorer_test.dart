import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// The project explorer (D94): one line for each form, as Visual Basic
/// shows a project, or the files as they are on disk.
void main() {
  Future<void> start(
    WidgetTester tester, {
    IdeStrings s = IdeStrings.en,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: exampleProjects, strings: s, open: 'askname'),
    );
    await tester.pumpAndSettle();
  }

  String? shownFile(WidgetTester tester) {
    final designer = find.byType(FormDesigner);
    if (designer.evaluate().isNotEmpty) {
      return tester.widget<FormDesigner>(designer).file;
    }
    final editor = find.byType(CodeEditor);
    if (editor.evaluate().isNotEmpty) {
      return tester.widget<CodeEditor>(editor).file;
    }
    return null;
  }

  testWidgets('forms first: a line for each form with its Caption and the '
      'startup mark; a click opens the design, a double-click the code', (
    tester,
  ) async {
    await start(tester);
    final form1 = find.byKey(const ValueKey('explorer.form.Form1'));
    final form2 = find.byKey(const ValueKey('explorer.form.Form2'));
    expect(form1, findsOneWidget);
    expect(form2, findsOneWidget);
    expect(
      find.descendant(of: form1, matching: find.text('starts · Greeting')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: form2, matching: find.text('Your name')),
      findsOneWidget,
    );
    // The two files of a form are one line, not two.
    expect(find.text('Form2.form.yaml'), findsNothing);
    expect(find.text('Form2.gbas'), findsNothing);

    await tester.tap(form2);
    await tester.pumpAndSettle();
    expect(shownFile(tester), 'Form2.form.yaml');
    expect(tester.widget<ListTile>(form2).selected, isTrue);
    expect(tester.widget<ListTile>(form1).selected, isFalse);

    // A double-click: the design at once, then the code.
    await tester.tap(form1);
    await tester.pump(const Duration(milliseconds: 50));
    expect(shownFile(tester), 'Form1.form.yaml');
    await tester.tap(form1);
    await tester.pumpAndSettle();
    expect(shownFile(tester), 'Form1.gbas');

    // Two clicks far apart are two clicks.
    await tester.tap(form2);
    await tester.pump(const Duration(seconds: 1));
    await tester.tap(form2);
    await tester.pumpAndSettle();
    expect(shownFile(tester), 'Form2.form.yaml');

    // The buttons open each.
    await tester.tap(explorerItem('Form2.gbas'));
    await tester.pumpAndSettle();
    expect(shownFile(tester), 'Form2.gbas');
    expect(
      tester.widget<IconButton>(explorerItem('Form2.gbas')).isSelected,
      isTrue,
    );
    await tester.tap(explorerItem('Form1.form.yaml'));
    await tester.pumpAndSettle();
    expect(shownFile(tester), 'Form1.form.yaml');
  });

  testWidgets('the project settings are the last line; Files shows the files '
      'on disk, and the choice stays for the next project', (tester) async {
    await start(tester);
    final settings = find.byKey(const ValueKey('explorer.settings'));
    expect(
      find.descendant(of: settings, matching: find.text('AskName.gbproj')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: settings, matching: find.text('Project settings')),
      findsOneWidget,
    );
    await tester.tap(settings);
    await tester.pumpAndSettle();
    expect(shownFile(tester), isNull);
    expect(find.textContaining('startup: Form1'), findsOneWidget);

    await tester.tap(find.text('Files'));
    await tester.pumpAndSettle();
    for (final f in [
      'AskName.gbproj',
      'Form1.form.yaml',
      'Form1.gbas',
      'Form2.form.yaml',
      'Form2.gbas',
    ]) {
      expect(find.text(f), findsOneWidget, reason: f);
    }
    expect(find.byKey(const ValueKey('explorer.form.Form1')), findsNothing);
    await tester.tap(find.text('Form2.gbas'));
    await tester.pumpAndSettle();
    expect(shownFile(tester), 'Form2.gbas');

    // Another project: still the files.
    final shell = tester.widget<IdeShell>(find.byType(IdeShell));
    await shell.controller.choose(
      tester.element(find.byType(IdeShell)),
      'example:hello',
    );
    await tester.pumpAndSettle();
    expect(find.text('Form1.form.yaml'), findsOneWidget);
    expect(find.byKey(const ValueKey('explorer.form.Form1')), findsNothing);

    await tester.tap(find.text('Forms'));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('explorer.form.Form1')), findsOneWidget);
    expect(find.text('Form1.form.yaml'), findsNothing);
  });

  testWidgets('Korean words', (tester) async {
    await start(tester, s: IdeStrings.ko);
    expect(find.text('폼'), findsOneWidget);
    expect(find.text('파일 목록'), findsOneWidget);
    expect(find.text('프로젝트 설정'), findsOneWidget);
    expect(find.byTooltip('디자인 보기'), findsNWidgets(2));
    expect(find.byTooltip('코드 보기'), findsNWidgets(2));
    expect(find.textContaining('시작 · '), findsOneWidget);
  });
}
