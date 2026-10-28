import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/explorer.dart';

/// The form size presets (D60): phone 360×800, tablet 768×1024, desktop
/// 800×600, and turning the form; the controls move as their Anchor says,
/// and going back puts each exactly where it was.
void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';

  /// A phone form whose controls use every kind of Anchor, at places off
  /// the grid and odd, so that a halving would show.
  final phoneForm =
      'formatVersion: 1\n'
      'properties:\n  Caption: Phone\n  Width: 360\n  Height: 800\n'
      'controls:\n'
      '  - name: lblTitle\n    type: Label\n'
      '    properties:\n      Caption: Title\n      Left: 13\n      Top: 9\n'
      '      Width: 335\n      Height: 27\n      Anchor: Left Top Right\n'
      '  - name: lstItems\n    type: ListBox\n'
      '    properties:\n      Left: 13\n      Top: 45\n      Width: 335\n'
      '      Height: 691\n      Anchor: Left Top Right Bottom\n'
      '  - name: btnOk\n    type: Button\n'
      '    properties:\n      Caption: OK\n      Left: 257\n      Top: 747\n'
      '      Width: 91\n      Height: 41\n      Anchor: Right Bottom\n'
      '  - name: lblMiddle\n    type: Label\n'
      '    properties:\n      Caption: middle\n      Left: 151\n'
      '      Top: 389\n      Width: 59\n      Height: 23\n      Anchor: ""\n'
      '  - name: btnBack\n    type: Button\n'
      '    properties:\n      Caption: Back\n      Left: 13\n      Top: 747\n'
      '      Width: 91\n      Height: 41\n      Anchor: Left Bottom\n';

  Future<void> open(WidgetTester tester, String form) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'hello': {...exampleProjects['hello']!, formFile: form},
        },
        strings: s,
      ),
    );
    await tester.tap(explorerItem(formFile));
    await tester.pumpAndSettle();
  }

  String formText(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;

  FormFile form(WidgetTester tester) =>
      readFormFile(formText(tester), name: 'Form1').form;

  ControlBox box(WidgetTester tester, String name) =>
      boxOf(form(tester).control(name)!);

  Future<void> preset(WidgetTester tester, FormSizePreset p) async {
    await tester.tap(find.byKey(designerMenuKey('toolbar.size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(designerMenuKey('preset.${p.name}')));
    await tester.pumpAndSettle();
  }

  Future<void> turn(WidgetTester tester) async {
    await tester.tap(find.byKey(designerMenuKey('toolbar.turn')));
    await tester.pumpAndSettle();
  }

  testWidgets('phone → tablet → phone puts every control back exactly, its '
      'Left, Top, Width and Height', (tester) async {
    await open(tester, phoneForm);
    expect(find.text('${s.phonePreset} · 360×800'), findsOneWidget);

    await preset(tester, FormSizePreset.tablet);
    expect(formSizeOf(form(tester)), (width: 768, height: 1024));
    expect(find.text('${s.tabletPreset} · 768×1024'), findsOneWidget);
    expect(box(tester, 'lblTitle'), (left: 13, top: 9, width: 743, height: 27));
    expect(box(tester, 'lstItems'), (
      left: 13,
      top: 45,
      width: 743,
      height: 915,
    ));
    expect(box(tester, 'btnOk'), (left: 665, top: 971, width: 91, height: 41));
    expect(box(tester, 'lblMiddle'), (
      left: 355,
      top: 501,
      width: 59,
      height: 23,
    ));
    expect(box(tester, 'btnBack'), (left: 13, top: 971, width: 91, height: 41));

    await preset(tester, FormSizePreset.phone);
    expect(formText(tester), phoneForm);
  });

  testWidgets('through every preset and turned, then phone again: still '
      'exactly the phone form', (tester) async {
    await open(tester, phoneForm);
    await preset(tester, FormSizePreset.desktop);
    expect(formSizeOf(form(tester)), (width: 800, height: 600));
    // 600 is less than 800: stretched controls shrink, the middle goes up
    // by half, rounded down.
    expect(box(tester, 'lstItems').height, 491);
    expect(box(tester, 'lblMiddle'), (
      left: 371,
      top: 289,
      width: 59,
      height: 23,
    ));
    await turn(tester);
    expect(formSizeOf(form(tester)), (width: 600, height: 800));
    await preset(tester, FormSizePreset.tablet);
    await turn(tester);
    expect(formSizeOf(form(tester)), (width: 1024, height: 768));
    expect(find.text('${s.tabletPreset} · 1024×768'), findsOneWidget);
    await preset(tester, FormSizePreset.phone);
    expect(formText(tester), phoneForm);

    // One step of undo each: back through the turned tablet.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(formSizeOf(form(tester)), (width: 1024, height: 768));
  });

  testWidgets('a control moved between presets is kept where it was put; '
      'the others still go back exactly', (tester) async {
    await open(tester, phoneForm);
    await preset(tester, FormSizePreset.tablet);
    // Move btnBack one pixel right in the Properties window: it is below
    // what the designer shows of a tablet form.
    await tester.tap(find.byKey(propertiesTargetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text('btnBack').last);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(propertyFieldKey('Left')), '14');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(box(tester, 'btnBack').left, 14);
    await preset(tester, FormSizePreset.phone);
    expect(box(tester, 'btnBack'), (left: 14, top: 747, width: 91, height: 41));
    expect(box(tester, 'btnOk'), (left: 257, top: 747, width: 91, height: 41));
    expect(box(tester, 'lblMiddle'), (
      left: 151,
      top: 389,
      width: 59,
      height: 23,
    ));
  });

  test('presetOf knows each preset upright and turned', () {
    expect(presetOf((width: 360, height: 800)), (
      name: FormSizePreset.phone,
      turned: false,
    ));
    expect(presetOf((width: 1024, height: 768)), (
      name: FormSizePreset.tablet,
      turned: true,
    ));
    expect(presetOf((width: 320, height: 120)), isNull);
  });
}
