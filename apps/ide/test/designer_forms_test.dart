import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';

import 'support/memory_folders.dart';

/// Several forms in the IDE (step 2-8, D88): adding, renaming and
/// deleting a form, choosing the one that starts, saving, and running.
void main() {
  const s = IdeStrings.en;
  late MemoryFolders fs;

  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: One\n  Width: 300\n'
        '  Height: 160\ncontrols:\n  - name: btnNext\n    type: Button\n'
        '    properties:\n      Caption: Next\n',
    'Form1.gbas': 'Sub btnNext_Click()\n    Form2.Show\nEnd Sub\n',
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

  Future<void> formAction(WidgetTester tester, String form, String item) async {
    await tester.tap(find.byKey(ValueKey('files.form.$form')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(item).last);
    await tester.pumpAndSettle();
  }

  testWidgets('File → Add Form adds Form2 and opens its design; it is '
      'renamed with its uses in the code, made the startup form and '
      'deleted', (tester) async {
    await start(tester);
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.addForm));
    await tester.pumpAndSettle();
    expect(projectFile(tester).forms, ['Form1', 'Form2']);
    expect(
      current(tester).files.keys,
      containsAll(['Form2.form.yaml', 'Form2.gbas']),
    );
    // The new form's design is open: its Caption is its name.
    expect(find.text('Form2'), findsWidgets);

    // A name another form has is refused, and says so.
    await formAction(tester, 'Form2', s.renameForm);
    await tester.enterText(
      find.byKey(const ValueKey('formName.field')),
      'form1',
    );
    await tester.pump();
    expect(
      find.text(s.formNameTaken.replaceAll('{0}', 'form1')),
      findsOneWidget,
    );
    expect(
      tester
          .widget<FilledButton>(find.byKey(const ValueKey('formName.ok')))
          .onPressed,
      isNull,
    );
    await tester.enterText(
      find.byKey(const ValueKey('formName.field')),
      'Question',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('formName.ok')));
    await tester.pumpAndSettle();
    expect(projectFile(tester).forms, ['Form1', 'Question']);
    expect(
      current(tester).files['Form1.gbas'],
      'Sub btnNext_Click()\n    Question.Show\nEnd Sub\n',
    );
    expect(current(tester).files.containsKey('Form2.gbas'), isFalse);

    // The startup form, tagged in the list.
    await formAction(tester, 'Question', s.makeStartupForm);
    expect(projectFile(tester).startup, 'Question');
    expect(find.textContaining(s.startupFormTag), findsOneWidget);

    // Deleting says where the code uses it.
    await formAction(tester, 'Question', s.deleteForm);
    expect(
      find.textContaining('The code uses Question (Form1.gbas:2)'),
      findsOneWidget,
    );
    await tester.tap(find.text(s.deleteForm.replaceAll('…', '')).last);
    await tester.pumpAndSettle();
    expect(projectFile(tester).forms, ['Form1']);
    expect(projectFile(tester).startup, 'Form1');
    expect(current(tester).files.keys, isNot(contains('Question.gbas')));
  });

  testWidgets('the last form cannot be deleted', (tester) async {
    await start(tester);
    final controller = tester
        .widget<IdeShell>(find.byType(IdeShell))
        .controller;
    final context = tester.element(find.byType(IdeShell));
    final deleted = controller.deleteForm(context, 'Form1');
    await tester.pumpAndSettle();
    expect(
      find.text(s.lastFormKept.replaceAll('{0}', 'Form1')),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.ok));
    await tester.pumpAndSettle();
    expect(await deleted, isFalse);
  });

  testWidgets('saving deletes the files of a form renamed or deleted from '
      'the disk, and writes the new ones', (tester) async {
    fs = MemoryFolders()
      ..add('/p/Demo', {
        ...demo,
        'Demo.gbproj':
            'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n'
            '  - Form1\n  - Form2\n',
        'Form2.form.yaml': 'formatVersion: 1\n',
        'Form2.gbas': '',
      });
    await start(tester);
    await formAction(tester, 'Form2', s.renameForm);
    await tester.enterText(
      find.byKey(const ValueKey('formName.field')),
      'Question',
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('formName.ok')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.save));
    await tester.pumpAndSettle();
    expect(
      fs.deleted,
      unorderedEquals(['/p/Demo/Form2.form.yaml', '/p/Demo/Form2.gbas']),
    );
    expect(fs.files['/p/Demo/Question.form.yaml'], 'formatVersion: 1\n');
    expect(fs.files['/p/Demo/Form1.gbas'], contains('Question.Show'));
    expect(current(tester).isDirty, isFalse);
  });

  testWidgets('a project of two forms runs: Next shows Form2 in the run '
      'window', (tester) async {
    await start(tester);
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.addForm));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byKey(runFormKey('Form1')), findsOneWidget);
    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    expect(find.byKey(runFormKey('Form2')), findsOneWidget);
    expect(find.byKey(runFormKey('Form1')), findsNothing);
    await tester.tap(find.byKey(runWindowCloseKey));
    await tester.pumpAndSettle();
  });
}
