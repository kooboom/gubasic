import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/memory_folders.dart';

void main() {
  final hello = exampleProjects['hello']!;
  const s = IdeStrings.en;
  late MemoryFolders fs;

  /// What the open and save dialogs give, in turn; null is Cancel.
  late List<String?> opens;
  late List<String?> saves;

  /// The names the save dialog offered.
  late List<String> offered;

  Future<void> start(WidgetTester tester, {IdeStrings strings = s}) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: strings,
        folders: fs,
        pickers: ProjectPickers(
          openProjectFile: (_) async => opens.removeAt(0),
          saveLocation: (name, _) async {
            offered.add(name);
            return saves.removeAt(0);
          },
        ),
      ),
    );
  }

  setUp(() {
    fs = MemoryFolders()..folders.add('/home');
    opens = [];
    saves = [];
    offered = [];
  });

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;

  Future<void> menu(WidgetTester tester, String item) async {
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item));
    await tester.pumpAndSettle();
  }

  Future<void> saveHelloAs(WidgetTester tester, String name) async {
    saves = ['/home/$name'];
    await menu(tester, s.saveAs);
    expect(find.text(s.exampleIsReadOnly), findsOneWidget);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();
  }

  testWidgets('Save on an example saves a copy in a new folder', (
    tester,
  ) async {
    await start(tester);
    saves = ['/home/Quiz'];
    await menu(tester, s.save);
    expect(find.text(s.exampleIsReadOnly), findsOneWidget);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();
    expect(offered, ['Hello']);

    expect(fs.files.keys, {
      '/home/Quiz/Quiz.gbproj',
      '/home/Quiz/Form1.form.yaml',
      '/home/Quiz/Form1.gbas',
    });
    expect(fs.files['/home/Quiz/Quiz.gbproj'], contains('name: Quiz\n'));
    expect(current(tester).location, isA<FolderLocation>());
    expect(find.text('Quiz'), findsWidgets, reason: 'title and menu');
    expect(find.text('Quiz.gbproj'), findsOneWidget, reason: 'file list');
    expect(find.text(s.saved.replaceAll('{0}', '/home/Quiz')), findsOneWidget);
  });

  testWidgets('a name typed with .gbproj makes the same folder', (
    tester,
  ) async {
    await start(tester);
    saves = ['/home/Quiz.gbproj'];
    await menu(tester, s.saveAs);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();
    expect(fs.files.keys, contains('/home/Quiz/Quiz.gbproj'));
  });

  testWidgets('a bad name or a folder that is there asks again', (
    tester,
  ) async {
    fs.add('/home/Hello', {'keep.txt': 'mine'});
    await start(tester);
    saves = ['/home/a:b', '/home/Hello', null];
    await menu(tester, s.saveAs);
    await tester.tap(find.text(s.saveCopyButton));
    await tester.pumpAndSettle();

    expect(find.text(s.badProjectName), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(
      find.text(s.folderExists.replaceAll('{0}', 'Hello')),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    expect(saves, isEmpty, reason: 'asked three times, then cancelled');
    expect(fs.written, isEmpty);
    expect(fs.files['/home/Hello/keep.txt'], 'mine');
    expect(current(tester).isExample, isTrue);
  });

  testWidgets('Open reads a .gbproj file and runs it', (tester) async {
    fs.add('/home/Typing', exampleProjects['typing']!);
    await start(tester);
    opens = ['/home/Typing/Typing.gbproj'];
    await menu(tester, s.open);
    expect(find.text('Typing'), findsWidgets);
    expect(current(tester).location, isA<FolderLocation>());
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(TextField), findsOneWidget, reason: 'the TextBox');
  });

  testWidgets('Open names the files that are missing', (tester) async {
    fs.add('/home/half', {...hello}..remove('Form1.gbas'));
    await start(tester);
    opens = ['/home/half/Hello.gbproj'];
    await menu(tester, s.open);
    expect(
      find.text(s.missingFiles.replaceAll('{0}', 'Form1.gbas')),
      findsOneWidget,
    );
  });

  testWidgets('Save writes changed files; the title marks unsaved changes', (
    tester,
  ) async {
    fs.add('/home/Hello', hello);
    await start(tester);
    opens = ['/home/Hello/Hello.gbproj'];
    await menu(tester, s.open);
    current(tester).setFile('Form1.gbas', "' changed\n");
    await tester.pump();
    expect(find.text('Hello — Edited'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyS);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    await tester.pumpAndSettle();
    expect(fs.written, ['/home/Hello/Form1.gbas']);
    expect(fs.files['/home/Hello/Form1.gbas'], "' changed\n");
    expect(find.text('Hello'), findsWidgets);
    expect(find.text('Hello — Edited'), findsNothing);
  });

  testWidgets('Save asks before replacing a file changed on disk', (
    tester,
  ) async {
    fs.add('/home/Hello', hello);
    await start(tester);
    opens = ['/home/Hello/Hello.gbproj'];
    await menu(tester, s.open);
    fs.files['/home/Hello/Form1.gbas'] = "' by another program\n";
    current(tester).setFile('Form1.gbas', "' mine\n");
    await tester.pump();

    final message = s.changedOnDisk.replaceAll('{0}', 'Form1.gbas');
    await menu(tester, s.save);
    expect(find.text(message), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(fs.files['/home/Hello/Form1.gbas'], "' by another program\n");
    expect(current(tester).isDirty, isTrue);

    await menu(tester, s.save);
    await tester.tap(find.text(s.overwrite));
    await tester.pumpAndSettle();
    expect(fs.files['/home/Hello/Form1.gbas'], "' mine\n");
    expect(current(tester).isDirty, isFalse);
  });

  testWidgets('a failed save says which file and keeps the changes', (
    tester,
  ) async {
    fs.add('/home/Hello', hello);
    fs.failing.add('/home/Hello/Form1.gbas');
    await start(tester);
    opens = ['/home/Hello/Hello.gbproj'];
    await menu(tester, s.open);
    current(tester).setFile('Form1.gbas', "' mine\n");
    await menu(tester, s.save);
    expect(
      find.text(
        s.cannotWrite
            .replaceAll('{0}', 'Form1.gbas')
            .replaceAll('{1}', 'disk full'),
      ),
      findsOneWidget,
    );
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(current(tester).isDirty, isTrue);
  });

  testWidgets('Save with nothing changed says so', (tester) async {
    fs.add('/home/Hello', hello);
    await start(tester);
    opens = ['/home/Hello/Hello.gbproj'];
    await menu(tester, s.open);
    await menu(tester, s.save);
    expect(find.text(s.nothingToSave), findsOneWidget);
    expect(fs.written, isEmpty);
  });

  group('unsaved changes', () {
    Future<void> changeAndSwitch(WidgetTester tester) async {
      fs.add('/home/Hello', hello);
      await start(tester);
      opens = ['/home/Hello/Hello.gbproj'];
      await menu(tester, s.open);
      current(tester).setFile('Form1.gbas', "' mine\n");
      await tester.pump();
      await tester.tap(find.text('Hello').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('typing').last);
      await tester.pumpAndSettle();
      expect(find.text(s.unsaved.replaceAll('{0}', 'Hello')), findsOneWidget);
    }

    testWidgets('Cancel stays', (tester) async {
      await changeAndSwitch(tester);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(current(tester).isDirty, isTrue);
      expect(current(tester).location, isA<FolderLocation>());
    });

    testWidgets("Don't Save goes on and loses them", (tester) async {
      await changeAndSwitch(tester);
      await tester.tap(find.text(s.dontSave));
      await tester.pumpAndSettle();
      expect(current(tester).isExample, isTrue);
      expect(fs.written, isEmpty);
    });

    testWidgets('Save saves, then goes on', (tester) async {
      await changeAndSwitch(tester);
      await tester.tap(find.widgetWithText(FilledButton, s.saveButton));
      await tester.pumpAndSettle();
      expect(fs.files['/home/Hello/Form1.gbas'], "' mine\n");
      expect(current(tester).isExample, isTrue);
    });

    testWidgets('quitting asks too', (tester) async {
      fs.add('/home/Hello', hello);
      await start(tester);
      opens = ['/home/Hello/Hello.gbproj'];
      await menu(tester, s.open);
      expect(
        await tester.binding.handleRequestAppExit(),
        AppExitResponse.exit,
        reason: 'nothing unsaved',
      );
      current(tester).setFile('Form1.gbas', "' mine\n");
      final response = tester.binding.handleRequestAppExit();
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(await response, AppExitResponse.cancel);
    });
  });

  testWidgets('a copy of an example can be saved again in its folder', (
    tester,
  ) async {
    await start(tester);
    await saveHelloAs(tester, 'Quiz');
    current(tester).setFile('Form1.gbas', "' more\n");
    await menu(tester, s.save);
    expect(fs.files['/home/Quiz/Form1.gbas'], "' more\n");
    expect(fs.written.last, '/home/Quiz/Form1.gbas');
  });

  testWidgets('no opening or saving while a program runs', (tester) async {
    await start(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    for (final item in [s.open, s.save, s.saveAs]) {
      final button = tester.widget<MenuItemButton>(
        find.widgetWithText(MenuItemButton, item),
      );
      expect(button.onPressed, isNull, reason: item);
    }
  });

  testWidgets('Korean words', (tester) async {
    await start(tester, strings: IdeStrings.ko);
    await tester.tap(find.widgetWithText(TextButton, '파일'));
    await tester.pumpAndSettle();
    expect(find.text('열기…'), findsOneWidget);
    expect(find.text('저장'), findsOneWidget);
    expect(find.text('다른 이름으로 저장…'), findsOneWidget);
    expect(find.text('프로젝트'), findsOneWidget, reason: 'the file list');
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    current(tester).setFile('Form1.gbas', "' 바꿈\n");
    await tester.pump();
    expect(find.text('Hello — 편집됨'), findsOneWidget);
  });

  testWidgets('the File menu is at the top left', (tester) async {
    await start(tester);
    final menu = tester.getTopLeft(find.text(s.fileMenu));
    final title = tester.getTopLeft(find.text('Hello').first);
    expect(menu.dx, lessThan(title.dx));
    expect(menu.dx, lessThan(100));
  });

  testWidgets('no File menu where there are no folders (the web)', (
    tester,
  ) async {
    await tester.pumpWidget(IdeApp(projects: exampleProjects, strings: s));
    expect(find.text(s.fileMenu), findsNothing);
  });
}
