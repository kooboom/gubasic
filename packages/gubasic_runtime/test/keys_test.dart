import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The form's keys as `Keyboard.IsDown` needs them (docs/DESIGN.md D138):
/// Shift, Control and Alt are told as keys, and losing the focus lets
/// every key go; the punctuation keys are read by their place, and a key
/// the system repeats is told as a repeat (D139).
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
      onKey:
          (
            event,
            code, {
            required shift,
            required control,
            required alt,
            required inTextBox,
            required repeat,
          }) => keys.add(
            '$event $code${shift ? ' shift' : ''}${repeat ? ' repeat' : ''}',
          ),
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

  testWidgets('the punctuation keys are read by their place', (tester) async {
    await pump(tester);
    for (final (physical, logical) in [
      (PhysicalKeyboardKey.comma, LogicalKeyboardKey.comma),
      (PhysicalKeyboardKey.period, LogicalKeyboardKey.period),
      (PhysicalKeyboardKey.slash, LogicalKeyboardKey.slash),
      (PhysicalKeyboardKey.semicolon, LogicalKeyboardKey.semicolon),
      (PhysicalKeyboardKey.quote, LogicalKeyboardKey.quote),
      (PhysicalKeyboardKey.minus, LogicalKeyboardKey.minus),
      (PhysicalKeyboardKey.equal, LogicalKeyboardKey.equal),
      (PhysicalKeyboardKey.bracketLeft, LogicalKeyboardKey.bracketLeft),
      (PhysicalKeyboardKey.bracketRight, LogicalKeyboardKey.bracketRight),
      (PhysicalKeyboardKey.backslash, LogicalKeyboardKey.backslash),
      (PhysicalKeyboardKey.backquote, LogicalKeyboardKey.backquote),
    ]) {
      await tester.sendKeyDownEvent(logical, physicalKey: physical);
      await tester.sendKeyUpEvent(logical, physicalKey: physical);
    }
    expect(keys.where((k) => k.startsWith('KeyDown')), [
      for (final code in [
        188,
        190,
        191,
        186,
        222,
        189,
        187,
        219,
        221,
        220,
        192,
      ])
        'KeyDown $code',
    ]);
  });

  testWidgets('a Korean input method does not change which key it is', (
    tester,
  ) async {
    await pump(tester);
    // With the Korean input on, the key's character is a Korean letter
    // and its logical key may be another; its place (on the web,
    // event.code) is the same, and that is what is read.
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.keyQ,
      physicalKey: PhysicalKeyboardKey.keyF,
      character: 'ㄹ',
    );
    await tester.sendKeyDownEvent(
      LogicalKeyboardKey.semicolon,
      physicalKey: PhysicalKeyboardKey.period,
    );
    expect(keys, ['KeyDown 70', 'KeyDown 190']);
  });

  testWidgets('a key the system repeats is told as a repeat', (tester) async {
    await pump(tester);
    await tester.sendKeyDownEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyRepeatEvent(LogicalKeyboardKey.keyF);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.keyF);
    expect(keys, ['KeyDown 70', 'KeyDown 70 repeat', 'KeyUp 70']);
  });
}
