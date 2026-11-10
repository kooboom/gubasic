import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// Keys held when the window stops being the one in front (docs/DESIGN.md
/// D138, D139): the KeyUp may never come, so every key counts as let go
/// and every press not yet asked is forgotten, as far as the program
/// sees, in `Keyboard.IsDown` and `Keyboard.WasPressed`.
void main() {
  testWidgets('a window that loses the focus lets every key go', (
    tester,
  ) async {
    final form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblKeys, type: Label }
  - { name: tmrGame, type: Timer, properties: { Interval: 600000, Enabled: true } }
''', name: 'Form1').form;
    const code = '''
Sub tmrGame_Tick()
    lblKeys.Caption = "F " & Keyboard.IsDown(Keys.F) & _
        ", period " & Keyboard.IsDown(Keys.OemPeriod) & _
        ", G pressed " & Keyboard.WasPressed(Keys.G)
End Sub
''';
    final program = compile(code, form: form);
    expect(program.diagnostics, isEmpty);
    final host = RunHost(form, settings: GbMemorySettings());
    final session = RunSession(
      StartupForm(form, 'Form1.gbas', program, null),
      strings: PlayerStrings.en,
      host: host,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(child: RunWindow(session: session)),
        ),
      ),
    );
    await tester.pump();
    host.modelOf('Form1').requestFocus?.call();
    await tester.pump();

    // The test ticks the Timer itself; its own clock is ten minutes.
    Future<String> tick() async {
      host.tick('Form1', 'tmrGame');
      await tester.pump();
      return host.modelOf('Form1').control('lblKeys')!.text('Caption');
    }

    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.period);
    expect(await tick(), 'F True, period True, G pressed False');

    // The keys are held, G is pressed and not yet asked, and the window
    // stops being the one in front (another app is chosen): no KeyUp.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyG);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(await tick(), 'F False, period False, G pressed False');

    // Back in front, the keys still held are told again by the system's
    // repeat: held again, but not a new press.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    host.modelOf('Form1').requestFocus?.call();
    await tester.pump();
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyG);
    expect(await tick(), 'F True, period False, G pressed False');

    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.period);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyG);
    session.closeForm();
    await tester.pump();
    session.dispose();
  });
}
