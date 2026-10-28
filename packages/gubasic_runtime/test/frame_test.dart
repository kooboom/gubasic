import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// Frames (docs/DESIGN.md D105): the controls in one are drawn in it, from
/// its corner, anchored to its edges; its OptionButtons are a group of
/// their own.
void main() {
  final events = <String>[];

  GbControlState control(
    String name,
    GbControlKind kind,
    Map<String, Object> properties, {
    String? container,
  }) => GbControlState(name, kind, {
    'Caption': name,
    'Left': 0,
    'Top': 0,
    'Width': 80,
    'Height': 24,
    'Anchor': 'Left Top',
    ...properties,
  }, container: container);

  GbFormModel model() => GbFormModel(
    form: {'Caption': '', 'Width': 300, 'Height': 200},
    controls: [
      control('fraA', GbControlKind.frame, {
        'Left': 10,
        'Top': 20,
        'Width': 150,
        'Height': 100,
        'Anchor': 'Left Top Right',
      }),
      control('optA1', GbControlKind.optionButton, {
        'Left': 8,
        'Top': 24,
        'Checked': true,
      }, container: 'fraA'),
      control('optA2', GbControlKind.optionButton, {
        'Left': 8,
        'Top': 56,
        'Checked': false,
      }, container: 'fraA'),
      control('btnIn', GbControlKind.button, {
        'Left': 60,
        'Top': 70,
        'Anchor': 'Right Top',
      }, container: 'FRAA'),
      control('optForm', GbControlKind.optionButton, {
        'Left': 180,
        'Top': 20,
        'Checked': true,
      }),
    ],
    onEvent: (control, event) => events.add('$control.$event'),
  );

  setUp(events.clear);

  test('the controls in a Frame are drawn in it, not on the form', () {
    final m = model();
    expect(m.drawingOrder.map((c) => c.name), ['fraA', 'optForm']);
    expect(m.drawnIn('fraa').map((c) => c.name), ['optA1', 'optA2', 'btnIn']);
  });

  test('anchored to the Frame\'s edges, which follow the form', () {
    final m = model();
    m.resize(340, 200);
    expect(m.control('fraA')!.integer('Width'), 190);
    expect(m.control('btnIn')!.integer('Left'), 100);
    m.setProperty('fraA', 'Width', 170);
    expect(m.control('btnIn')!.integer('Left'), 80);
    // Moving the Frame does not change where the control is in it.
    m.setProperty('fraA', 'Left', 50);
    expect(m.control('btnIn')!.integer('Left'), 80);
  });

  testWidgets('drawn from the Frame\'s corner; a click checks an option of '
      'its own group only', (tester) async {
    final m = model();
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
    expect(find.text('fraA'), findsOneWidget, reason: 'its caption');
    final form = tester.getTopLeft(find.byType(GbFormView));
    expect(
      tester.getTopLeft(find.widgetWithText(OutlinedButton, 'btnIn')) - form,
      const Offset(70, 90),
    );
    await tester.tap(find.text('optA2'));
    await tester.pump();
    expect(events, ['optA2.Changed']);
    expect(m.control('optA1')!['Checked'], false);
    expect(m.control('optForm')!['Checked'], true);
    await tester.tapAt(form + const Offset(150, 110));
    expect(events.last, 'fraA.Click');
  });
}
