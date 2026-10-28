import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'support/explorer.dart';

/// A form larger than the space is shrunk to fit (D66), in the designer
/// and in the run window; the mouse works on it as the user sees it.
void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';
  // A tablet form, 768 x 1024: taller than the designer and the run area.
  final tall = {
    ...exampleProjects['hello']!,
    formFile:
        'formatVersion: 1\n'
        'properties:\n  Caption: Tall\n  Width: 768\n  Height: 1024\n'
        'controls:\n'
        '  - name: btnBottom\n    type: Button\n'
        '    properties:\n      Caption: Bottom\n      Left: 40\n      Top: 900\n'
        '      Width: 200\n      Height: 64\n',
    'Form1.gbas':
        'Sub btnBottom_Click()\n    Debug.Print("clicked")\nEnd Sub\n',
  };

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(IdeApp(projects: {'hello': tall}, strings: s));
    await tester.tap(explorerItem(formFile));
    await tester.pumpAndSettle();
  }

  String formText(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;

  Rect onScreen(WidgetTester tester, Finder f) =>
      Rect.fromPoints(tester.getTopLeft(f), tester.getBottomRight(f));

  test('fitScale shrinks, never grows, never below a tenth', () {
    expect(fitScale(const Size(100, 200), const Size(100, 100)), 0.5);
    expect(fitScale(const Size(100, 100), const Size(400, 400)), 1);
    expect(fitScale(const Size(10000, 100), const Size(100, 100)), 0.1);
  });

  testWidgets('the designer shows a tall form whole, and a drag moves a '
      'control as far as the user sees it move', (tester) async {
    await open(tester);
    final form = onScreen(tester, find.byKey(designerFormKey));
    expect(form.height, lessThan(1024));
    expect(form.bottom, lessThan(900), reason: 'all of it shows');
    final scale = form.height / 1024;
    expect(find.text('${(scale * 100).floor()}%'), findsOneWidget);

    // Without the grid, a drag of 60 on the screen moves it 60 / scale.
    await tester.tap(find.text(s.grid));
    await tester.pumpAndSettle();
    final button = tester.getCenter(
      find.descendant(
        of: find.byKey(designerFormKey),
        matching: find.text('Bottom'),
      ),
    );
    final mouse = await tester.startGesture(
      button,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.moveBy(const Offset(30, 0));
    await tester.pump();
    await mouse.moveBy(const Offset(30, 0));
    await tester.pump();
    await mouse.up();
    await tester.pumpAndSettle();
    final left = readFormFile(
      formText(tester),
      name: 'Form1',
    ).form.control('btnBottom')!.valueOf('Left') as int;
    expect(left, closeTo(40 + 60 / scale, 1));

    // Off: the form at its own size.
    await tester.tap(find.byKey(designerMenuKey('toolbar.fit')));
    await tester.pumpAndSettle();
    expect(onScreen(tester, find.byKey(designerFormKey)).height, 1024);
    expect(find.textContaining('%'), findsNothing);
  });

  testWidgets('the run window shows a tall form whole, and its button takes '
      'a click there; the switch turns it off', (tester) async {
    await open(tester);
    await tester.tap(find.text('Run (F5)'));
    await tester.pumpAndSettle();
    final view = find.descendant(
      of: find.byType(RunWindow),
      matching: find.byType(GbFormView),
    );
    final shown = onScreen(tester, view);
    expect(shown.height, lessThan(1024));
    expect(shown.bottom, lessThan(900));
    await tester.tap(
      find.descendant(
        of: find.byType(RunWindow),
        matching: find.text('Bottom'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('clicked'), findsOneWidget);

    // The corner, shrunk: a drag of 30 makes the form 30 / scale wider.
    final scale = shown.height / 1024;
    final model = tester.widget<GbFormView>(view).model;
    final gesture = await tester.startGesture(
      tester.getCenter(find.byKey(runWindowResizeKey)),
      kind: PointerDeviceKind.mouse,
    );
    await gesture.moveBy(const Offset(30, 0));
    await tester.pump();
    await gesture.up();
    await tester.pumpAndSettle();
    expect(model.form.integer('Width'), closeTo(768 + 30 / scale, 1));

    await tester.tap(find.byKey(runWindowFitKey));
    await tester.pumpAndSettle();
    expect(onScreen(tester, view).height, 1024);
  });
}
