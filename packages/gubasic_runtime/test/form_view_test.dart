import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

void main() {
  late GbFormModel model;
  late List<String> events;

  Future<void> show(WidgetTester tester) async {
    events = [];
    model = GbFormModel(
      form: {'Caption': 'Hello', 'Width': 320, 'Height': 120},
      controls: [
        GbControlState('lblMessage', GbControlKind.label, {
          'Caption': 'Press the button', 'Left': 16, 'Top': 16, //
          'Width': 288, 'Height': 24,
        }),
        GbControlState('btnHello', GbControlKind.button, {
          'Caption': 'Say hello', 'Left': 16, 'Top': 56, //
          'Width': 120, 'Height': 32,
        }),
      ],
      onEvent: (c, e) => events.add('$c.$e'),
    );
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

  testWidgets('controls sit at Left/Top with Width x Height', (tester) async {
    await show(tester);
    final form = tester.getRect(find.byType(GbFormView));
    expect(form.size, const Size(320, 120));
    expect(
      tester.getRect(find.byType(GbButton)),
      const Rect.fromLTWH(16, 56, 120, 32).shift(form.topLeft),
    );
    expect(
      tester.getRect(find.byType(GbLabel)),
      const Rect.fromLTWH(16, 16, 288, 24).shift(form.topLeft),
    );
  });

  testWidgets('properties set by the program show at once', (tester) async {
    await show(tester);
    model.control('LBLMESSAGE')!.set('Caption', 'Hello, Kim!');
    model.control('btnHello')!
      ..set('Left', 100)
      ..set('Caption', 'Again');
    model.form.set('Width', 400);
    await tester.pump();
    expect(find.text('Hello, Kim!'), findsOneWidget);
    expect(find.text('Again'), findsOneWidget);
    expect(
      tester.getTopLeft(find.byType(GbButton)).dx -
          tester.getTopLeft(find.byType(GbFormView)).dx,
      100,
    );
    expect(tester.getSize(find.byType(GbFormView)).width, 400);
    expect(events, isEmpty);
  });

  testWidgets('clicks raise Click for buttons and labels', (tester) async {
    await show(tester);
    await tester.tap(find.text('Say hello'));
    await tester.tap(find.text('Press the button'));
    await tester.pump();
    expect(events, ['btnHello.Click', 'lblMessage.Click']);
  });

  test('controls are found by name in any case; null is the form', () {
    final m = GbFormModel(
      form: {'Width': 1, 'Height': 1},
      controls: [GbControlState('txtA', GbControlKind.textBox, {})],
      onEvent: (_, _) {},
    );
    expect(m.control('TXTA')!.name, 'txtA');
    expect(m.control(null), same(m.form));
    expect(m.control('nothing'), isNull);
    expect(() => m.form['Caption'], throwsArgumentError);
  });

  group('dialogs are modal', () {
    late GbDialogs dialogs;
    late BuildContext context;

    Future<void> app(WidgetTester tester, GbStrings strings) async {
      dialogs = GbDialogs(strings: strings);
      await show(tester);
      context = tester.element(find.byType(GbFormView));
    }

    testWidgets('MsgBox: the form cannot be used until OK', (tester) async {
      await app(tester, GbStrings.en);
      var closed = false;
      dialogs.msgBox(context, 'Saved', 'Score Book').then((_) => closed = true);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(find.text('Score Book'), findsOneWidget);
      expect(dialogs.hasOpenDialog, isTrue);
      // A tap outside the dialog neither closes it nor reaches the form.
      await tester.tapAt(const Offset(5, 590));
      await tester.tap(find.text('Say hello'), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(find.text('Saved'), findsOneWidget);
      expect(events, isEmpty);
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
      expect(find.text('Saved'), findsNothing);
      expect(dialogs.hasOpenDialog, isFalse);
    });

    testWidgets('InputBox: the answer, or "" when cancelled', (tester) async {
      await app(tester, GbStrings.ko);
      final answer = dialogs.inputBox(context, '이름은?', '', '');
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '김구');
      await tester.tap(find.text('확인'));
      await tester.pumpAndSettle();
      expect(await answer, '김구');

      final cancelled = dialogs.inputBox(context, '이름은?', '', 'default');
      await tester.pumpAndSettle();
      expect(find.text('default'), findsOneWidget);
      await tester.tap(find.text('취소'));
      await tester.pumpAndSettle();
      expect(await cancelled, '');
    });

    testWidgets('Escape cancels', (tester) async {
      await app(tester, GbStrings.en);
      final answer = dialogs.inputBox(context, 'Name?', '', 'x');
      await tester.pumpAndSettle();
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(await answer, '');
      expect(find.text('Name?'), findsNothing);
    });

    testWidgets('closeAll closes every dialog as cancelled', (tester) async {
      await app(tester, GbStrings.en);
      var msgClosed = false;
      dialogs.msgBox(context, 'first', '').then((_) => msgClosed = true);
      await tester.pumpAndSettle();
      final answer = dialogs.inputBox(context, 'second', '', 'typed');
      await tester.pumpAndSettle();
      dialogs.closeAll();
      await tester.pumpAndSettle();
      expect(await answer, '');
      expect(msgClosed, isTrue);
      expect(find.text('first'), findsNothing);
      expect(find.text('second'), findsNothing);
      expect(dialogs.hasOpenDialog, isFalse);
    });
  });
}
