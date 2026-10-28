import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A form's menus (docs/DESIGN.md D106): on macOS on the system's menu bar,
/// between the app's own menu and the Window menu, while the program runs;
/// elsewhere in the run window, above the form.
void main() {
  const files = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\n'
        'forms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 3\nproperties:\n  Width: 240\n'
        '  Height: 120\nmenus:\n'
        '  - name: mnuFile\n    properties:\n      Caption: File\n'
        '    menus:\n'
        '      - name: mnuFileNew\n        properties:\n'
        '          Caption: New\n          Shortcut: Ctrl+N\n',
    'Form1.gbas':
        'Sub mnuFileNew_Click()\n    Debug.Print("New")\n'
        '    mnuFileNew.Checked = True\nEnd Sub\n',
  };

  Future<RunSession> run(WidgetTester tester) async {
    final session = RunSession(
      Project.read(files).startup!,
      strings: PlayerStrings.en,
      settings: GbMemorySettings(),
    );
    addTearDown(session.stop);
    await tester.pumpWidget(
      MaterialApp(
        home: SystemMenus(
          appName: 'Demo',
          strings: PlayerStrings.en,
          session: session,
          child: Scaffold(body: RunWindow(session: session)),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return session;
  }

  testWidgets('on macOS: on the system\'s menu bar, not in the window', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      final session = await run(tester);
      expect(find.byKey(gbMenuBarKey), findsNothing);
      List<PlatformMenuItem> menus() =>
          tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus;
      expect(menus().map((m) => m.label), ['Demo', 'File', 'Window']);
      final item = (menus()[1] as PlatformMenu).menus.single;
      expect(item.label, 'New');
      expect((item.shortcut! as SingleActivator).meta, isTrue);
      item.onSelected!();
      await tester.pumpAndSettle();
      expect(session.output, ['New']);
      // Checked now: the system's menu shows it.
      expect((menus()[1] as PlatformMenu).menus.single.label, '✓ New');

      session.closeForm();
      await tester.pumpAndSettle();
      expect(menus().map((m) => m.label), ['Demo', 'Window']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('elsewhere: in the window, above the form', (tester) async {
    final session = await run(tester);
    expect(find.byType(PlatformMenuBar), findsNothing);
    expect(find.byKey(gbMenuBarKey), findsOneWidget);
    final bar = tester.getRect(find.byKey(gbMenuBarKey));
    final form = tester.getRect(find.byKey(runFormKey('Form1')));
    expect(bar.bottom, lessThanOrEqualTo(form.top));
    await tester.tap(find.byKey(gbMenuKey('mnuFile')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(gbMenuKey('mnuFileNew')));
    await tester.pumpAndSettle();
    expect(session.output, ['New']);
  });
}
