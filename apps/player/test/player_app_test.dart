import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_player_app/src/player_app.dart';

/// The player (D79, D81): the project's form in the run window, filling
/// the app; a run-time error in a dialog; a project that cannot start says
/// why.
void main() {
  Map<String, String> hello() => {
    for (final f in Directory(
      '../../examples/hello',
    ).listSync().whereType<File>())
      f.uri.pathSegments.last: f.readAsStringSync(),
  };

  Future<void> open(
    WidgetTester tester,
    Map<String, String> files, {
    PlayerStrings strings = PlayerStrings.en,
  }) async {
    tester.view.physicalSize = const Size(800, 600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(PlayerApp(files: files, strings: strings));
    await tester.pumpAndSettle();
  }

  testWidgets('hello runs as an app: its form, its button, its dialogs', (
    tester,
  ) async {
    await open(tester, hello());
    expect(find.text('Press the button'), findsOneWidget);
    await tester.tap(find.text('Say hello'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Kim');
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Kim! (1)'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(find.text('Hello, Kim! (1)'), findsNothing);
  });

  testWidgets('a run-time error is shown with its line, in the device\'s '
      'language', (tester) async {
    await open(tester, {
      ...hello(),
      'Form1.gbas':
          'Sub Form_Load()\n    Dim a(2) As Integer\n    a(5) = 1\nEnd Sub\n',
    }, strings: PlayerStrings.ko);
    expect(find.textContaining('Form1.gbas 파일 3번째 줄:'), findsOneWidget);
    expect(find.text('확인'), findsOneWidget);
  });

  testWidgets('a project that cannot start lists its errors', (tester) async {
    await open(tester, {
      ...hello(),
      'Form1.gbas': 'Sub Form_Load()\n    x = \nEnd Sub\n',
    });
    expect(find.text(PlayerStrings.en.cannotStart), findsOneWidget);
    expect(find.textContaining('Form1.gbas, line 2:'), findsWidgets);
  });

  testWidgets('a bundle it cannot read says why, in the device\'s language', (
    tester,
  ) async {
    await tester.pumpWidget(
      const BundleProblemApp(
        problem: BundleTooNew('0.5.0'),
        strings: PlayerStrings.ko,
      ),
    );
    expect(find.textContaining('GuBASIC 0.5.0 버전으로'), findsOneWidget);
    await tester.pumpWidget(
      const BundleProblemApp(problem: NotABundle(), strings: PlayerStrings.en),
    );
    expect(find.textContaining('project.gbz) is damaged'), findsOneWidget);
  });
}
