import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_zip.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'project_zip_test.dart' show zipOf;
import 'support/fake_browser.dart';

void main() {
  final hello = exampleProjects['hello']!;
  final typing = exampleProjects['typing']!;
  const s = IdeStrings.en;
  late FakeBrowser browser;

  /// What the .zip dialog gives, in turn; null is Cancel.
  late List<List<int>?> zips;

  Future<void> start(WidgetTester tester, {IdeStrings strings = s}) async {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: strings,
        browser: browser,
        pickZip: () async => zips.removeAt(0),
      ),
    );
  }

  setUp(() {
    browser = FakeBrowser();
    zips = [];
  });

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  /// Saves the hello example as [name] in the browser; closes the notice.
  Future<void> keepHelloAs(WidgetTester tester, String name) async {
    await menu(tester, s.save);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), name);
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, s.saveButton));
    await tester.pumpAndSettle();
  }

  Future<void> closeDialog(WidgetTester tester) async {
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
  }

  testWidgets('the web File menu, and the .zip button', (tester) async {
    await start(tester);
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    for (final item in [s.open, s.save, s.saveAs, s.uploadZip]) {
      expect(find.text(item), findsOneWidget, reason: item);
    }
    expect(find.text(s.downloadZip), findsNWidgets(2), reason: 'menu, button');
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(OutlinedButton, s.downloadZip), findsOneWidget);
    expect(find.text(s.exampleStatus), findsOneWidget);
  });

  testWidgets('Save on an example keeps a copy in the browser, with a '
      'notice the first time only', (tester) async {
    await start(tester);
    await keepHelloAs(tester, 'Quiz');
    expect(find.text(s.browserNotice), findsOneWidget);
    await closeDialog(tester);

    final location = current(tester).location;
    expect(location, isA<BrowserLocation>());
    final kept = browser.storage.values['gubasic.ide.project.quiz']!;
    expect(kept, contains('Quiz.gbproj'));
    expect(kept, contains(r'name: Quiz\n'));
    expect(find.text(s.keptStatus.replaceAll('{0}', s.none)), findsOneWidget);
    expect(
      find.widgetWithText(FilledButton, s.downloadZip),
      findsOneWidget,
      reason: 'never downloaded',
    );

    await tester.tap(find.text('Quiz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('hello').last);
    await tester.pumpAndSettle();
    await keepHelloAs(tester, 'Quiz2');
    expect(find.text(s.browserNotice), findsNothing);
  });

  testWidgets('a name kept already is asked again', (tester) async {
    await start(tester);
    await keepHelloAs(tester, 'Quiz');
    await closeDialog(tester);
    await tester.tap(find.text('Quiz').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('hello').last);
    await tester.pumpAndSettle();
    await keepHelloAs(tester, 'QUIZ');
    expect(
      find.text(s.projectExistsInBrowser.replaceAll('{0}', 'QUIZ')),
      findsOneWidget,
    );
    await closeDialog(tester);
    expect(find.text(s.saveAsTitle), findsOneWidget, reason: 'asked again');
  });

  testWidgets('changes are kept a moment later, and when the page hides', (
    tester,
  ) async {
    await start(tester);
    await keepHelloAs(tester, 'Quiz');
    await closeDialog(tester);

    current(tester).setFile('Form1.gbas', "' one\n");
    await tester.pump();
    expect(find.text('Quiz — Edited'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    expect(find.text('Quiz — Edited'), findsNothing);
    expect(
      browser.storage.values['gubasic.ide.project.quiz'],
      contains("' one"),
    );

    current(tester).setFile('Form1.gbas', "' two\n");
    browser.hide();
    expect(
      browser.storage.values['gubasic.ide.project.quiz'],
      contains("' two"),
      reason: 'kept at once',
    );
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('Download gives NAME.zip; the browser asks before leaving '
      'only while changes are not downloaded', (tester) async {
    await start(tester);
    expect(browser.wouldAskToLeave, isFalse, reason: 'an unchanged example');
    await keepHelloAs(tester, 'Quiz');
    await closeDialog(tester);
    expect(browser.wouldAskToLeave, isTrue);

    await tester.tap(find.widgetWithText(FilledButton, s.downloadZip));
    await tester.pumpAndSettle();
    final (name, bytes) = browser.downloads.single;
    expect(name, 'Quiz.zip');
    final back = unzipProject(bytes);
    expect(back.name, 'Quiz');
    expect(back.files.keys, contains('Quiz.gbproj'));
    expect(browser.wouldAskToLeave, isFalse);
    expect(find.widgetWithText(OutlinedButton, s.downloadZip), findsOneWidget);
    expect(find.text(s.keptStatus.replaceAll('{0}', s.none)), findsNothing);

    current(tester).setFile('Form1.gbas', "' more\n");
    await tester.pump(const Duration(seconds: 3));
    expect(browser.wouldAskToLeave, isTrue);
    expect(find.widgetWithText(FilledButton, s.downloadZip), findsOneWidget);
  });

  testWidgets('Ctrl+Shift+E downloads', (tester) async {
    await start(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyE);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(browser.downloads.single.$1, 'Hello.zip');
  });

  testWidgets('Upload keeps the project of a .zip and opens it', (
    tester,
  ) async {
    await start(tester);
    zips = [
      zipOf({
        for (final MapEntry(:key, :value) in typing.entries)
          'Typing/$key': value,
        'Typing/notes.txt': 'mine',
      }),
    ];
    await menu(tester, s.uploadZip);
    expect(
      find.text(s.zipIgnored.replaceAll('{0}', 'Typing/notes.txt')),
      findsOneWidget,
    );
    await closeDialog(tester);
    expect(find.text(s.browserNotice), findsOneWidget);
    await closeDialog(tester);

    expect(current(tester).location, isA<BrowserLocation>());
    expect(current(tester).files, typing);
    expect(browser.wouldAskToLeave, isFalse, reason: 'it came from a file');
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget, reason: 'the TextBox');
  });

  testWidgets('Upload of a name kept already asks for another', (tester) async {
    await start(tester);
    await keepHelloAs(tester, 'Hello');
    await closeDialog(tester);
    zips = [zipProject('Hello', hello)];
    await menu(tester, s.uploadZip);
    expect(
      find.text(s.projectExistsInBrowser.replaceAll('{0}', 'Hello')),
      findsOneWidget,
    );
    await closeDialog(tester);
    await tester.enterText(find.byType(TextField), 'Hello2');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, s.saveButton));
    await tester.pumpAndSettle();
    expect(
      browser.storage.values['gubasic.ide.project.hello2'],
      contains('Hello2.gbproj'),
    );
    expect(
      browser.storage.values['gubasic.ide.project.hello2'],
      contains(r'name: Hello2\n'),
    );
  });

  testWidgets('a bad .zip says why and changes nothing', (tester) async {
    await start(tester);
    zips = [
      zipOf({...hello, '../evil.gbas': 'x'}),
    ];
    await menu(tester, s.uploadZip);
    expect(
      find.text(s.unsafeZipPath.replaceAll('{0}', '../evil.gbas')),
      findsOneWidget,
    );
    await closeDialog(tester);
    expect(browser.storage.values, isEmpty);
    expect(current(tester).isExample, isTrue);
  });

  testWidgets('Open lists the kept projects; one can be deleted', (
    tester,
  ) async {
    await start(tester);
    await menu(tester, s.open);
    expect(find.text(s.noKeptProjects), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    await keepHelloAs(tester, 'A');
    await closeDialog(tester);
    await tester.tap(find.text('A').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('hello').last);
    await tester.pumpAndSettle();
    await keepHelloAs(tester, 'B');

    await menu(tester, s.open);
    expect(find.text(s.keptProjectsTitle), findsOneWidget);
    await tester.tap(find.byTooltip(s.deleteProject).last);
    await tester.pumpAndSettle();
    expect(find.text(s.confirmDelete.replaceAll('{0}', 'A')), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, s.deleteProject));
    await tester.pumpAndSettle();
    expect(
      browser.storage.values.keys,
      isNot(contains('gubasic.ide.project.a')),
    );

    await tester.tap(find.text('B').last);
    await tester.pumpAndSettle();
    expect(current(tester).location, isA<BrowserLocation>());
    expect(current(tester).project.name, 'B');
  });

  testWidgets('deleting the open project opens an example instead', (
    tester,
  ) async {
    await start(tester);
    await keepHelloAs(tester, 'Quiz');
    await closeDialog(tester);
    await menu(tester, s.open);
    await tester.tap(find.byTooltip(s.deleteProject));
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(FilledButton, s.deleteProject));
    await tester.pumpAndSettle();
    expect(find.text(s.noKeptProjects), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    expect(current(tester).isExample, isTrue);
    expect(find.text('Quiz'), findsNothing, reason: 'not in the menu');
    current(tester).setFile('Form1.gbas', "' after\n");
    await tester.pump(const Duration(seconds: 3));
    expect(browser.storage.values, isNot(contains('gubasic.ide.project.quiz')));
  });

  testWidgets('a long message keeps a readable width', (tester) async {
    await start(tester);
    await keepHelloAs(tester, 'Quiz');
    expect(
      tester.getSize(find.text(s.browserNotice)).width,
      lessThanOrEqualTo(440),
    );
  });

  testWidgets('a full storage says so, in a dialog and in the status line', (
    tester,
  ) async {
    await start(tester);
    await keepHelloAs(tester, 'Quiz');
    await closeDialog(tester);
    browser.storage.full = true;
    current(tester).setFile('Form1.gbas', "' lost?\n");
    await tester.pump(const Duration(seconds: 3));
    expect(find.text(s.storageFailed), findsOneWidget, reason: 'status line');
    await menu(tester, s.save);
    expect(find.text(s.storageFailed), findsNWidgets(2));
    await closeDialog(tester);
    expect(current(tester).isDirty, isTrue);
  });

  testWidgets('Korean words', (tester) async {
    await start(tester, strings: IdeStrings.ko);
    expect(find.text('.zip으로 내려받기'), findsOneWidget);
    expect(find.text(IdeStrings.ko.exampleStatus), findsOneWidget);
    await tester.tap(find.widgetWithText(TextButton, '파일'));
    await tester.pumpAndSettle();
    expect(find.text('.zip 올리기…'), findsOneWidget);
  });
}
