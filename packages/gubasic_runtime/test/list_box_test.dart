import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

void main() {
  late GbControlState box;
  late List<String> log;
  var accept = true;

  Future<void> show(
    WidgetTester tester, {
    List<String> items = const ['Seoul', 'Busan', 'Daegu'],
    bool designing = false,
  }) async {
    log = [];
    accept = true;
    box = GbControlState('lstCity', GbControlKind.listBox, {
      'Left': 0, 'Top': 0, 'Width': 160, 'Height': 120, //
      'ListIndex': -1, 'Items': items,
    });
    final model = GbFormModel(
      form: {'Caption': '', 'Width': 200, 'Height': 140},
      controls: [box],
      onEvent: (c, e) => log.add('$c.$e ${box['ListIndex']}'),
      accepts: (c, e) => accept,
      designing: designing,
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

  testWidgets('a click chooses an item and raises Changed; the chosen one '
      'again does nothing', (tester) async {
    await show(tester);
    expect(tester.getSize(find.byType(GbListBox)), const Size(160, 120));
    await tester.tap(find.text('Busan'));
    await tester.pump();
    expect(log, ['commit', 'lstCity.Changed 1']);
    await tester.tap(find.byKey(gbListItemKey('lstCity', 1)));
    await tester.pump();
    expect(log, ['commit', 'lstCity.Changed 1', 'commit']);
  });

  testWidgets('a click the program would ignore changes nothing', (
    tester,
  ) async {
    await show(tester);
    accept = false;
    await tester.tap(find.text('Daegu'));
    await tester.pump();
    expect(log, ['commit']);
    expect(box['ListIndex'], -1);
  });

  testWidgets('items and the choice set by the program show at once, '
      'without an event', (tester) async {
    await show(tester, items: const []);
    box
      ..set('Items', const ['Jeju', 'Ulsan'])
      ..set('ListIndex', 1);
    await tester.pump();
    expect(find.text('Jeju'), findsOneWidget);
    final chosen = tester.widget<Container>(
      find.ancestor(of: find.text('Ulsan'), matching: find.byType(Container)),
    );
    expect(chosen.color, isNotNull);
    expect(log, isEmpty);
  });

  testWidgets('many items scroll', (tester) async {
    await show(tester, items: [for (var i = 0; i < 20; i++) 'item $i']);
    expect(find.text('item 19'), findsNothing);
    await tester.drag(find.byType(GbListBox), const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(find.text('item 19'), findsOneWidget);
  });

  testWidgets('in the designer, an empty ListBox shows its name', (
    tester,
  ) async {
    await show(tester, items: const [], designing: true);
    expect(find.text('lstCity'), findsOneWidget);
    await show(tester, items: const []);
    expect(find.text('lstCity'), findsNothing);
  });
}
