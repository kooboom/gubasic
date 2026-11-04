import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The form's keys as `Keyboard.IsDown` needs them (docs/DESIGN.md D138):
/// Shift, Control and Alt are told as keys, and losing the focus lets
/// every key go.
void main() {
  late List<String> keys;
  late int released;
  late GbFormModel model;

  Future<void> pump(WidgetTester tester) async {
    keys = [];
    released = 0;
    model = GbFormModel(
      form: {'Caption': '', 'Width': 200, 'Height': 80},
      controls: [
        GbControlState('btnA', GbControlKind.button, {
          'Caption': 'A', 'Left': 8, 'Top': 8, 'Width': 80, 'Height': 24, //
        }),
      ],
      onEvent: (_, _) {},
      onKey: (
        event,
        code, {
        required shift,
        required control,
        required alt,
        required inTextBox,
      }) => keys.add('$event $code${shift ? ' shift' : ''}'),
      onKeysReleased: () => released++,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Column(
            children: [
              GbFormView(model: model),
              const TextField(key: ValueKey('outside')),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('Shift, Control and Alt are told as 16, 17 and 18', (
    tester,
  ) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.arrowLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.controlRight);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.controlRight);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.altLeft);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.altLeft);
    expect(keys, [
      'KeyDown 16 shift',
      'KeyDown 37 shift',
      'KeyUp 37 shift',
      'KeyUp 16',
      'KeyDown 17',
      'KeyUp 17',
      'KeyDown 18',
      'KeyUp 18',
    ]);
    expect(released, 0);
  });

  testWidgets('losing the focus lets every key go', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.arrowRight);
    expect(keys, ['KeyDown 39']);
    // A control of the form keeps the focus inside it.
    await tester.tap(find.text('A'));
    await tester.pump();
    expect(released, 0);
    // Something outside the form (a dialog) takes it.
    await tester.tap(find.byKey(const ValueKey('outside')));
    await tester.pump();
    expect(released, 1);
  });
}
