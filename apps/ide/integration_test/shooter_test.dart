import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/project_pictures.dart';
import 'package:gubasic_ide/src/project/project_sounds.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart' show GbSprite;
import 'package:gubasic_test_support/gubasic_test_support.dart';
import 'package:integration_test/integration_test.dart';

/// The Shooter example in the IDE's own window (docs/DESIGN.md D138): the
/// game starts on its button, the keys the test sends (not the computer's)
/// move the ship and fire, the sounds play through the real engine, and
/// the score goes up. Run with `dart run gubasic_test_support:integration
/// integration_test/shooter_test.dart -d windows` (or `-d macos`); with
/// `--dart-define=SHOTS=folder` it saves the run window there as
/// `shooter-PLATFORM.png`. CI runs it on Windows and macOS.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const shots = String.fromEnvironment('SHOTS');
  testWidgetsKeepingFailures('the shooter runs, with keys held and sounds', (
    tester,
  ) async {
    await tester.pumpWidget(
      IdeApp(
        projects: {'shooter': exampleProjects['shooter']!},
        examplePictures: {
          'shooter': decodeExamplePictures(examplePictures)['shooter']!,
        },
        exampleSounds: {
          'shooter': decodeExampleSounds(exampleSounds)['shooter']!,
        },
        open: 'shooter',
        strings: IdeStrings.ko,
      ),
    );
    await tester.pumpAndSettle();

    String textOf(Finder f) => switch (tester.widget(f)) {
      final Text t => t.data ?? '',
      final other => '$other',
    };

    /// Lets real time pass until [ok] holds.
    Future<void> until(String what, bool Function() ok) async {
      for (var i = 0; i < 400; i++) {
        if (ok()) return;
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      fail('waited 20 seconds for $what');
    }

    await tester.tap(find.byKey(const ValueKey('toolbar.run')));
    await until(
      'the form',
      () => find.byKey(runFormKey('Form1')).evaluate().isNotEmpty,
    );
    final score = find.textContaining('점수 ');
    await until('the score', () => score.evaluate().isNotEmpty);
    expect(textOf(score.first), '점수 0');
    // Start: the music and the loop begin.
    await tester.tap(find.text('시작'));
    await tester.pump();
    // A player's hands: fire all the time, go right a little, then left
    // until the ship is under the first lane, and stay there. The first
    // enemy comes down that lane a second after Start and meets the shots
    // whatever the computer's speed; a ship swept to the edge would fire
    // past it (the edge is left of the lane's middle).
    int shipLeft() => tester
        .widget<GbSprite>(
          find.byWidgetPredicate(
            (w) => w is GbSprite && w.state.name?.toLowerCase() == 'sprship',
          ),
        )
        .state
        .integer('Left');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await until('the ship going right', () => shipLeft() > 240);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    // The lane is 96 wide and its enemy 32, at 32 to 64; the shot leaves
    // the ship's middle, Left + 13 to Left + 19.
    await until('the ship under the first lane', () => shipLeft() <= 40);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await until(
      'a hit',
      () => score.evaluate().isNotEmpty && textOf(score.first) != '점수 0',
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
    expect(textOf(score.first), isNot('점수 0'));
    expect(find.textContaining('목숨 '), findsWidgets);
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
        final file = File('$shots/shooter-${Platform.operatingSystem}.png');
        await file.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }
    await tester.tap(find.byKey(const ValueKey('toolbar.stop')));
    await tester.pumpAndSettle();
  });
}
