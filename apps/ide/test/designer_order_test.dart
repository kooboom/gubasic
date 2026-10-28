import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/explorer.dart';

void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const formFile = 'Form1.form.yaml';
  // A Label over btnHello, after it in the file: drawn under it (D41).
  final over = {
    ...hello,
    formFile:
        '${hello[formFile]}'
        '  - name: lblOver\n'
        '    type: Label\n'
        '    properties:\n'
        '      Left: 8\n'
        '      Top: 48\n'
        '      Width: 200\n'
        '      Height: 48\n',
  };

  Future<void> open(WidgetTester tester, {IdeStrings strings = s}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': over}, strings: strings),
    );
    await tester.pumpAndSettle();
  }

  String formText(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;
  List<String> order(WidgetTester tester) => [
    for (final c in readFormFile(formText(tester), name: 'Form1').form.controls)
      c.name,
  ];
  String? selected(WidgetTester tester) => tester
      .widget<DropdownButton<String>>(find.byKey(propertiesTargetKey))
      .value;

  Future<void> click(
    WidgetTester tester,
    Offset at, {
    int buttons = kPrimaryButton,
  }) async {
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    final mouse = await tester.startGesture(
      origin + at,
      kind: PointerDeviceKind.mouse,
      buttons: buttons,
    );
    await mouse.up();
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> altClick(WidgetTester tester, Offset at) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await click(tester, at);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  Future<void> menu(WidgetTester tester, Offset at) =>
      click(tester, at, buttons: kSecondaryButton);

  test('to the front or the back of the list', () {
    final form = readFormFile(over[formFile]!, name: 'Form1').form;
    List<String> names(FormFile f) => [for (final c in f.controls) c.name];
    expect(names(withOrder(form, 'lblMessage', front: true)), [
      'btnHello',
      'lblOver',
      'lblMessage',
    ]);
    expect(names(withOrder(form, 'LBLOVER', front: false)), [
      'lblOver',
      'lblMessage',
      'btnHello',
    ]);
  });

  testWidgets('Tab and Shift+Tab go through the controls in file order', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(250, 100));
    expect(selected(tester), '');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(selected(tester), 'lblMessage');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(selected(tester), 'lblOver');
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(selected(tester), 'lblMessage', reason: 'round again');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect(selected(tester), 'lblOver');

    // In the Properties window, Tab is the fields' own.
    await tester.tap(find.byKey(propertyFieldKey('Caption')));
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pumpAndSettle();
    expect(selected(tester), 'lblOver');
  });

  testWidgets('Option-click goes down through the controls there', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    expect(selected(tester), 'btnHello', reason: 'on top');
    await altClick(tester, const Offset(30, 70));
    expect(selected(tester), 'lblOver');
    await altClick(tester, const Offset(30, 70));
    expect(selected(tester), 'btnHello', reason: 'round again');
    expect(find.byType(CodeEditor), findsNothing, reason: 'no double-click');
  });

  testWidgets('Ctrl+J, Ctrl+K and the toolbar: one step of undo each', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    await ctrl(tester, LogicalKeyboardKey.keyK);
    expect(order(tester), ['btnHello', 'lblMessage', 'lblOver']);
    await ctrl(tester, LogicalKeyboardKey.keyJ);
    expect(order(tester), ['lblMessage', 'lblOver', 'btnHello']);
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(order(tester), ['btnHello', 'lblMessage', 'lblOver']);
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), over[formFile]);
    await tester.tap(find.byKey(designerMenuKey('toolbar.back')));
    await tester.pumpAndSettle();
    expect(order(tester).first, 'btnHello');
    await tester.tap(find.byKey(designerMenuKey('toolbar.front')));
    await tester.pumpAndSettle();
    expect(order(tester).last, 'btnHello');
  });

  testWidgets('the order keys go by where the key is, not its letter', (
    tester,
  ) async {
    // Chrome on a Mac with a Korean input method reports Ctrl+K as ㅏ.
    const k = ShortcutAt(PhysicalKeyboardKey.keyK);
    KeyDownEvent down(LogicalKeyboardKey logical) => KeyDownEvent(
      physicalKey: PhysicalKeyboardKey.keyK,
      logicalKey: logical,
      character: logical.keyLabel,
      timeStamp: Duration.zero,
    );
    final keyboard = HardwareKeyboard.instance;
    expect(k.accepts(down(LogicalKeyboardKey.keyK), keyboard), isFalse);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    expect(k.accepts(down(const LogicalKeyboardKey(0x314f)), keyboard), isTrue);
    expect(k.accepts(down(LogicalKeyboardKey.keyK), keyboard), isTrue);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    expect(k.accepts(down(LogicalKeyboardKey.keyK), keyboard), isFalse);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
  });

  testWidgets("a control's menu", (tester) async {
    await open(tester);
    await menu(tester, const Offset(180, 70));
    expect(selected(tester), 'lblOver', reason: 'selected first');
    for (final item in ['viewCode', 'front', 'back', 'delete', 'properties']) {
      expect(find.byKey(designerMenuKey(item)), findsOneWidget, reason: item);
    }
    expect(find.text('Ctrl+J'), findsOneWidget);
    await tester.tap(find.byKey(designerMenuKey('back')));
    await tester.pumpAndSettle();
    expect(order(tester).first, 'lblOver');

    await menu(tester, const Offset(180, 70));
    await tester.tap(find.byKey(designerMenuKey('properties')));
    await tester.pumpAndSettle();
    final name = tester.widget<TextField>(
      find.byKey(propertyFieldKey('(Name)')),
    );
    expect(name.focusNode!.hasFocus, isTrue);

    await menu(tester, const Offset(180, 70));
    await tester.tap(find.byKey(designerMenuKey('delete')));
    await tester.pumpAndSettle();
    expect(order(tester), ['lblMessage', 'btnHello']);

    await menu(tester, const Offset(30, 70));
    await tester.tap(find.byKey(designerMenuKey('viewCode')));
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    final c = tester.widget<TextField>(find.byKey(codeFieldKey)).controller!;
    expect(
      c.text.substring(0, c.selection.baseOffset),
      endsWith('Sub btnHello_Click()\n    clickCount = clickCount + 1'),
    );
  });

  testWidgets("the form's menu: View Code and the grid", (tester) async {
    await open(tester);
    await menu(tester, const Offset(250, 100));
    expect(find.byKey(designerMenuKey('front')), findsNothing);
    await tester.tap(find.byKey(designerMenuKey('grid')));
    await tester.pumpAndSettle();
    final shell = tester.widget<IdeShell>(find.byType(IdeShell));
    expect(shell.grid.value, isFalse);
    await menu(tester, const Offset(250, 100));
    await tester.tap(find.byKey(designerMenuKey('viewCode')));
    await tester.pumpAndSettle();
    final c = tester.widget<TextField>(find.byKey(codeFieldKey)).controller!;
    expect(
      c.text.substring(0, c.selection.baseOffset),
      contains('Sub Form_Load()'),
    );
  });

  testWidgets('while running only View Code works', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(explorerItem(formFile));
    await tester.pumpAndSettle();
    await menu(tester, const Offset(30, 70));
    PopupMenuItem<Object?> item(String id) =>
        tester.widget(find.byKey(designerMenuKey(id)));
    expect(item('viewCode').enabled, isTrue);
    for (final id in ['front', 'back', 'delete', 'properties']) {
      expect(item(id).enabled, isFalse, reason: id);
    }
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    await menu(tester, const Offset(250, 100));
    expect(
      tester
          .widget<CheckedPopupMenuItem<Object?>>(
            find.byKey(designerMenuKey('grid')),
          )
          .enabled,
      isFalse,
    );
  });

  testWidgets('Control and a click opens the menu on Apple systems', (
    tester,
  ) async {
    await open(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await click(tester, const Offset(30, 70));
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
    expect(find.byKey(designerMenuKey('viewCode')), findsOneWidget);
    expect(find.text('⌘J'), findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.macOS));

  testWidgets('Korean words', (tester) async {
    await open(tester, strings: IdeStrings.ko);
    await menu(tester, const Offset(30, 70));
    for (final w in ['코드 보기', '맨 앞으로', '맨 뒤로', '삭제', '속성']) {
      expect(find.text(w), findsWidgets, reason: w);
    }
  });

  test('defaultTargetPlatform is reset', () {
    expect(debugDefaultTargetPlatformOverride, isNull);
  });
}
