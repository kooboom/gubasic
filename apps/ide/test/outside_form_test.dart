import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/form_window.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// Controls outside the form (D72): marked, counted and named above the
/// designer, and brought inside in one step.
void main() {
  const formFile = 'Form1.form.yaml';
  const size = (width: 360, height: 800);

  /// A desktop form: one control on the right, one wider than a phone,
  /// one at the top left that stays inside a phone.
  const desktop =
      'formatVersion: 1\n'
      'properties:\n  Caption: Quiz\n  Width: 800\n  Height: 600\n'
      'controls:\n'
      '  - name: lblTitle\n    type: Label\n'
      '    properties:\n      Caption: Title\n      Left: 16\n      Top: 16\n'
      '      Width: 120\n'
      '  - name: txtAnswer\n    type: TextBox\n'
      '    properties:\n      Left: 16\n      Top: 56\n      Width: 500\n'
      '  - name: btnNext\n    type: Button\n'
      '    properties:\n      Caption: Next\n      Left: 600\n      Top: 520\n'
      '      Width: 120\n      Height: 40\n';

  test('a box is outside when any edge is past the form', () {
    expect(
      isOutside((left: 0, top: 0, width: 360, height: 800), size),
      isFalse,
    );
    expect(isOutside((left: -1, top: 0, width: 10, height: 10), size), isTrue);
    expect(isOutside((left: 351, top: 0, width: 10, height: 10), size), isTrue);
    expect(isOutside((left: 0, top: 791, width: 10, height: 10), size), isTrue);
  });

  test('a box that fits is moved in; a larger one keeps its start', () {
    expect(fittedInside((left: 600, top: 520, width: 120, height: 40), size), (
      left: 240,
      top: 520,
      width: 120,
      height: 40,
    ));
    expect(fittedInside((left: 16, top: 56, width: 500, height: 24), size), (
      left: 16,
      top: 56,
      width: 344,
      height: 24,
    ), reason: 'larger than the form: its start kept');
    expect(fittedInside((left: -20, top: 900, width: 50, height: 900), size), (
      left: 0,
      top: 0,
      width: 50,
      height: 800,
    ));
    expect(fittedInside((left: 355, top: 0, width: 400, height: 20), size), (
      left: 0,
      top: 0,
      width: 360,
      height: 20,
    ), reason: 'no room after its start: the width of the form');
  });

  Future<void> open(
    WidgetTester tester, {
    IdeStrings strings = IdeStrings.en,
    String formText = desktop,
  }) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'hello': {
            ...exampleProjects['hello']!,
            formFile: formText,
            'Form1.gbas': '',
          },
        },
        strings: strings,
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

  Future<void> phone(WidgetTester tester) async {
    await tester.tap(find.byKey(designerMenuKey('toolbar.size')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(designerMenuKey('preset.phone')));
    await tester.pumpAndSettle();
  }

  testWidgets('a phone size leaves two controls outside: counted, named, '
      'a name selects; Fit brings them inside, one undo puts them back', (
    tester,
  ) async {
    await open(tester);
    expect(find.byKey(designerOutsideKey), findsNothing);
    await phone(tester);
    expect(find.text('2 controls are outside the form:'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('designer.outside.lblTitle')),
      findsNothing,
    );

    // The names scroll sideways when the bar is narrow.
    await tester.ensureVisible(
      find.byKey(const ValueKey('designer.outside.btnNext')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('designer.outside.btnNext')));
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byKey(propertiesTargetKey),
        matching: find.text('btnNext'),
      ),
      findsOneWidget,
    );

    final before = form(tester);
    await tester.tap(find.byKey(designerFitInsideKey));
    await tester.pumpAndSettle();
    final after = form(tester);
    expect(controlsOutside(after), isEmpty);
    expect(boxOf(after.control('btnNext')!), (
      left: 240,
      top: 520,
      width: 120,
      height: 40,
    ));
    expect(boxOf(after.control('txtAnswer')!).left, 16);
    expect(boxOf(after.control('txtAnswer')!).width, 344);
    expect(
      boxOf(after.control('lblTitle')!),
      boxOf(before.control('lblTitle')!),
    );
    expect(find.byKey(designerOutsideKey), findsNothing);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(boxOf(form(tester).control('btnNext')!).left, 600);
    expect(boxOf(form(tester).control('txtAnswer')!).width, 500);
    expect(find.byKey(designerOutsideKey), findsOneWidget);
  });

  testWidgets('one control: said so; while the program runs, Fit cannot be '
      'pressed', (tester) async {
    // Without the wide TextBox: only btnNext is outside a phone.
    await open(
      tester,
      formText: desktop.replaceFirst('Width: 500', 'Width: 300'),
    );
    await phone(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    expect(find.text('1 control is outside the form:'), findsOneWidget);
    expect(
      tester.widget<OutlinedButton>(find.byKey(designerFitInsideKey)).onPressed,
      isNull,
    );
  });

  testWidgets('the bar lies over the canvas: as it comes and goes, the form, '
      'its scale and the Properties window stay where they are, and it covers '
      'neither the form nor its handles (D75)', (tester) async {
    await open(tester);
    await phone(tester);
    Rect rect(Finder f) => tester.getRect(f);
    final form = find.byKey(designerFormKey);
    final window = find.byType(FormWindowFrame);
    final panel = find.byType(PropertiesPanel);
    final corner = find.byKey(const ValueKey('designer.formHandle.1.1'));
    final bar = find.byKey(designerOutsideKey);
    expect(bar, findsOneWidget);
    final withBar = (rect(form), rect(panel), rect(corner));
    expect(rect(bar).bottom, lessThanOrEqualTo(rect(window).top));
    expect(rect(bar).right, lessThanOrEqualTo(rect(panel).left));

    // A selected control's handles are inside the form: below the bar.
    // The names scroll sideways when the bar is narrow.
    await tester.ensureVisible(
      find.byKey(const ValueKey('designer.outside.btnNext')),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('designer.outside.btnNext')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(designerFitInsideKey));
    await tester.pumpAndSettle();
    expect(bar, findsNothing);
    expect((rect(form), rect(panel), rect(corner)), withBar);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
    expect(bar, findsOneWidget);
    expect((rect(form), rect(panel), rect(corner)), withBar);
  });

  testWidgets('Korean words', (tester) async {
    await open(tester, strings: IdeStrings.ko);
    await phone(tester);
    expect(find.text('폼 밖으로 나간 컨트롤 2개:'), findsOneWidget);
    expect(find.text('폼 안으로 맞추기'), findsOneWidget);
  });
}
