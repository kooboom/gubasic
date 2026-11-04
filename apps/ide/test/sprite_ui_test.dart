import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/project_pictures.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/explorer.dart';

/// A Sprite in the designer (docs/DESIGN.md D138): placed from the
/// toolbox, its Frames chosen one picture at a time in the Properties
/// window, and its size taken from the first frame once.
void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        examplePictures: decodeExamplePictures(examplePictures),
        strings: s,
        open: 'quiz',
      ),
    );
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

  Future<void> chooseFrame(WidgetTester tester, String label) async {
    await tester.tap(find.byKey(propertyFieldKey('Frames')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(label).last);
    await tester.pumpAndSettle();
  }

  testWidgets('Frames are chosen one picture at a time; the first gives '
      'the size once', (tester) async {
    await start(tester);
    await tester.tap(explorerItem(formFile));
    await tester.pumpAndSettle();
    final tool = find.byKey(const ValueKey('toolbox.Sprite'));
    await tester.tap(tool);
    await tester.pump(kDoubleTapMinTime);
    await tester.tap(tool);
    await tester.pumpAndSettle();
    var sprite = form(tester).controls
        .singleWhere((c) => c.component.name == 'Sprite');
    expect(sprite.name, 'Sprite1');
    expect(sprite.valueOf('Frames'), '');
    expect([sprite.valueOf('Width'), sprite.valueOf('Height')], [32, 32]);
    expect(find.text(s.noPicture), findsOneWidget);

    final triangle = decodeExamplePictures(
      examplePictures,
    )['quiz']!['triangle.png']!;
    final size = pictureSize(triangle)!;
    await chooseFrame(tester, 'triangle.png');
    sprite = form(tester).control('Sprite1')!;
    expect(sprite.valueOf('Frames'), 'triangle.png');
    expect(
      [sprite.valueOf('Width'), sprite.valueOf('Height')],
      [size.$1, size.$2],
    );

    // A second frame goes after the first; the size stays.
    await chooseFrame(tester, 'pentagon.png');
    sprite = form(tester).control('Sprite1')!;
    expect(sprite.valueOf('Frames'), 'triangle.png, pentagon.png');
    expect(sprite.valueOf('Width'), size.$1);
    // Unchecked, the first leaves; the Properties window shows the rest.
    await chooseFrame(tester, 'triangle.png');
    sprite = form(tester).control('Sprite1')!;
    expect(sprite.valueOf('Frames'), 'pentagon.png');
    expect(find.text('pentagon.png'), findsWidgets);
    // "No picture" clears them.
    await chooseFrame(tester, s.noPicture);
    expect(form(tester).control('Sprite1')!.valueOf('Frames'), '');
  });
}
