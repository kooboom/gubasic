import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A game's start button, clicked with the mouse, has the focus; Space and
/// Enter would press it again (docs/LANGUAGE.md §11.1). Hidden or disabled
/// when the match begins, it takes neither, and the form still hears them.
void main() {
  for (final hide in ['Visible', 'Enabled', null]) {
    testWidgets(
      hide == null
          ? 'a start button left as it is is pressed again by Space'
          : 'a start button with $hide = False takes no Space or Enter',
      (tester) async {
        final form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnStart, type: Button, properties: { Caption: Start, Left: 10, Top: 10, Width: 100, Height: 30 } }
  - { name: lblState, type: Label, properties: { Left: 10, Top: 60, Width: 300 } }
  - { name: tmrGame, type: Timer, properties: { Interval: 600000, Enabled: true } }
''', name: 'Form1').form;
        final code =
            '''
Dim starts As Integer
Dim presses As Integer

Sub btnStart_Click()
    starts = starts + 1
${hide == null ? '' : '    btnStart.$hide = False\n'}End Sub

Sub Form_KeyDown(e As KeyEventArgs)
    presses = presses + 1
End Sub

Sub tmrGame_Tick()
    lblState.Caption = "starts " & starts & ", keys " & presses & _
        ", space " & Keyboard.IsDown(Keys.Space) & _
        ", enter pressed " & Keyboard.WasPressed(Keys.Enter)
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

        Future<String> tick() async {
          host.tick('Form1', 'tmrGame');
          await tester.pump();
          return host.modelOf('Form1').control('lblState')!.text('Caption');
        }

        // Clicked with the mouse, as a player does: the button takes the
        // focus, then the program hides or disables it. Nothing gives the
        // form the focus again afterwards.
        await tester.tap(find.text('Start'));
        await tester.pumpAndSettle();
        expect(
          await tick(),
          'starts 1, keys 0, space False, enter pressed False',
        );

        await tester.sendKeyDownEvent(LogicalKeyboardKey.space);
        await tester.pump();
        // Left as it is, the focused button is pressed again, as in Visual
        // Basic 6 and the operating systems; the form hears the key too.
        final again = hide == null ? 2 : 1;
        expect(
          await tick(),
          'starts $again, keys 1, space True, enter pressed False',
        );
        if (hide == null) {
          session.closeForm();
          await tester.pump();
          session.dispose();
          return;
        }
        await tester.sendKeyUpEvent(LogicalKeyboardKey.space);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expect(
          await tick(),
          'starts 1, keys 2, space False, enter pressed True',
        );

        session.closeForm();
        await tester.pump();
        session.dispose();
      },
    );
  }
}
