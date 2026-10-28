import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/memory_folders.dart';

/// A project's modules in the IDE (docs/DESIGN.md D102): File → Add
/// Module, their group in the project explorer, starting with Sub Main,
/// renaming with their uses, deleting, saving and opening again.
void main() {
  const s = IdeStrings.en;
  late MemoryFolders fs;

  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: One\ncontrols:\n'
        '  - name: lblTotal\n    type: Label\n',
    'Form1.gbas': 'Sub Form_Load()\nEnd Sub\n',
  };

  setUp(() {
    fs = MemoryFolders()..add('/p/Demo', demo);
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        folders: fs,
        pickers: ProjectPickers(
          openProjectFile: (_) async => '/p/Demo/Demo.gbproj',
          saveLocation: (_, _) async => null,
        ),
      ),
    );
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.open));
    await tester.pumpAndSettle();
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;
  ProjectFile projectFile(WidgetTester tester) =>
      readProjectFile(current(tester).files['Demo.gbproj']!).project;

  Future<void> moduleAction(
    WidgetTester tester,
    String module,
    String item,
  ) async {
    await tester.tap(find.byKey(ValueKey('files.module.$module')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('File → Add Module adds Module1 and opens its code; the '
      'project starts with its Sub Main; it is renamed with its uses, '
      'saved, and deleted', (tester) async {
    await start(tester);
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.addModule));
    await tester.pumpAndSettle();
    expect(projectFile(tester).modules, ['Module1']);
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(current(tester).files['Module1.gbas'], "' ${s.moduleComment}\n");
    expect(find.byKey(const ValueKey('explorer.modules')), findsOneWidget);
    expect(
      find.byKey(const ValueKey('explorer.module.Module1')),
      findsOneWidget,
    );

    // Without a Sub Main, the project cannot start with one.
    await tester.tap(find.byKey(const ValueKey('files.module.Module1')));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<PopupMenuItem<String>>(
            find.widgetWithText(PopupMenuItem<String>, s.startWithMain),
          )
          .enabled,
      isFalse,
    );
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();

    current(tester)
      ..setFile(
        'Module1.gbas',
        'Public Total As Integer\nSub Main()\nForm1.Show\nEnd Sub\n',
      )
      ..setFile(
        'Form1.gbas',
        'Sub Form_Load()\nlblTotal.Caption = CStr(Module1.Total)\nEnd Sub\n',
      );
    await tester.pumpAndSettle();
    await moduleAction(tester, 'Module1', s.startWithMain);
    expect(projectFile(tester).startsWithMain, isTrue);
    expect(current(tester).project.canRun, isTrue);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('explorer.module.Module1')),
        matching: find.text(s.startupFormTag),
      ),
      findsOneWidget,
    );

    await moduleAction(tester, 'Module1', s.renameModule);
    await tester.enterText(find.byType(TextField).last, 'Shared');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(projectFile(tester).modules, ['Shared']);
    expect(current(tester).files['Form1.gbas'], contains('Shared.Total'));
    expect(current(tester).files.containsKey('Module1.gbas'), isFalse);

    // Saved, and read back from the disk.
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.save));
    await tester.pumpAndSettle();
    expect(fs.files['/p/Demo/Shared.gbas'], contains('Sub Main()'));
    expect(fs.files['/p/Demo/Demo.gbproj'], contains('modules:\n  - Shared'));

    await moduleAction(tester, 'Shared', s.deleteModule);
    await tester.tap(find.widgetWithText(FilledButton, 'Delete Module'));
    await tester.pumpAndSettle();
    expect(projectFile(tester).modules, isEmpty);
    expect(projectFile(tester).startsWithMain, isFalse, reason: 'Form1');
    expect(find.byKey(const ValueKey('explorer.modules')), findsNothing);
  });

  testWidgets('Korean words', (tester) async {
    expect(IdeStrings.ko.addModule, '모듈 추가');
    expect(IdeStrings.ko.startWithMain, 'Sub Main으로 시작');
  });
}
