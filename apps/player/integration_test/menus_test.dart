import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_player_app/src/app_window.dart';
import 'package:gubasic_player_app/src/player_app.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';
import 'package:integration_test/integration_test.dart';

/// A form's menus in an exported desktop app (docs/DESIGN.md D106): on
/// macOS on the system's menu bar, which the app sets through the engine,
/// and the window is the form's size; on Windows in the window, above the
/// form, which the window makes room for. Run with
/// `flutter test integration_test/menus_test.dart -d macos` (or
/// `-d windows`); nothing comes from the computer's mouse or keyboard.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  const files = {
    'Menus.gbproj':
        'formatVersion: 1\nname: Menus\nstartup: Form1\nforms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 3\nproperties:\n  Caption: Menus\n  Width: 320\n'
        '  Height: 140\ncontrols:\n'
        '  - name: lblSaid\n    type: Label\n    properties:\n'
        '      Caption: nothing yet\n      Left: 16\n      Top: 16\n'
        '      Width: 200\nmenus:\n'
        '  - name: mnuFile\n    properties:\n      Caption: File\n'
        '    menus:\n'
        '      - name: mnuFileHello\n        properties:\n'
        '          Caption: Hello\n          Shortcut: Ctrl+H\n',
    'Form1.gbas':
        'Sub mnuFileHello_Click()\n    lblSaid.Caption = "Hello"\n'
        '    mnuFileHello.Checked = True\nEnd Sub\n',
  };

  testWidgets('the menus where the platform puts them; choosing an item '
      'runs its Click', (tester) async {
    Size inside() => tester.view.physicalSize / tester.view.devicePixelRatio;
    final bar = gbUsesSystemMenus ? 0.0 : gbMenuBarHeight;

    await fitAppWindow(Project.read(files));
    await tester.pumpWidget(
      PlayerApp(files: files, strings: PlayerStrings.en, asApp: true),
    );
    await tester.pumpAndSettle();
    for (var i = 0; i < 100 && inside() != Size(320, 140 + bar); i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(inside(), Size(320, 140 + bar));

    if (defaultTargetPlatform == TargetPlatform.macOS) {
      expect(find.byKey(gbMenuBarKey), findsNothing);
      List<PlatformMenuItem> menus() =>
          tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus;
      expect(menus().map((m) => m.label), ['Menus', 'File', 'Window']);
      // What the system's menu calls when the item is chosen.
      (menus()[1] as PlatformMenu).menus.single.onSelected!();
      await tester.pumpAndSettle();
      expect((menus()[1] as PlatformMenu).menus.single.label, '✓ Hello');
    } else {
      expect(find.byType(PlatformMenuBar), findsNothing);
      await tester.tap(find.byKey(gbMenuKey('mnuFile')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(gbMenuKey('mnuFileHello')));
      await tester.pumpAndSettle();
    }
    expect(find.text('Hello'), findsOneWidget);
  });
}
