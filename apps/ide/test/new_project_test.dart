import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/new_project.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/fake_browser.dart';
import 'support/memory_folders.dart';

/// File → New Project (D63): a name, the form's Caption and size; on the
/// desktop a folder chosen at once, on the web kept in the browser.
void main() {
  const s = IdeStrings.en;

  late MemoryFolders fs;
  late List<String?> saves;

  setUp(() {
    fs = MemoryFolders()..folders.add('/home');
    saves = [];
  });

  Future<void> startDesktop(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        folders: fs,
        pickers: ProjectPickers(
          openProjectFile: (_) async => null,
          saveLocation: (_, _) async => saves.removeAt(0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;

  Future<void> openDialog(WidgetTester tester) async {
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.newProject')));
    await tester.pumpAndSettle();
  }

  Future<void> create(WidgetTester tester) async {
    await tester.tap(find.widgetWithText(FilledButton, s.createButton));
    await tester.pumpAndSettle();
  }

  testWidgets('on the desktop: a folder is chosen at once, the form is empty '
      'with the name as its Caption, at the size chosen', (tester) async {
    await startDesktop(tester);
    await openDialog(tester);
    expect(
      find.widgetWithText(FilledButton, s.createButton).evaluate().single,
      isA<Element>(),
    );
    await tester.enterText(find.byKey(newProjectNameKey), 'Quiz Two');
    await tester.pump();
    expect(
      tester
          .widget<TextField>(find.byKey(newProjectCaptionKey))
          .controller!
          .text,
      'Quiz Two',
      reason: 'the Caption follows the name',
    );
    await tester.tap(find.textContaining(s.phonePreset));
    await tester.pump();
    saves.add('/home/Quiz Two');
    await create(tester);

    final project = readProjectFile(fs.files['/home/Quiz Two/Quiz Two.gbproj']!)
        .project;
    expect(project.name, 'Quiz Two');
    final form = readFormFile(
      fs.files['/home/Quiz Two/Form1.form.yaml']!,
      name: 'Form1',
    ).form;
    expect(form.valueOf('Caption'), 'Quiz Two');
    expect((form.valueOf('Width'), form.valueOf('Height')), (360, 800));
    expect(form.controls, isEmpty);
    expect(fs.files['/home/Quiz Two/Form1.gbas'], '');
    expect(current(tester).location, isA<FolderLocation>());
    expect(current(tester).isDirty, isFalse);
    expect(find.text('Quiz Two'), findsWidgets);
  });

  testWidgets('a Caption typed is kept; Desktop is the size unless chosen; '
      'Cancel in the folder dialog makes nothing', (tester) async {
    await startDesktop(tester);
    await openDialog(tester);
    await tester.enterText(find.byKey(newProjectCaptionKey), '나의 퀴즈');
    await tester.enterText(find.byKey(newProjectNameKey), 'MyQuiz');
    await tester.pump();
    saves.add(null);
    await create(tester);
    expect(fs.files, isEmpty);
    expect(current(tester).project.name, 'Hello');

    await openDialog(tester);
    await tester.enterText(find.byKey(newProjectCaptionKey), '나의 퀴즈');
    await tester.enterText(find.byKey(newProjectNameKey), 'MyQuiz');
    await tester.pump();
    saves.add('/home/MyQuiz');
    await create(tester);
    final form = readFormFile(
      fs.files['/home/MyQuiz/Form1.form.yaml']!,
      name: 'Form1',
    ).form;
    expect(form.valueOf('Caption'), '나의 퀴즈');
    expect((form.valueOf('Width'), form.valueOf('Height')), (800, 600));
  });

  testWidgets('a name a project cannot have cannot be created', (tester) async {
    await startDesktop(tester);
    await openDialog(tester);
    await tester.enterText(find.byKey(newProjectNameKey), 'a/b');
    await tester.pump();
    expect(find.text(s.badProjectName), findsOneWidget);
    expect(
      tester
          .widget<FilledButton>(
            find.widgetWithText(FilledButton, s.createButton),
          )
          .onPressed,
      isNull,
    );
  });

  testWidgets('unsaved changes are asked about first', (tester) async {
    await startDesktop(tester);
    current(tester).setFile('Form1.gbas', "' changed\n");
    await tester.pump();
    await openDialog(tester);
    expect(find.text(s.unsaved.replaceAll('{0}', 'Hello')), findsOneWidget);
  });

  testWidgets('on the web: kept in the browser at once, with the notice; a '
      'name kept already is asked again', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final browser = FakeBrowser();
    final kept = await BrowserProjects.open(browser.projects, browser.storage);
    await kept.save('Taken', exampleProjects['hello']!);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        browser: browser,
        kept: kept,
        pickZip: () async => null,
      ),
    );
    await tester.pumpAndSettle();

    await openDialog(tester);
    await tester.enterText(find.byKey(newProjectNameKey), 'Taken');
    await tester.pump();
    await create(tester);
    expect(
      find.text(s.projectExistsInBrowser.replaceAll('{0}', 'Taken')),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byKey(newProjectNameKey), 'Fresh');
    await tester.pump();
    await create(tester);
    expect(find.text(s.browserNotice), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(current(tester).location, isA<BrowserLocation>());
    expect(current(tester).project.name, 'Fresh');
    expect(browser.projects.records, contains('fresh'));
  });
}
