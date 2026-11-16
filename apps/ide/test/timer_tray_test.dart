import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

/// A Timer in the designer (docs/DESIGN.md D100): it is not drawn on the
/// form but kept in a tray under it, chosen, given properties, opened and
/// deleted there.
void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const formFile = 'Form1.form.yaml';

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdeApp(projects: {'hello': hello}, strings: s));
    await tester.pumpAndSettle();
  }

  String text(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;

  testWidgets('a Timer from the toolbox goes into the tray, without a place', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(designerTrayKey), findsNothing);
    final tool = find.byKey(const ValueKey('toolbox.Timer'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    expect(find.byKey(designerTrayKey), findsOneWidget);
    expect(find.byKey(const ValueKey('designer.tray.Timer1')), findsOneWidget);
    expect(text(tester), endsWith('  - name: Timer1\n    type: Timer\n'));
    expect(find.text('Timer1 (Timer)'), findsOneWidget, reason: 'chosen');
    // Its properties, and no place or size.
    expect(find.byKey(propertyFieldKey('Interval')), findsOneWidget);
    expect(find.byKey(propertyFieldKey('Enabled')), findsOneWidget);
    expect(find.byKey(propertyFieldKey('Left')), findsNothing);

    // The tool and a click on the form: the next one, into the tray too.
    await tester.tap(tool);
    await tester.pump();
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.tapAt(
      origin + const Offset(200, 20),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('designer.tray.Timer2')), findsOneWidget);
    expect(text(tester), isNot(contains('Left: 200')));
  });

  testWidgets('a click chooses it, a double-click opens its Tick, Delete '
      'deletes it', (tester) async {
    await open(tester);
    final tool = find.byKey(const ValueKey('toolbox.Timer'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    final chip = find.byKey(const ValueKey('designer.tray.Timer1'));

    // The form chosen, then the Timer again.
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.tapAt(
      origin + const Offset(300, 100),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Form1 (Form) · 320×120'), findsOneWidget);
    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('Timer1 (Timer)'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(text(tester), hello[formFile]);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(chip, findsOneWidget);

    await tester.tap(chip);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(chip);
    await tester.pumpAndSettle();
    expect(find.byType(CodeEditor), findsOneWidget);
    expect(
      tester
          .widget<IdeShell>(find.byType(IdeShell))
          .controller
          .current
          .files['Form1.gbas'],
      contains('Sub Timer1_Tick()\n'),
    );
  });

  Future<Finder> placeTimer(WidgetTester tester) async {
    final tool = find.byKey(const ValueKey('toolbox.Timer'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    return find.byKey(const ValueKey('designer.tray.Timer1'));
  }

  testWidgets('a right click on it opens the menu; Delete there deletes it', (
    tester,
  ) async {
    await open(tester);
    final chip = await placeTimer(tester);
    await tester.tapAt(
      tester.getCenter(chip),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryButton,
    );
    await tester.pumpAndSettle();
    // Front and back are for controls on the form.
    expect(
      tester
          .widget<PopupMenuItem<VoidCallback>>(
            find.byKey(designerMenuKey('front')),
          )
          .enabled,
      isFalse,
    );
    await tester.tap(find.byKey(designerMenuKey('delete')));
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(text(tester), hello[formFile]);
  });

  testWidgets('Backspace and Edit → Delete delete it; undo brings it back', (
    tester,
  ) async {
    await open(tester);
    final chip = await placeTimer(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    await tester.tap(find.byKey(const ValueKey('menu.edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.edit.undo')));
    await tester.pumpAndSettle();
    expect(chip, findsOneWidget, reason: 'Edit → Undo');

    await tester.tap(chip);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.tap(find.byKey(const ValueKey('menu.edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.edit.delete')));
    await tester.pumpAndSettle();
    expect(chip, findsNothing);
    expect(text(tester), hello[formFile]);
  });

  testWidgets('Edit → Delete in a field of the Properties window deletes '
      'text, not the control', (tester) async {
    await open(tester);
    final chip = await placeTimer(tester);
    final field = find.descendant(
      of: find.byKey(propertyFieldKey('Interval')),
      matching: find.byType(EditableText),
    );
    await tester.tap(field);
    await tester.pump();
    // The caret at the start: Delete takes the first digit of 100.
    final editable = tester.state<EditableTextState>(field);
    editable.userUpdateTextEditingValue(
      editable.textEditingValue.copyWith(
        selection: const TextSelection.collapsed(offset: 0),
      ),
      SelectionChangedCause.tap,
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('menu.edit')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.edit.delete')));
    await tester.pumpAndSettle();
    expect(chip, findsOneWidget);
    expect(tester.widget<EditableText>(field).controller.text, '00');
  });
}
