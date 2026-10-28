import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/explorer.dart';

/// Frames in the designer (docs/DESIGN.md D105): a control drawn or
/// dropped in one goes into it; one in it moves in it; the Frame moves,
/// is deleted, copied and pasted with the controls in it; a control pasted
/// with a Frame chosen goes into the Frame.
void main() {
  const s = IdeStrings.en;
  const form1 = 'Form1.form.yaml';
  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n'
        '  - Form1\n',
    form1:
        'formatVersion: 2\nproperties:\n  Width: 400\n  Height: 300\n'
        'controls:\n'
        '  - name: fraA\n    type: Frame\n    properties:\n'
        '      Caption: A\n      Left: 16\n      Top: 16\n'
        '      Width: 200\n      Height: 120\n'
        '    controls:\n'
        '      - name: btnIn\n        type: Button\n        properties:\n'
        '          Caption: In\n          Left: 16\n          Top: 32\n'
        '          Width: 80\n          Height: 24\n'
        '  - name: lblOut\n    type: Label\n    properties:\n'
        '      Caption: Out\n      Left: 240\n      Top: 16\n'
        '      Width: 96\n      Height: 24\n',
    'Form1.gbas': '',
  };

  setUp(clearDesignerClipboard);

  FormFile form(WidgetTester tester) => readFormFile(
    tester
        .widget<IdeShell>(find.byType(IdeShell))
        .controller
        .current
        .files[form1]!,
    name: 'Form1',
  ).form;

  String where(FormFile f, String name) {
    final c = f.control(name)!;
    return '${c.container} ${c.valueOf('Left')},${c.valueOf('Top')}';
  }

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

  Future<void> drag(WidgetTester tester, Offset from, Offset to) async {
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
    await tester.pumpAndSettle();
    await tester.pump(const Duration(milliseconds: 500));
  }

  Future<void> click(WidgetTester tester, Offset at) => drag(tester, at, at);

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testWidgets('a control in a Frame is chosen there and moves in it; the '
      'Frame moves with it', (tester) async {
    await open(tester);
    // btnIn is seen at (32, 48) on the form.
    await click(tester, const Offset(40, 56));
    expect(
      find.text('btnIn (Button) · Left 16, Top 32 · 80×24'),
      findsOneWidget,
    );
    await drag(tester, const Offset(40, 56), const Offset(48, 64));
    expect(where(form(tester), 'btnIn'), 'fraA 24,40');

    // The Frame's empty part: the Frame, which takes btnIn along.
    await drag(tester, const Offset(180, 110), const Offset(204, 126));
    expect(where(form(tester), 'fraA'), 'null 40,32');
    expect(where(form(tester), 'btnIn'), 'fraA 24,40');
    // btnIn is where the Frame took it.
    await click(tester, const Offset(72, 80));
    expect(
      find.text('btnIn (Button) · Left 24, Top 40 · 80×24'),
      findsOneWidget,
    );
  });

  testWidgets('a control drawn in a Frame goes into it, inside it as far '
      'as it fits', (tester) async {
    await open(tester);
    await tester.tap(find.byKey(const ValueKey('toolbox.Label')));
    await tester.pump();
    await click(tester, const Offset(120, 96));
    // From the Frame's corner (104, 80), moved in to fit 120×24.
    expect(where(form(tester), 'Label1'), 'fraA 80,80');
    await tester.tap(find.byKey(const ValueKey('toolbox.Label')));
    await tester.pump();
    await click(tester, const Offset(240, 200));
    expect(where(form(tester), 'Label2'), 'null 240,200');
  });

  testWidgets('deleted, copied and pasted with the controls in it; pasted '
      'into a chosen Frame', (tester) async {
    await open(tester);
    await click(tester, const Offset(180, 110));
    expect(find.textContaining('fraA (Frame)'), findsOneWidget);
    await ctrl(tester, LogicalKeyboardKey.keyC);
    await click(tester, const Offset(300, 250));
    await ctrl(tester, LogicalKeyboardKey.keyV);
    var f = form(tester);
    // The copies: a new Frame, and a new Button in it.
    expect(f.control('Frame1')!.container, isNull);
    expect(where(f, 'Button1'), 'Frame1 16,32');

    // lblOut pasted with fraA chosen: into fraA.
    await click(tester, const Offset(260, 24));
    await ctrl(tester, LogicalKeyboardKey.keyC);
    // Where Frame1, pasted a step down and right, does not cover fraA.
    await click(tester, const Offset(20, 100));
    await ctrl(tester, LogicalKeyboardKey.keyV);
    f = form(tester);
    expect(f.control('Label1')!.container, 'fraA');
    expect(f.inside('fraA').map((c) => c.name), ['btnIn', 'Label1']);

    // Deleting fraA deletes what is in it.
    await click(tester, const Offset(20, 100));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    f = form(tester);
    expect(f.controls.map((c) => c.name), ['lblOut', 'Frame1', 'Button1']);
  });

  test('the form made wider: a Frame anchored to its right grows, and a '
      'control anchored to the Frame\'s right moves', () {
    final f = readFormFile('''
formatVersion: 2
properties: { Width: 400, Height: 300 }
controls:
  - name: fraA
    type: Frame
    properties: { Left: 16, Top: 16, Width: 200, Height: 120, Anchor: Left Top Right }
    controls:
      - { name: btnIn, type: Button, properties: { Left: 100, Top: 32, Width: 80, Height: 24, Anchor: Right Top } }
''', name: 'Form1').form;
    final wider = withAnchoredSize(f, (
      width: 440,
      height: 300,
    ), anchorBaseOf(f));
    expect(wider.control('fraA')!.valueOf('Width'), 240);
    expect(where(wider, 'btnIn'), 'fraA 140,32');
    expect(boxOn(wider, wider.control('btnIn')!), (
      left: 156,
      top: 48,
      width: 80,
      height: 24,
    ));
  });
}
