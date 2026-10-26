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

/// On the web, when the IDE starts with an example and projects are kept
/// in the browser, a bar says so and opens their list (D74).
void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;

  /// The web IDE, with [names] kept in the browser and [last] remembered.
  Future<void> startWeb(
    WidgetTester tester, {
    List<String> names = const [],
    String? last,
    IdeStrings strings = s,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final browser = FakeBrowser();
    final kept = await BrowserProjects.open(browser.projects, browser.storage);
    for (final name in names) {
      await kept.save(name, {
        ...hello,
        'Hello.gbproj':
            'formatVersion: 1\nname: $name\nstartup: Form1\nforms:\n  - Form1\n',
      });
    }
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: strings,
        browser: browser,
        kept: kept,
        lastProject: MemoryLastProject(last),
        pickZip: () async => null,
      ),
    );
    await tester.pumpAndSettle();
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;

  testWidgets('nothing remembered, two kept: the bar says so; Open one '
      'shows them, and the one chosen opens', (tester) async {
    await startWeb(tester, names: ['Quiz', 'Fruit']);
    expect(current(tester).project.name, 'Hello', reason: 'hello still opens');
    expect(find.byKey(keptBarKey), findsOneWidget);
    expect(find.text(s.keptMany.replaceAll('{0}', '2')), findsOneWidget);
    await tester.tap(find.text(s.keptOpen));
    await tester.pumpAndSettle();
    expect(find.byKey(keptBarKey), findsNothing);
    expect(find.text(s.keptProjectsTitle), findsOneWidget);
    await tester.tap(find.text('Fruit'));
    await tester.pumpAndSettle();
    expect(current(tester).project.name, 'Fruit');
    expect(current(tester).location, isA<BrowserLocation>());
  });

  testWidgets('an example remembered, one kept: the bar too; Close closes '
      'it', (tester) async {
    await startWeb(tester, names: ['Quiz'], last: 'example:hello');
    expect(find.text(s.keptOne), findsOneWidget);
    await tester.tap(find.text(s.keptDismiss));
    await tester.pumpAndSettle();
    expect(find.byKey(keptBarKey), findsNothing);
    expect(current(tester).project.name, 'Hello');
  });

  testWidgets('another project opened closes the bar', (tester) async {
    await startWeb(tester, names: ['Quiz']);
    expect(find.byKey(keptBarKey), findsOneWidget);
    await tester.tap(find.text('hello'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('quiz').last);
    await tester.pumpAndSettle();
    expect(current(tester).project.name, isNot('Hello'));
    expect(find.byKey(keptBarKey), findsNothing);
  });

  testWidgets('no bar when a kept project is remembered, or none is kept', (
    tester,
  ) async {
    await startWeb(tester, names: ['Quiz'], last: 'browser:Quiz');
    expect(current(tester).project.name, 'Quiz');
    expect(find.byKey(keptBarKey), findsNothing);

    await tester.pumpWidget(const SizedBox());
    await startWeb(tester);
    expect(find.byKey(keptBarKey), findsNothing);
  });

  testWidgets('no bar on the desktop', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        folders: MemoryFolders(),
        lastProject: MemoryLastProject(),
        pickers: ProjectPickers(
          openProjectFile: (_) async => null,
          saveLocation: (_, _) async => null,
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(keptBarKey), findsNothing);
  });

  testWidgets('the project menu lists every project kept in the browser, '
      'the last saved first; choosing one opens it (D78)', (tester) async {
    await startWeb(tester, names: ['Quiz', 'Fruit'], last: 'browser:Quiz');
    expect(current(tester).project.name, 'Quiz');
    // The project menu, not the Properties window's list.
    final menu = find.descendant(
      of: find.byType(AppBar),
      matching: find.byType(DropdownButton<String>),
    );
    await tester.tap(menu);
    await tester.pumpAndSettle();
    // Fruit was kept after Quiz: above it, after the examples.
    final fruit = tester.getTopLeft(find.text('Fruit').last).dy;
    final quiz = tester.getTopLeft(find.text('Quiz').last).dy;
    final hello = tester.getTopLeft(find.text('hello').last).dy;
    expect(hello, lessThan(fruit));
    expect(fruit, lessThan(quiz));
    await tester.tap(find.text('Fruit').last);
    await tester.pumpAndSettle();
    expect(current(tester).project.name, 'Fruit');
    expect(current(tester).location, isA<BrowserLocation>());

    await tester.tap(menu);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Quiz').last);
    await tester.pumpAndSettle();
    expect(current(tester).project.name, 'Quiz');
  });

  testWidgets('Korean words', (tester) async {
    await startWeb(
      tester,
      names: ['Quiz', 'Fruit', 'Clock'],
      strings: IdeStrings.ko,
    );
    expect(find.text('이 브라우저에 보관된 프로젝트가 3개 있습니다.'), findsOneWidget);
    expect(find.text('열기'), findsWidgets);
    expect(find.text('닫기'), findsOneWidget);
  });
}
