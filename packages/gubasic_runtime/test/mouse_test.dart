import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// MouseDown and MouseUp (docs/DESIGN.md D111): the innermost control under
/// the pointer, the place on it, the button; on a touch screen a press is
/// the left button, a long press the right one, and not a click.
void main() {
  final events = <String>[];

  GbFormModel model() => GbFormModel(
    form: {'Caption': '', 'Width': 300, 'Height': 200},
    controls: [
      GbControlState('fraA', GbControlKind.frame, {
        'Caption': 'A',
        'Left': 100,
        'Top': 50,
        'Width': 150,
        'Height': 100,
        'Anchor': 'Left Top',
      }),
      GbControlState('btnIn', GbControlKind.button, {
        'Caption': 'In',
        'Left': 20,
        'Top': 30,
        'Width': 80,
        'Height': 30,
        'Anchor': 'Left Top',
      }, container: 'fraA'),
    ],
    onEvent: (control, event) => events.add('$control.$event'),
    onMouse: (control, event, button, x, y) => events.add(
      '$control.$event ${switch (button) {
        gbMouseLeft => 'Left',
        gbMouseRight => 'Right',
        _ => 'Middle',
      }} $x,$y',
    ),
  );

  setUp(events.clear);

  Future<Offset> show(WidgetTester tester, GbFormModel m) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: GbFormView(model: m),
          ),
        ),
      ),
    );
    return tester.getTopLeft(find.byType(GbFormView));
  }

  testWidgets('a mouse: the innermost control, the place on it, the button; '
      'the form where no control is', (tester) async {
    final form = await show(tester, model());
    // btnIn is at (120, 80) on the form.
    await tester.tapAt(
      form + const Offset(125, 84),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump();
    expect(events, [
      'btnIn.MouseDown Left 5,4',
      'btnIn.MouseUp Left 5,4',
      'btnIn.Click',
    ]);
    events.clear();
    final right = await tester.startGesture(
      form + const Offset(20, 10),
      kind: PointerDeviceKind.mouse,
      buttons: kSecondaryMouseButton,
    );
    await right.moveTo(form + const Offset(30, 15));
    await right.up();
    expect(events, ['null.MouseDown Right 20,10', 'null.MouseUp Right 30,15']);
    events.clear();
    // The Frame itself, away from btnIn.
    await tester.tapAt(
      form + const Offset(240, 140),
      kind: PointerDeviceKind.mouse,
    );
    expect(events.take(2), [
      'fraA.MouseDown Left 140,90',
      'fraA.MouseUp Left 140,90',
    ]);
  });

  testWidgets('a finger: a press is the left button when lifted; a long '
      'press the right one at once, and no click', (tester) async {
    final form = await show(tester, model());
    await tester.tapAt(form + const Offset(125, 84));
    await tester.pump();
    expect(events, [
      'btnIn.MouseDown Left 5,4',
      'btnIn.MouseUp Left 5,4',
      'btnIn.Click',
    ]);
    events.clear();
    final finger = await tester.startGesture(form + const Offset(125, 84));
    await tester.pump(gbLongPress + const Duration(milliseconds: 50));
    expect(events, ['btnIn.MouseDown Right 5,4']);
    await finger.up();
    await tester.pump();
    expect(events, ['btnIn.MouseDown Right 5,4', 'btnIn.MouseUp Right 5,4']);
  });
}
