import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A Timer's clock in the run window (docs/DESIGN.md D100): it ticks every
/// Interval milliseconds while Enabled, and stops when the program ends.
/// The parity programs make each tick themselves; here the clock does.
void main() {
  testWidgets('an Enabled Timer ticks every Interval; Stop stops it', (
    tester,
  ) async {
    final form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblCount, type: Label }
  - { name: tmrCount, type: Timer, properties: { Interval: 100, Enabled: true } }
''', name: 'Form1').form;
    const code = '''
Dim count As Integer

Sub tmrCount_Tick()
    count = count + 1
    lblCount.Caption = CStr(count)
    If count = 3 Then tmrCount.Stop
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
    String caption() =>
        host.modelOf('Form1').control('lblCount')!.text('Caption');
    expect(caption(), '');
    await tester.pump(const Duration(milliseconds: 110));
    await tester.pump();
    expect(caption(), '1');
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(caption(), '3', reason: 'stopped at the third tick');
    session.closeForm();
    await tester.pump();
    expect(session.result, isA<RunCompleted>());
    session.dispose();
  });
}
