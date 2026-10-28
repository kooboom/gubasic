import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'support/explorer.dart';

/// Anchor in the IDE (D59): the designer moves controls as their Anchor
/// says when the form changes size, the Properties window sets it with a
/// cross, and the run window's corner resizes a running form.
void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';
  final project = {
    ...exampleProjects['hello']!,
    formFile:
        'formatVersion: 1\n'
        'properties:\n  Caption: Anchors\n  Width: 320\n  Height: 200\n'
        'controls:\n'
        '  - name: btnOk\n    type: Button\n'
        '    properties:\n      Caption: OK\n      Left: 229\n      Top: 163\n'
        '      Width: 83\n      Height: 29\n      Anchor: Right Bottom\n'
        '  - name: txtNote\n    type: TextBox\n'
        '    properties:\n      Left: 13\n      Top: 11\n      Width: 293\n'
        '      Height: 27\n      Anchor: Left Top Right\n'
        '  - name: lblMiddle\n    type: Label\n'
        '    properties:\n      Caption: middle\n      Left: 131\n'
        '      Top: 85\n      Width: 61\n      Height: 23\n      Anchor: ""\n',
    'Form1.gbas':
        'Sub Form_Resize()\n'
        '    Debug.Print("Resize " & Me.Width & "x" & Me.Height & " " & '
        'btnOk.Left & "," & btnOk.Top)\n'
        'End Sub\n',
  };

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdeApp(projects: {'hello': project}, strings: s));
    await tester.tap(explorerItem(formFile));
    await tester.pumpAndSettle();
  }

  String formText(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;

  ControlDecl control(WidgetTester tester, String name) =>
      readFormFile(formText(tester), name: 'Form1').form.control(name)!;

  ({int left, int top, int width, int height}) box(
    WidgetTester tester,
    String name,
  ) {
    final c = control(tester, name);
    return (
      left: c.valueOf('Left') as int,
      top: c.valueOf('Top') as int,
      width: c.valueOf('Width') as int,
      height: c.valueOf('Height') as int,
    );
  }

  Future<void> dragCorner(WidgetTester tester, Offset by) async {
    await tester.dragFrom(
      tester.getCenter(find.byKey(const ValueKey('designer.formHandle.1.1'))),
      by,
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
  }

  testWidgets('resizing the form in the designer moves the controls as '
      'their Anchor says, off the grid, and back exactly', (tester) async {
    await open(tester);
    final drawn = formText(tester);
    // The grid is on: the form's size goes to it, the controls do not.
    await dragCorner(tester, const Offset(43, 21));
    expect(find.text('Form1 (Form) · 360×224'), findsOneWidget);
    expect(box(tester, 'btnOk'), (left: 269, top: 187, width: 83, height: 29));
    expect(box(tester, 'txtNote'), (left: 13, top: 11, width: 333, height: 27));
    expect(box(tester, 'lblMiddle'), (
      left: 151,
      top: 97,
      width: 61,
      height: 23,
    ));

    // Without the grid, by odd amounts: the middle rounds down; then
    // back: every control exactly where it was drawn.
    await tester.tap(find.text(s.grid));
    await tester.pumpAndSettle();
    await dragCorner(tester, const Offset(101, -57));
    expect(find.text('Form1 (Form) · 461×167'), findsOneWidget);
    expect(box(tester, 'lblMiddle'), (
      left: 201,
      top: 68,
      width: 61,
      height: 23,
    ));
    await dragCorner(tester, const Offset(-141, 33));
    expect(find.text('Form1 (Form) · 320×200'), findsOneWidget);
    expect(formText(tester), drawn);

    // Each size change is one step of undo.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(find.text('Form1 (Form) · 461×167'), findsOneWidget);
  });

  testWidgets('a control moved after a resize is where it was put from then '
      'on', (tester) async {
    await open(tester);
    await tester.tap(find.text(s.grid));
    await tester.pumpAndSettle();
    await dragCorner(tester, const Offset(40, 0));
    // Select btnOk and move it one pixel to the left.
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.tapAt(origin + const Offset(300, 170));
    await tester.pump(const Duration(milliseconds: 500));
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(box(tester, 'btnOk').left, 268);
    await dragCorner(tester, const Offset(-40, 0));
    expect(box(tester, 'btnOk').left, 228);
  });

  testWidgets('the Anchor field opens a cross whose arms turn the edges on '
      'and off', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(propertiesTargetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('lblMiddle').last);
    await tester.pumpAndSettle();
    final field = find.byKey(propertyFieldKey('Anchor'));
    expect(
      find.descendant(of: field, matching: find.text(s.noAnchor)),
      findsOneWidget,
    );
    await tester.tap(field);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(anchorArmKey('Bottom')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(anchorArmKey('Left')));
    await tester.pumpAndSettle();
    expect(control(tester, 'lblMiddle').valueOf('Anchor'), 'Left Bottom');
    expect(formText(tester), contains('      Anchor: Left Bottom\n'));
    expect(
      find.descendant(of: field, matching: find.text('Left Bottom')),
      findsOneWidget,
    );
    await tester.tap(find.byKey(anchorArmKey('Left')));
    await tester.pumpAndSettle();
    expect(control(tester, 'lblMiddle').valueOf('Anchor'), 'Bottom');
    // Back to the default: not written.
    for (final edge in ['Bottom', 'Top', 'Left']) {
      await tester.tap(find.byKey(anchorArmKey(edge)));
      await tester.pumpAndSettle();
    }
    expect(
      'Anchor:'.allMatches(formText(tester)),
      hasLength(2),
      reason: 'btnOk and txtNote only',
    );
    expect(control(tester, 'lblMiddle').valueOf('Anchor'), defaultAnchor);
  });

  testWidgets('the run window\'s corner resizes the form: the controls '
      'follow, Form_Resize runs when it is let go; a double-click on the '
      'title puts it back', (tester) async {
    await open(tester);
    await tester.tap(find.text('Run (F5)'));
    await tester.pumpAndSettle();
    expect(
      find.text('Resize 320x200 229,163'),
      findsOneWidget,
      reason: 'shown',
    );

    final corner = find.byKey(runWindowResizeKey);
    final button = find.descendant(
      of: find.byType(RunWindow),
      matching: find.byType(GbButton),
    );
    // The window is centred: places are measured from the form's corner.
    final view = find.descendant(
      of: find.byType(RunWindow),
      matching: find.byType(GbFormView),
    );
    Offset place() => tester.getTopLeft(button) - tester.getTopLeft(view);
    final before = place();
    final gesture = await tester.startGesture(
      tester.getCenter(corner),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump();
    await gesture.moveBy(const Offset(30, 10));
    await tester.pump();
    expect(place() - before, const Offset(60, 20));
    expect(
      find.textContaining('Resize 380x220'),
      findsNothing,
      reason: 'not while dragging',
    );
    await gesture.up();
    await tester.pumpAndSettle();
    expect(find.text('Resize 380x220 289,183'), findsOneWidget);

    final title = find.descendant(
      of: find.byType(RunWindow),
      matching: find.text('Anchors'),
    );
    await tester.tap(title);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(title);
    await tester.pumpAndSettle();
    expect(find.text('Resize 320x200 229,163'), findsNWidgets(2));
    expect(place(), before);
  });
}
