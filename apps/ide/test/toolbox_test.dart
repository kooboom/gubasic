import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/designer/toolbox.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// The toolbox (D69): a tool is chosen as the button goes down, a
/// double-click places a control in the middle, and a tool dragged onto
/// the form places one where it is dropped; none of the three gets in the
/// way of another.
void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';
  const quick = Duration(milliseconds: 30);

  Future<void> open(WidgetTester tester, {Map<String, String>? project}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {'hello': project ?? exampleProjects['hello']!},
        strings: s,
      ),
    );
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
  }

  FormFile form(WidgetTester tester) => readFormFile(
    tester
        .widget<IdeShell>(find.byType(IdeShell))
        .controller
        .current
        .files[formFile]!,
    name: 'Form1',
  ).form;

  ComponentSpec? chosen(WidgetTester tester) =>
      tester.widget<Toolbox>(find.byType(Toolbox)).tool;

  Offset tool(WidgetTester tester, String type) =>
      tester.getCenter(find.byKey(ValueKey('toolbox.$type')));

  Offset onForm(WidgetTester tester, Offset p) =>
      tester.getTopLeft(find.byKey(designerFormKey)) + p;

  /// A quick click, the button down for [quick] only.
  Future<void> click(WidgetTester tester, Offset at) async {
    final mouse = await tester.startGesture(
      at,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump(quick);
    await mouse.up();
    await tester.pump(quick);
  }

  testWidgets('a quick click chooses the tool at once: a drag on the form '
      'straight after draws the control', (tester) async {
    await open(tester);
    final before = form(tester).controls.length;
    final mouse = await tester.startGesture(
      tool(tester, 'Button'),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    expect(chosen(tester), isNull, reason: 'not before the frame');
    await tester.pump();
    expect(chosen(tester)?.name, 'Button', reason: 'as the button goes down');
    await tester.pump(quick);
    await mouse.up();
    await tester.pump(quick);

    final draw = await tester.startGesture(
      onForm(tester, const Offset(150, 90)),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump(quick);
    await draw.moveTo(onForm(tester, const Offset(230, 112)));
    await tester.pump(quick);
    await draw.up();
    await tester.pumpAndSettle();
    final drawn = form(tester).controls;
    expect(drawn.length, before + 1);
    expect(boxOf(drawn.last), (left: 152, top: 88, width: 80, height: 24));
    expect(chosen(tester), isNull, reason: 'the pointer again');
  });

  testWidgets('a quick click on a tool, then a click on the form, places '
      'one of the default size there', (tester) async {
    await open(tester);
    await click(tester, tool(tester, 'Label'));
    await click(tester, onForm(tester, const Offset(160, 20)));
    await tester.pumpAndSettle();
    final added = form(tester).controls.last;
    expect(added.component.name, 'Label');
    expect(boxOf(added).left, 160);
  });

  testWidgets('a double-click on a tool places one control in the middle, '
      'and leaves the pointer chosen', (tester) async {
    await open(tester);
    final before = form(tester).controls.length;
    await tester.tap(find.byKey(const ValueKey('toolbox.CheckBox')));
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(find.byKey(const ValueKey('toolbox.CheckBox')));
    await tester.pumpAndSettle();
    final controls = form(tester).controls;
    expect(controls.length, before + 1);
    expect(controls.last.component.name, 'CheckBox');
    expect(chosen(tester), isNull);
  });

  testWidgets('a tool dragged onto the form places one of the default size '
      'where it is dropped; one undo takes it out', (tester) async {
    await open(tester);
    final before = form(tester).controls.length;
    final mouse = await tester.startGesture(
      tool(tester, 'Button'),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    for (final step in [0.25, 0.5, 0.75, 1.0]) {
      await mouse.moveTo(
        Offset.lerp(
          tool(tester, 'Button'),
          onForm(tester, const Offset(200, 64)),
          step,
        )!,
      );
      await tester.pump();
    }
    await mouse.up();
    await tester.pumpAndSettle();
    final controls = form(tester).controls;
    expect(controls.length, before + 1);
    final d = defaultSizeOf(controls.last.component);
    expect(boxOf(controls.last), (
      left: 200,
      top: 64,
      width: d.width,
      height: d.height,
    ));
    expect(chosen(tester), isNull);
    // Nothing more comes from that drag: no second control, no double-click.
    await tester.pump(const Duration(seconds: 1));
    expect(form(tester).controls.length, before + 1);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(form(tester).controls.length, before);
  });

  testWidgets('a tool dropped beside the form places nothing', (tester) async {
    await open(tester);
    final before = form(tester).controls.length;
    final mouse = await tester.startGesture(
      tool(tester, 'Button'),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await mouse.moveBy(const Offset(60, 0));
    await tester.pump();
    await mouse.moveTo(onForm(tester, const Offset(0, 400)));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    expect(form(tester).controls.length, before);
  });

  testWidgets('on a form shrunk to fit, the control goes where the user '
      'dropped it on the form they see', (tester) async {
    await open(
      tester,
      project: {
        ...exampleProjects['hello']!,
        formFile:
            'formatVersion: 1\n'
            'properties:\n  Caption: Tall\n  Width: 768\n  Height: 1024\n'
            'controls: []\n',
      },
    );
    final f = find.byKey(designerFormKey);
    final scale =
        (tester.getBottomRight(f).dy - tester.getTopLeft(f).dy) / 1024;
    expect(scale, lessThan(1));
    final mouse = await tester.startGesture(
      tool(tester, 'Label'),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await tester.pump();
    await mouse.moveBy(const Offset(60, 0));
    await tester.pump();
    await mouse.moveTo(onForm(tester, const Offset(100, 200)));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    final box = boxOf(form(tester).controls.single);
    // On the grid, as a click with the tool puts it.
    expect(box.left, snap(100 / scale, grid: true));
    expect(box.top, snap(200 / scale, grid: true));
  });
}
