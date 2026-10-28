import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/menu_editor.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'support/explorer.dart';

/// The menu editor and the menu bar in the designer (docs/DESIGN.md D106).
void main() {
  const s = IdeStrings.en;
  const form1 = 'Form1.form.yaml';
  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n'
        '  - Form1\n',
    form1:
        'formatVersion: 1\nproperties:\n  Width: 320\n  Height: 200\n'
        'controls:\n'
        '  - name: btnOk\n    type: Button\n    properties:\n'
        '      Left: 16\n      Top: 16\n',
    'Form1.gbas': '',
  };

  String text(WidgetTester tester, [String file = form1]) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[file]!;

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'demo': demo}, strings: s, open: 'demo'),
    );
    await tester.pumpAndSettle();
    await tester.tap(explorerItem(form1));
    await tester.pumpAndSettle();
  }

  Future<void> fill(WidgetTester tester, String field, String value) async {
    await tester.enterText(find.byKey(menuEditorFieldKey(field)), value);
    await tester.pump();
  }

  Future<void> press(WidgetTester tester, String button) async {
    await tester.tap(find.byKey(menuEditorButtonKey(button)));
    await tester.pumpAndSettle();
  }

  Future<void> editMenus(WidgetTester tester) async {
    await tester.tap(find.byKey(designerMenuKey('toolbar.menus')));
    await tester.pumpAndSettle();
  }

  testWidgets('items made in the menu editor go under menus:, and the '
      'designer draws them; choosing one opens its Click', (tester) async {
    await open(tester);
    expect(find.byKey(gbMenuBarKey), findsNothing);
    await editMenus(tester);
    await fill(tester, 'Caption', 'File');
    await fill(tester, 'Name', 'mnuFile');
    await press(tester, 'next');
    await fill(tester, 'Caption', 'Open');
    await fill(tester, 'Name', 'mnuFileOpen');
    await fill(tester, 'Shortcut', 'ctrl + o');
    await press(tester, 'in');
    await press(tester, 'next');
    await press(tester, 'ok');

    expect(
      text(tester),
      endsWith(
        'menus:\n'
        '  - name: mnuFile\n    properties:\n      Caption: File\n'
        '    menus:\n'
        '      - name: mnuFileOpen\n        properties:\n'
        '          Caption: Open\n          Shortcut: Ctrl+O\n',
      ),
    );
    expect(text(tester), startsWith('formatVersion: 3\n'));
    expect(find.byKey(gbMenuBarKey), findsOneWidget);

    // Opened again: as they were.
    await editMenus(tester);
    expect(find.byKey(menuEditorRowKey(1)), findsOneWidget);
    expect(find.text('····Open'), findsOneWidget);
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(gbMenuKey('mnuFile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(gbMenuKey('mnuFileOpen')));
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(text(tester, 'Form1.gbas'), contains('Sub mnuFileOpen_Click()\n'));
  });

  testWidgets('what is wrong is said, and OK waits; Ctrl+A leaves the '
      'menus alone; undo takes them back', (tester) async {
    await open(tester);
    await editMenus(tester);
    await fill(tester, 'Caption', 'OK');
    await fill(tester, 'Name', 'btnOk');
    await press(tester, 'ok');
    expect(
      find.text(s.menuNameTaken.replaceAll('{0}', 'btnOk')),
      findsOneWidget,
    );
    await fill(tester, 'Name', 'mnuFile');
    await fill(tester, 'Shortcut', 'O');
    await press(tester, 'ok');
    expect(find.text(s.menuBadShortcut.replaceAll('{0}', 'O')), findsOneWidget);
    await fill(tester, 'Shortcut', '');
    await press(tester, 'ok');
    expect(find.byKey(menuEditorButtonKey('ok')), findsNothing);
    expect(
      readFormFile(text(tester), name: 'Form1').form.control('mnuFile'),
      isNotNull,
    );

    // Ctrl+A and Delete: the controls, not the menus.
    await tester.tapAt(
      tester.getTopLeft(find.byKey(designerFormKey)) + const Offset(250, 150),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyA);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    var form = readFormFile(text(tester), name: 'Form1').form;
    expect(form.controls.map((c) => c.name), ['mnuFile']);

    for (var i = 0; i < 2; i++) {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
      await tester.pumpAndSettle();
    }
    form = readFormFile(text(tester), name: 'Form1').form;
    expect(form.controls.map((c) => c.name), ['btnOk']);
  });

  test('rows with what is wrong with them', () {
    final form = readFormFile(demo[form1]!, name: 'Form1').form;
    String? problem(List<MenuRow> rows) => menuRowsProblem(form, rows, s);
    expect(
      problem([MenuRow(name: 'mnuA', level: 1)]),
      s.menuTooDeep.replaceAll('{0}', 'mnuA'),
    );
    expect(
      problem([
        MenuRow(name: 'mnuA'),
        MenuRow(name: 'mnuLine', caption: '-', level: 1),
        MenuRow(name: 'mnuB', level: 2),
      ]),
      s.menuLineHolds.replaceAll('{0}', 'mnuLine'),
    );
    expect(
      problem([
        MenuRow(name: 'mnuA', shortcut: 'Ctrl+A'),
        MenuRow(name: 'mnuB', level: 1),
      ]),
      s.menuShortcutOfMenu.replaceAll('{0}', 'mnuA'),
    );
    expect(
      problem([MenuRow(name: 'Sub')]),
      s.menuBadName.replaceAll('{0}', 'Sub'),
    );
    expect(problem([MenuRow()]), s.menuNoName);
    expect(
      problem([MenuRow(name: 'mnuA'), MenuRow(name: 'MNUA')]),
      s.menuNameTaken.replaceAll('{0}', 'MNUA'),
    );
  });
}
