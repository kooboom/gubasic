import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

void main() {
  late GbFormModel model;
  late GbControlState box;
  late List<String> log;
  var accept = true;

  Future<void> show(WidgetTester tester) async {
    log = [];
    accept = true;
    box = GbControlState('chkShow', GbControlKind.checkBox, {
      'Caption': 'Show the answer', 'Checked': false, 'Left': 16, //
      'Top': 16, 'Width': 200, 'Height': 32,
    });
    model = GbFormModel(
      form: {'Caption': '', 'Width': 240, 'Height': 64},
      controls: [box],
      onEvent: (c, e) => log.add('$c.$e ${box['Checked']}'),
      accepts: (c, e) => accept,
    );
    model.addCommitter(() => log.add('commit'));
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: GbFormView(model: model),
          ),
        ),
      ),
    );
  }

  bool shownChecked(WidgetTester tester) =>
      tester.widget<Checkbox>(find.byType(Checkbox)).value!;

  testWidgets('a click on the box or its Caption changes Checked, then '
      'raises Changed', (tester) async {
    await show(tester);
    expect(tester.getRect(find.byType(GbCheckBox)).size, const Size(200, 32));
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(log, ['commit', 'chkShow.Changed true']);
    expect(shownChecked(tester), isTrue);
    await tester.tap(find.text('Show the answer'));
    await tester.pump();
    expect(log.last, 'chkShow.Changed false');
    expect(shownChecked(tester), isFalse);
  });

  testWidgets('a click the program would ignore changes nothing', (
    tester,
  ) async {
    await show(tester);
    accept = false;
    await tester.tap(find.byType(Checkbox));
    await tester.pump();
    expect(log, ['commit']);
    expect(box['Checked'], isFalse);
    expect(shownChecked(tester), isFalse);
  });

  testWidgets('Checked and Caption set by the program show at once, '
      'without an event', (tester) async {
    await show(tester);
    box
      ..set('Checked', true)
      ..set('Caption', 'Shown');
    await tester.pump();
    expect(shownChecked(tester), isTrue);
    expect(find.text('Shown'), findsOneWidget);
    expect(log, isEmpty);
  });
}
