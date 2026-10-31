import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A Grid (docs/DESIGN.md D116): a click chooses a cell; a second click,
/// Enter or typing edits it; Enter keeps the edit and Escape drops it;
/// ReadOnly edits nothing; rows and columns that do not fit scroll.
void main() {
  final events = <String>[];

  GbFormModel model({bool readOnly = false, int rows = 3}) => GbFormModel(
    form: {'Caption': '', 'Width': 300, 'Height': 200},
    controls: [
      GbControlState('grd', GbControlKind.grid, {
        'Left': 0,
        'Top': 0,
        'Width': 260,
        'Height': 120,
        'Anchor': 'Left Top',
        'ReadOnly': readOnly,
        'Row': -1,
        'Col': -1,
        'Headers': const ['이름', '반', '점수', '비고'],
        'Cells': [
          for (var r = 0; r < rows; r++) ...['학생$r', '1반', '${r * 10}', ''],
        ],
      }),
    ],
    onEvent: (control, event) => events.add('$control.$event'),
  );

  setUp(events.clear);

  Future<GbControlState> show(WidgetTester tester, GbFormModel m) async {
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
    return m.control('grd')!;
  }

  Finder cell(int r, int c) => find.byKey(gbGridCellKey('grd', r, c));
  final editor = find.byKey(gbGridEditorKey('grd'));

  testWidgets('a click chooses; a second click edits; Enter keeps it', (
    tester,
  ) async {
    final g = await show(tester, model());
    expect(find.text('이름'), findsOneWidget);
    await tester.tap(cell(1, 2));
    await tester.pump();
    expect((g['Row'], g['Col']), (1, 2));
    expect(events, ['grd.Click']);
    await tester.tap(cell(1, 2));
    await tester.pump();
    expect(events, ['grd.Click']);
    await tester.enterText(editor, '95');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(events, ['grd.Click', 'grd.Changed']);
    expect((g['Cells'] as List)[6], '95');
    expect(editor, findsNothing);
  });

  testWidgets('typing starts the text over; Escape drops it; an unchanged '
      'cell raises nothing', (tester) async {
    final g = await show(tester, model());
    await tester.tap(cell(0, 0));
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
    await tester.pump();
    expect(tester.widget<EditableText>(editor).controller.text, 'k');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(editor, findsNothing);
    expect((g['Cells'] as List)[0], '학생0');
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(events, ['grd.Click']);
  });

  testWidgets('ReadOnly: chosen, never edited', (tester) async {
    await show(tester, model(readOnly: true));
    await tester.tap(cell(0, 1));
    await tester.pump();
    await tester.tap(cell(0, 1));
    await tester.pump();
    expect(editor, findsNothing);
    expect(events, ['grd.Click']);
  });

  testWidgets('rows and columns that do not fit scroll into view', (
    tester,
  ) async {
    final g = await show(tester, model(rows: 30));
    // Four columns of at least gbGridMinColumnWidth in 260: the last is
    // off to the right; row 29 is far below.
    expect(cell(29, 3).hitTestable(), findsNothing);
    await tester.scrollUntilVisible(
      find.byKey(gbGridCellKey('grd', 29, 0)),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await tester.drag(find.byType(Scrollable).first, const Offset(-200, 0));
    await tester.pump();
    await tester.tap(cell(29, 3));
    await tester.pump();
    expect((g['Row'], g['Col']), (29, 3));
  });
}
