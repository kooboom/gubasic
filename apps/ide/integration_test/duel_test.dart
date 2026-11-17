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
import 'package:gubasic_test_support/gubasic_test_support.dart';
import 'package:integration_test/integration_test.dart';

/// The Duel example in the IDE's own window (docs/DESIGN.md D139): two
/// players on one keyboard, the keys the test sends (not the computer's).
/// The start buttons hide; both walk in, holding their keys; 1P punches
/// with F and 2P with the period key, a punctuation key, until each has
/// hurt the other; 1P's jump kick goes through a crouching block and is
/// stopped by a standing one; B shows the training view. Run with `dart run
/// gubasic_test_support:integration integration_test/duel_test.dart -d
/// windows` (or `-d macos`); with `--dart-define=SHOTS=folder` it saves
/// the run window there as `duel-PLATFORM.png`. CI runs it on Windows and
/// macOS.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const shots = String.fromEnvironment('SHOTS');
  testWidgetsKeepingFailures('two players fight with one keyboard', (
    tester,
  ) async {
    await tester.pumpWidget(
      IdeApp(
        projects: {'duel': exampleProjects['duel']!},
        examplePictures: {
          'duel': decodeExamplePictures(examplePictures)['duel']!,
        },
        exampleSounds: {'duel': decodeExampleSounds(exampleSounds)['duel']!},
        open: 'duel',
        strings: IdeStrings.ko,
      ),
    );
    await tester.pumpAndSettle();

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
    final host = tester.widget<RunWindow>(find.byType(RunWindow)).session.host;
    int width(String label) =>
        host.modelOf('Form1').control(label)!.integer('Width');
    int left(String sprite) =>
        host.modelOf('Form1').control(sprite)!.integer('Left');

    await tester.tap(find.text('2인'));
    await tester.pump();
    expect(find.text('2인'), findsNothing, reason: 'hidden for the match');

    // Both walk in, each holding a key: A and D are 1P's, the arrows 2P's.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await until(
      'the fighters meeting',
      () => left('sprFighter2') - left('sprFighter1') < 64,
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);

    // Punches, each a press: F for 1P, the period key for 2P.
    Future<void> punchUntilHurt(LogicalKeyboardKey key, String bar) async {
      for (var i = 0; i < 40 && width(bar) >= 220; i++) {
        await tester.sendKeyEvent(key);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 400)),
        );
        await tester.pump();
      }
      expect(width(bar), lessThan(220), reason: '$bar after the punches');
    }

    await punchUntilHurt(LogicalKeyboardKey.keyF, 'lblBar2');
    // Pushed back by the punches, 2P walks in again first.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await until(
      '2P walking in',
      () => left('sprFighter2') - left('sprFighter1') < 64,
    );
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await punchUntilHurt(LogicalKeyboardKey.period, 'lblBar1');

    // Jump attacks are high: a crouching block does not stop them, a
    // standing one does. 1P walks in, then jumps and kicks at once.
    Future<void> walkIn() async {
      await tester.sendKeyDownEvent(LogicalKeyboardKey.keyD);
      await until(
        '1P walking in',
        () => left('sprFighter2') - left('sprFighter1') < 60,
      );
      await tester.sendKeyUpEvent(LogicalKeyboardKey.keyD);
    }

    Future<void> wait(int ms) =>
        tester.runAsync(() => Future<void>.delayed(Duration(milliseconds: ms)));

    await wait(500);
    await walkIn();
    final before = width('lblBar2');
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
    await until('the jump kick through a crouching block', () {
      return width('lblBar2') < before;
    });
    await wait(900);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowDown);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    await tester.pump();

    // A standing block stops it: 2P is seen blocking, and keeps its health.
    await wait(500);
    await walkIn();
    final standing = width('lblBar2');
    String frames2() =>
        host.modelOf('Form1').control('sprFighter2')!.text('Frames');
    var blocked = false;
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyW);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
    for (var i = 0; i < 24; i++) {
      blocked = blocked || frames2() == 'p2_block.png';
      await wait(50);
      await tester.pump();
    }
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowRight);
    expect(blocked, isTrue, reason: '2P blocked standing');
    expect(width('lblBar2'), standing, reason: 'no damage when blocked');

    // The training view: the bundles shown, as the keys fill them.
    await tester.sendKeyEvent(LogicalKeyboardKey.keyB);
    await until('the training view', () {
      final label = host.modelOf('Form1').control('lblInputs1')!;
      return label['Visible'] == true;
    });
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyS);
    await until('1P crouching shown', () {
      final text = host.modelOf('Form1').control('lblInputs1')!.text('Caption');
      return text.contains('앉기');
    });
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyS);

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
        final file = File('$shots/duel-${Platform.operatingSystem}.png');
        await file.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }
    await tester.tap(find.byKey(const ValueKey('toolbar.stop')));
    await tester.pumpAndSettle();
  });
}
