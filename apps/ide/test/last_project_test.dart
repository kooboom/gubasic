import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/last_project.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/fake_browser.dart';
import 'support/memory_folders.dart';

/// The IDE opens the project open last when it starts (D62): on the web
/// one kept in the browser or an example, on the desktop one on disk.
void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;

  Future<void> startDesktop(
    WidgetTester tester,
    MemoryFolders fs,
    LastProject last,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        folders: fs,
        lastProject: last,
        pickers: ProjectPickers(
          openProjectFile: (_) async => '/home/Fruit/Fruit.gbproj',
          saveLocation: (_, _) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> startWeb(
    WidgetTester tester,
    FakeBrowser browser,
    LastProject last,
  ) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        lastProject: last,
        pickZip: () async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;

  MemoryFolders fruit() => MemoryFolders()
    ..folders.add('/home')
    ..add('/home/Fruit', {
      'Fruit.gbproj':
          'formatVersion: 1\nname: Fruit\nstartup: Form1\nforms:\n  - Form1\n',
      'Form1.form.yaml': hello['Form1.form.yaml']!,
      'Form1.gbas': hello['Form1.gbas']!,
    });

  testWidgets('a project opened from disk is remembered, and opened again '
      'when the IDE starts', (tester) async {
    final fs = fruit();
    final last = MemoryLastProject();
    await startDesktop(tester, fs, last);
    expect(current(tester).project.name, 'Hello');

    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.open).last);
    await tester.pumpAndSettle();
    expect(current(tester).project.name, 'Fruit');
    expect(last.value, 'folder:/home/Fruit/Fruit.gbproj');

    // The IDE again, as after quitting it.
    await tester.pumpWidget(const SizedBox());
    await startDesktop(tester, fs, last);
    expect(current(tester).project.name, 'Fruit');
    expect(current(tester).location, isA<FolderLocation>());
  });

  testWidgets('a project no longer on disk: hello, and a word why', (
    tester,
  ) async {
    await startDesktop(
      tester,
      MemoryFolders(),
      MemoryLastProject('folder:/home/Gone/Gone.gbproj'),
    );
    expect(current(tester).project.name, 'Hello');
    expect(
      find.text(s.lastProjectGone.replaceAll('{0}', '/home/Gone/Gone.gbproj')),
      findsOneWidget,
    );
  });

  testWidgets('an example chosen last is opened again', (tester) async {
    final last = MemoryLastProject();
    await startDesktop(tester, MemoryFolders(), last);
    await tester.tap(find.text('hello').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('quiz').last);
    await tester.pumpAndSettle();
    expect(last.value, 'example:quiz');

    await tester.pumpWidget(const SizedBox());
    await startDesktop(tester, MemoryFolders(), last);
    expect(current(tester).project.name, 'Quiz');
  });

  testWidgets('on the web, the project kept in the browser opens again after '
      'a reload; a deleted one leaves hello', (tester) async {
    final browser = FakeBrowser();
    final kept = await BrowserProjects.open(browser.projects, browser.storage);
    await kept.save('My Quiz', {
      ...hello,
      'Hello.gbproj': 'formatVersion: 1\nname: My Quiz\nstartup: Form1\nforms:\n  - Form1\n',
    });
    final last = MemoryLastProject('browser:My Quiz');
    await startWeb(tester, browser, last);
    expect(current(tester).project.name, 'My Quiz');
    expect(current(tester).location, isA<BrowserLocation>());

    await tester.pumpWidget(const SizedBox());
    await startWeb(tester, FakeBrowser(), MemoryLastProject('browser:Gone'));
    expect(current(tester).project.name, 'Hello');
    expect(
      find.text(s.lastProjectGone.replaceAll('{0}', 'Gone')),
      findsOneWidget,
    );
  });

  test('the web keeps it in localStorage, under its own key', () async {
    final storage = MemoryStorage();
    await StorageLastProject(storage).write('example:quiz');
    expect(storage.values, {lastProjectKey: 'example:quiz'});
    expect(await StorageLastProject(storage).read(), 'example:quiz');
  });
}
