import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A running form takes the keys without a click (docs/DESIGN.md D139):
/// when it is first shown, and when it is shown again after another view,
/// as the IDE's code beside its run window; on the web, while the page
/// does not have the keys, it says so over itself.
void main() {
  late RunHost host;
  late RunSession session;

  Future<void> start(WidgetTester tester, ValueNotifier<int> view) async {
    final form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblKeys, type: Label }
  - { name: tmrGame, type: Timer, properties: { Interval: 600000, Enabled: true } }
''', name: 'Form1').form;
    const code = '''
Sub tmrGame_Tick()
    lblKeys.Caption = "F " & Keyboard.IsDown(Keys.F)
End Sub
''';
    final program = compile(code, form: form);
    expect(program.diagnostics, isEmpty);
    host = RunHost(form, settings: GbMemorySettings());
    session = RunSession(
      StartupForm(form, 'Form1.gbas', program, null),
      strings: PlayerStrings.en,
      host: host,
    );
    // As the IDE: the code, with a text field that takes the focus, and
    // the run window, one of them seen.
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ValueListenableBuilder(
            valueListenable: view,
            builder: (context, index, _) => IndexedStack(
              index: index,
              children: [
                const TextField(autofocus: true),
                Center(child: RunWindow(session: session)),
              ],
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<String> held(WidgetTester tester) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    host.tick('Form1', 'tmrGame');
    await tester.pump();
    final caption = host.modelOf('Form1').control('lblKeys')!.text('Caption');
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.pump();
    return caption;
  }

  Future<void> end(WidgetTester tester) async {
    session.closeForm();
    await tester.pump();
    session.dispose();
  }

  testWidgets('the form takes the keys when shown, and shown again', (
    tester,
  ) async {
    final view = ValueNotifier(1);
    await start(tester, view);
    // No click and no requestFocus from the test.
    expect(await held(tester), 'F True');

    // The code is chosen: its field takes the keys; then the run window
    // again, and the form has them back.
    view.value = 0;
    await tester.pumpAndSettle();
    await tester.tap(find.byType(TextField));
    await tester.pump();
    expect(await held(tester), 'F False');
    view.value = 1;
    await tester.pumpAndSettle();
    expect(await held(tester), 'F True');
    await end(tester);
  });

  testWidgets('without the page focus it says "Click to start"', (
    tester,
  ) async {
    addTearDown(() => gbPageFocus.value = true);
    final view = ValueNotifier(1);
    await start(tester, view);
    expect(find.text('Click to start'), findsNothing);
    gbPageFocus.value = false;
    await tester.pump();
    expect(find.text('Click to start'), findsOneWidget);
    // The click gives the page the keys.
    await tester.tap(find.text('Click to start'));
    gbPageFocus.value = true;
    await tester.pumpAndSettle();
    expect(find.text('Click to start'), findsNothing);
    expect(await held(tester), 'F True');
    await end(tester);
  });
}
