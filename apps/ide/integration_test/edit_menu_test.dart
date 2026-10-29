import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:integration_test/integration_test.dart';

/// The IDE's Edit menu on macOS's menu bar (D110), set through the engine
/// in the IDE's own window: there while no program runs, gone while one
/// does, back when it ends. Run with
/// `flutter test integration_test/edit_menu_test.dart -d macos`; F5 and
/// Shift+F5 are the test's keys, not the computer's.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Edit while no program runs', (tester) async {
    await tester.pumpWidget(
      IdeApp(
        projects: {'hello': exampleProjects['hello']!},
        strings: IdeStrings.en,
      ),
    );
    await tester.pumpAndSettle();
    List<String> labels() => [
      for (final m
          in tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus)
        m.label,
    ];
    expect(labels(), ['GuBASIC', 'Edit', 'Window']);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(labels(), ['GuBASIC', 'Window']);

    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(labels(), ['GuBASIC', 'Edit', 'Window']);
  }, skip: !Platform.isMacOS);
}
