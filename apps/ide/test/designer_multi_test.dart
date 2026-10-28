import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// Several controls at once in the designer: choosing them with Ctrl (⌘)
/// or Shift and a click, a rubber band or Ctrl+A; moving, resizing,
/// ordering and deleting them together; copying, cutting and pasting them.
void main() {
  const s = IdeStrings.en;
  const form1 = 'Form1.form.yaml';
  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n'
        '  - Form1\n  - Form2\n',
    form1:
        'formatVersion: 1\nproperties:\n  Caption: One\n  Width: 400\n'
        '  Height: 300\ncontrols:\n'
        '  - name: btnA\n    type: Button\n    properties:\n      Caption: A\n'
        '      Left: 16\n      Top: 16\n      Width: 96\n      Height: 32\n'
        '  - name: btnB\n    type: Button\n    properties:\n      Caption: B\n'
        '      Left: 16\n      Top: 64\n      Width: 96\n      Height: 32\n'
        '  - name: Label1\n    type: Label\n    properties:\n'
        '      Caption: Label1\n      Left: 200\n      Top: 16\n'
        '      Width: 96\n      Height: 24\n',
    'Form1.gbas': 'Sub btnA_Click()\n    Label1.Caption = "x"\nEnd Sub\n',
    'Form2.form.yaml':
        'formatVersion: 1\nproperties:\n  Caption: Two\n  Width: 400\n'
        '  Height: 300\n',
  };

  setUp(clearDesignerClipboard);

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;
  String text(WidgetTester tester, [String file = form1]) =>
      current(tester).files[file]!;

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

  /// A mouse drag on the form from [from] to [to]; a click when they are
  /// the same. [hold] is held down meanwhile.
  Future<void> drag(
    WidgetTester tester,
    Offset from,
    Offset to, {
    LogicalKeyboardKey? hold,
  }) async {
    if (hold != null) await tester.sendKeyDownEvent(hold);
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    final mouse = await tester.startGesture(
      origin + from,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.moveTo(origin + (from + to) / 2);
    await tester.pump();
    await mouse.moveTo(origin + to);
    await tester.pump();
    await mouse.up();
    if (hold != null) await tester.sendKeyUpEvent(hold);
    await tester.pumpAndSettle();
    // Past a double-click: the next press is a press of its own.
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> click(
    WidgetTester tester,
    Offset at, {
    LogicalKeyboardKey? hold,
  }) => drag(tester, at, at, hold: hold);

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  Finder status(String text) => find.text(text);

  testWidgets('Ctrl or Shift and a click add a control and take it away; '
      'a rubber band chooses what it touches; Escape chooses none', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(20, 20));
    expect(find.textContaining('btnA (Button)'), findsOneWidget);
    await click(tester, const Offset(20, 70), hold: LogicalKeyboardKey.control);
    expect(status('2 controls chosen'), findsNWidgets(2));
    expect(find.text(s.chooseOneControl), findsOneWidget);
    await click(tester, const Offset(210, 20), hold: LogicalKeyboardKey.shift);
    expect(status('3 controls chosen'), findsNWidgets(2));
    // Again: it leaves them.
    await click(tester, const Offset(20, 20), hold: LogicalKeyboardKey.shift);
    expect(status('2 controls chosen'), findsNWidgets(2));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.text('Form1 (Form) · 400×300'), findsOneWidget);

    // From the form's empty part, over btnA and btnB, not Label1.
    await drag(tester, const Offset(150, 8), const Offset(60, 80));
    expect(status('2 controls chosen'), findsNWidgets(2));
    // Ctrl and a band add Label1.
    await drag(
      tester,
      const Offset(320, 8),
      const Offset(250, 20),
      hold: LogicalKeyboardKey.control,
    );
    expect(status('3 controls chosen'), findsNWidgets(2));

    // A click on the form chooses none again.
    await click(tester, const Offset(300, 250));
    expect(find.text('Form1 (Form) · 400×300'), findsOneWidget);
    await ctrl(tester, LogicalKeyboardKey.keyA);
    expect(status('3 controls chosen'), findsNWidgets(2));
    expect(text(tester), demo[form1], reason: 'choosing changes nothing');
  });

  testWidgets('chosen controls move together, by the mouse and by the arrows, '
      'one step of undo each; Shift and an arrow resizes each', (tester) async {
    await open(tester);
    await click(tester, const Offset(20, 20));
    await click(tester, const Offset(20, 70), hold: LogicalKeyboardKey.control);
    await drag(tester, const Offset(20, 70), const Offset(60, 110));
    expect(text(tester), contains('      Left: 56\n      Top: 56\n'));
    expect(text(tester), contains('      Left: 56\n      Top: 104\n'));
    expect(text(tester), contains('      Left: 200\n      Top: 16\n'));
    expect(status('2 controls chosen'), findsNWidgets(2), reason: 'still');

    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(text(tester), demo[form1], reason: 'one step back');
    await ctrl(tester, LogicalKeyboardKey.arrowRight);
    expect(text(tester), contains('      Left: 24\n      Top: 16\n'));
    expect(text(tester), contains('      Left: 24\n      Top: 64\n'));
    // Moving left stops them together at the edge.
    for (var i = 0; i < 5; i++) {
      await ctrl(tester, LogicalKeyboardKey.arrowLeft);
    }
    // Left 0 is the default, which the file leaves out.
    expect(text(tester), contains('      Caption: A\n      Top: 16\n'));
    expect(text(tester), contains('      Caption: B\n      Top: 64\n'));

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
    expect('Width: 104'.allMatches(text(tester)).length, 2);

    // A click without a drag on one of them chooses it alone.
    await click(tester, const Offset(4, 70));
    expect(find.textContaining('btnB (Button)'), findsOneWidget);
  });

  testWidgets('Delete deletes them all, asking first when the code uses '
      'them; Ctrl+J and Ctrl+K order them together', (tester) async {
    await open(tester);
    await click(tester, const Offset(20, 20));
    await click(
      tester,
      const Offset(210, 20),
      hold: LogicalKeyboardKey.control,
    );
    await ctrl(tester, LogicalKeyboardKey.keyK);
    expect(
      text(tester).indexOf('name: btnA'),
      lessThan(text(tester).indexOf('name: Label1')),
    );
    expect(
      text(tester).indexOf('name: Label1'),
      lessThan(text(tester).indexOf('name: btnB')),
      reason: 'under btnB, in their own order',
    );
    await ctrl(tester, LogicalKeyboardKey.keyZ);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(find.textContaining('Label1 is used in Form1.gbas'), findsOneWidget);
    expect(find.textContaining('btnA_Click'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, s.deleteControl));
    await tester.pumpAndSettle();
    expect(text(tester), isNot(contains('name: btnA')));
    expect(text(tester), isNot(contains('name: Label1')));
    expect(text(tester), contains('name: btnB'));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(text(tester), demo[form1]);
  });

  testWidgets('copies are pasted a step down and right, with new names where '
      'the old ones are taken, chosen; onto another form, as they were', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(20, 20));
    await click(
      tester,
      const Offset(210, 20),
      hold: LogicalKeyboardKey.control,
    );
    await ctrl(tester, LogicalKeyboardKey.keyC);
    expect(text(tester), demo[form1], reason: 'copying changes nothing');
    await ctrl(tester, LogicalKeyboardKey.keyV);
    final pasted = text(tester);
    expect(
      pasted,
      endsWith(
        // The default size is left out of the file.
        '  - name: Button1\n    type: Button\n    properties:\n'
        '      Caption: A\n      Left: 24\n      Top: 24\n'
        '  - name: Label2\n    type: Label\n    properties:\n'
        '      Caption: Label2\n      Left: 208\n      Top: 24\n'
        '      Width: 96\n',
      ),
    );
    expect(status('2 controls chosen'), findsNWidgets(2));
    // Again: a step further.
    await ctrl(tester, LogicalKeyboardKey.keyV);
    expect(text(tester), contains('  - name: Button2\n'));
    expect(text(tester), contains('      Left: 32\n      Top: 32\n'));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(text(tester), pasted, reason: 'one step back');

    // Onto Form2: the names and places as they were.
    await tester.tap(explorerItem('Form2.form.yaml'));
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.keyV);
    expect(
      text(tester, 'Form2.form.yaml'),
      contains(
        '  - name: btnA\n    type: Button\n    properties:\n'
        '      Caption: A\n      Left: 16\n      Top: 16\n',
      ),
    );
    expect(text(tester, 'Form2.form.yaml'), contains('  - name: Label1\n'));
  });

  testWidgets('Ctrl+X cuts; the context menu has Cut, Copy and Paste, and '
      'Select All on the form', (tester) async {
    await open(tester);
    await click(tester, const Offset(20, 70));
    await ctrl(tester, LogicalKeyboardKey.keyX);
    expect(text(tester), isNot(contains('name: btnB')));
    await ctrl(tester, LogicalKeyboardKey.keyV);
    expect(text(tester), contains('  - name: btnB\n'), reason: 'free again');
    expect(text(tester), contains('      Left: 16\n      Top: 64\n'));

    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.tapAt(
      origin + const Offset(20, 20),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    for (final item in ['cut', 'copy', 'paste', 'delete']) {
      expect(find.byKey(designerMenuKey(item)), findsOneWidget, reason: item);
    }
    await tester.tapAt(Offset.zero);
    await tester.pumpAndSettle();
    await tester.tapAt(
      origin + const Offset(300, 250),
      buttons: kSecondaryButton,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(designerMenuKey('selectAll')));
    await tester.pumpAndSettle();
    expect(status('3 controls chosen'), findsNWidgets(2));
  });

  testWidgets('Korean words', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'demo': demo}, strings: IdeStrings.ko, open: 'demo'),
    );
    await tester.pumpAndSettle();
    await ctrl(tester, LogicalKeyboardKey.keyA);
    expect(find.text('컨트롤 3개를 골랐습니다'), findsNWidgets(2));
    expect(find.text('속성을 보고 바꾸려면 컨트롤을 하나만 고릅니다.'), findsOneWidget);
  });
}
