import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_player_app/src/app_window.dart';
import 'package:gubasic_player_app/src/player_app.dart';
import 'package:integration_test/integration_test.dart';

import 'askname.dart';

/// The askname example as an exported desktop app runs it (D88, D89),
/// in the player's own window: clicked through, the window takes each
/// form's size. Run with `flutter test integration_test -d macos` (or
/// `-d windows`); the taps come from the test inside the app, not from
/// the computer's mouse.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('askname: Next shows Form2 in the window, at its size; OK '
      'greets on Form1, at its size again', (tester) async {
    Size inside() => tester.view.physicalSize / tester.view.devicePixelRatio;

    /// Waits for the window to be [size] inside: the runner resizes it
    /// after the frame that asked.
    Future<void> waitFor(Size size) async {
      for (var i = 0; i < 100 && inside() != size; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump();
      }
      expect(inside(), size);
    }

    await fitAppWindow(Project.read(askname));
    await tester.pumpWidget(
      PlayerApp(files: askname, strings: PlayerStrings.en, asApp: true),
    );
    await tester.pumpAndSettle();
    await waitFor(const Size(320, 140));
    expect(find.text('Press Next and tell me your name.'), findsOneWidget);

    await tester.tap(find.text('Next'));
    await tester.pumpAndSettle();
    await waitFor(const Size(300, 140));
    expect(find.text('What is your name?'), findsOneWidget);

    await tester.enterText(find.byType(TextField), 'Kim');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    await waitFor(const Size(320, 140));
    expect(find.text('Hello, Kim!'), findsOneWidget);
  });
}
