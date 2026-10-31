import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';
import 'package:integration_test/integration_test.dart';

/// The Scores example in the IDE's own window (D116, D117): a score
/// changed in the Grid, the total worked out again, and the list saved as
/// a PDF file in the font the IDE carries. The save dialog is the
/// system's, so the program here writes to a folder of the test's. Run
/// with `flutter test integration_test/scores_test.dart -d macos` (or `-d
/// windows`); the clicks and the typing are the test's, not the
/// computer's. With `--dart-define=SHOTS=folder` it saves the run window
/// there as `scores-run-PLATFORM.png`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const shots = String.fromEnvironment('SHOTS');

  testWidgets('a score changed in the Grid, the list saved as a PDF file', (
    tester,
  ) async {
    final dir = await Directory.systemTemp.createTemp('gubasic');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}scores.pdf';
    final example = exampleProjects['scores']!;
    final code = example['Form1.gbas']!
        .replaceFirst(
          'If dlgSave.ShowDialog() = DialogResult.OK Then',
          'If True Then',
        )
        .replaceAll('dlgSave.FileName', '"${path.replaceAll('"', '""')}"');
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'scores': {...example, 'Form1.gbas': code},
        },
        open: 'scores',
        strings: IdeStrings.en,
      ),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byKey(runFormKey('Form1')), findsOneWidget);
    expect(find.text('3 students, total 245, average 81.7'), findsOneWidget);

    // A click chooses the cell, a second one edits it.
    final cell = find.byKey(gbGridCellKey('grdScores', 1, 2));
    await tester.tap(cell);
    await tester.pumpAndSettle();
    await tester.tap(cell);
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(gbGridEditorKey('grdScores')), '95');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
    expect(find.text('3 students, total 255, average 85.0'), findsOneWidget);

    if (shots.isNotEmpty) {
      final area = tester.getRect(find.byKey(runFormKey('Form1')));
      final ratio = tester.view.devicePixelRatio;
      await tester.runAsync(() async {
        final view = tester.binding.renderViews.first;
        final image = await (view.debugLayer! as OffsetLayer).toImage(
          Rect.fromLTRB(
            area.left * ratio,
            (area.top - 40) * ratio,
            area.right * ratio,
            area.bottom * ratio,
          ),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$shots/scores-run-${Platform.operatingSystem}.png');
        await file.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }

    await tester.tap(find.text('Save PDF'));
    for (var i = 0; i < 100 && !File(path).existsSync(); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Saved $path'), findsOneWidget);
    final bytes = File(path).readAsBytesSync();
    final text = String.fromCharCodes(bytes);
    expect(text, startsWith('%PDF-1.4'));
    expect(text, contains('+NanumGothic'));
    expect(bytes.length, lessThan(40000));
    if (shots.isNotEmpty) File(path).copySync('$shots/scores.pdf');
  });
}
