import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

void main() {
  const s = IdeStrings.en;
  final hello = exampleProjects['hello']!;
  const formFile = 'Form1.form.yaml';

  Future<void> open(WidgetTester tester, {IdeStrings strings = s}) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': hello}, strings: strings),
    );
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
  }

  String formText(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;

  Finder field(String property) => find.byKey(propertyFieldKey(property));
  String fieldText(WidgetTester tester, String property) =>
      tester.widget<TextField>(field(property)).controller!.text;
  Finder onForm(String text) => find.descendant(
    of: find.byKey(designerFormKey),
    matching: find.text(text),
  );

  Future<void> click(WidgetTester tester, Offset p) async {
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    final mouse = await tester.startGesture(
      origin + p,
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.up();
    await tester.pumpAndSettle();
  }

  Future<void> choose(WidgetTester tester, String target) async {
    await tester.tap(find.byKey(propertiesTargetKey));
    await tester.pumpAndSettle();
    await tester.tap(find.text(target).last);
    await tester.pumpAndSettle();
  }

  Future<void> ctrl(WidgetTester tester, LogicalKeyboardKey key) async {
    await tester.sendKeyDownEvent(LogicalKeyboardKey.control);
    await tester.sendKeyEvent(key);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.control);
    await tester.pumpAndSettle();
  }

  testWidgets("with nothing selected, the form's properties show", (
    tester,
  ) async {
    await open(tester);
    expect(find.text(s.properties), findsOneWidget);
    expect(fieldText(tester, 'Caption'), 'Hello');
    expect(fieldText(tester, 'Width'), '320');
    expect(fieldText(tester, 'Height'), '120');
    expect(field('Left'), findsNothing);

    await click(tester, const Offset(30, 70));
    expect(fieldText(tester, 'Caption'), 'Say hello');
    expect(fieldText(tester, 'Left'), '16');
    await click(tester, const Offset(250, 100));
    expect(fieldText(tester, 'Width'), '320', reason: 'the empty form');
  });

  testWidgets('the list chooses a control the canvas hides', (tester) async {
    await open(tester);
    await choose(tester, 'lblMessage');
    expect(
      find.text('lblMessage (Label) · Left 16, Top 16 · 288×24'),
      findsOneWidget,
    );
    expect(fieldText(tester, 'Width'), '288');
    // The canvas chooses too, and the list follows.
    await click(tester, const Offset(30, 70));
    final list = tester.widget<DropdownButton<String>>(
      find.byKey(propertiesTargetKey),
    );
    expect(list.value, 'btnHello');
  });

  testWidgets('typing applies at once, as one step of undo', (tester) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    await tester.enterText(field('Caption'), 'H');
    await tester.pump();
    expect(onForm('H'), findsOneWidget, reason: 'the canvas at once');
    await tester.enterText(field('Caption'), 'Hi');
    await tester.enterText(field('Caption'), 'Hi there');
    await tester.pump();
    expect(onForm('Hi there'), findsOneWidget);
    expect(formText(tester), contains('      Caption: Hi there\n'));
    expect(find.text('Hello — Edited'), findsOneWidget);

    await click(tester, const Offset(250, 100));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), hello[formFile], reason: 'one step');
    await ctrl(tester, LogicalKeyboardKey.keyY);
    expect(formText(tester), contains('Caption: Hi there'));
  });

  testWidgets('the canvas shows the syllable being typed; the file waits', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    await tester.tap(field('Caption'));
    await tester.pump();
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '한글',
        selection: TextSelection.collapsed(offset: 2),
        composing: TextRange(start: 1, end: 2),
      ),
    );
    await tester.pump();
    expect(onForm('한글'), findsOneWidget, reason: 'as the field shows it');
    expect(formText(tester), contains('      Caption: 한\n'));
    // Esc drops 글: the form follows the field again.
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pump();
    expect(onForm('한'), findsOneWidget);
    await click(tester, const Offset(250, 100));
    expect(formText(tester), contains('      Caption: 한\n'));
    expect(find.text('한글'), findsNothing);
  });

  testWidgets('a value that is not valid says why and is not applied', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    for (final bad in ['abc', '-5', '1.5']) {
      await tester.enterText(field('Width'), bad);
      await tester.pump();
      expect(
        find.text('Width takes a whole number from 0 to 2147483647.'),
        findsOneWidget,
        reason: bad,
      );
      expect(formText(tester), hello[formFile], reason: bad);
    }
    // Leaving the field shows the value again.
    await click(tester, const Offset(30, 70));
    expect(fieldText(tester, 'Width'), '120');
    expect(find.textContaining('whole number'), findsNothing);

    // Left follows component.yaml: it may be negative.
    await tester.enterText(field('Left'), '-16');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(formText(tester), contains('      Left: -16\n'));
  });

  testWidgets('a number applies on Enter or on leaving the field', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    // Erasing 120 to type 104 passes through 12, 1, nothing, 1 and 10.
    for (final typed in ['12', '1', '', '1', '10', '104']) {
      await tester.enterText(field('Width'), typed);
      await tester.pump();
      expect(formText(tester), hello[formFile], reason: typed);
    }
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(formText(tester), contains('      Width: 104\n'), reason: 'Enter');

    await tester.enterText(field('Height'), '40');
    await tester.pump();
    expect(formText(tester), isNot(contains('Height: 40')));
    await click(tester, const Offset(250, 100));
    await click(tester, const Offset(30, 70));
    expect(formText(tester), contains('      Height: 40\n'), reason: 'left');

    // Esc keeps the property's value.
    await tester.tap(field('Top'));
    await tester.enterText(field('Top'), '80');
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(formText(tester), contains('      Top: 56\n'));
    expect(fieldText(tester, 'Top'), '56');
  });

  testWidgets('keys in a field never change the form', (tester) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    await tester.tap(field('Caption'));
    await tester.enterText(field('Caption'), '');
    await tester.pump();
    for (final key in [
      LogicalKeyboardKey.backspace,
      LogicalKeyboardKey.backspace,
      LogicalKeyboardKey.delete,
    ]) {
      await tester.sendKeyEvent(key);
      await tester.pump();
    }
    expect(formText(tester), contains('btnHello'), reason: 'not deleted');
    await ctrl(tester, LogicalKeyboardKey.arrowRight);
    expect(formText(tester), isNot(contains('      Left: 24')));
    expect(formText(tester), contains('      Left: 16\n'));
    await ctrl(tester, LogicalKeyboardKey.keyZ);
    expect(formText(tester), contains('btnHello'), reason: 'the text only');

    // Back on the form, the keys work again.
    await click(tester, const Offset(30, 70));
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('btnHello')));
  });

  testWidgets('Esc puts back the value and returns to the form', (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    await tester.tap(field('Caption'));
    await tester.enterText(field('Caption'), 'Changed');
    await tester.pump();
    expect(formText(tester), contains('Caption: Changed'));
    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(formText(tester), hello[formFile]);
    expect(fieldText(tester, 'Caption'), 'Say hello');
    // The form has the focus: Delete deletes.
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('btnHello')));
  });

  testWidgets("the toolbar's Undo, while a field has the focus", (
    tester,
  ) async {
    await open(tester);
    await click(tester, const Offset(30, 70));
    await tester.enterText(field('Caption'), 'Changed');
    await tester.pump();
    await tester.tap(find.byTooltip('${s.undo} (Ctrl+Z)'));
    await tester.pumpAndSettle();
    expect(formText(tester), hello[formFile]);
    expect(fieldText(tester, 'Caption'), 'Say hello');
  });

  testWidgets('moving with the mouse shows in the fields', (tester) async {
    await open(tester);
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.dragFrom(
      origin + const Offset(30, 70),
      const Offset(48, 0),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pumpAndSettle();
    expect(fieldText(tester, 'Left'), '64');
  });

  testWidgets('read-only while the program runs', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.text(formFile));
    await tester.pumpAndSettle();
    expect(tester.widget<TextField>(field('Caption')).readOnly, isTrue);
    await tester.enterText(field('Caption'), 'No');
    await tester.pump();
    expect(formText(tester), hello[formFile]);
  });

  group('renaming', () {
    final code = hello['Form1.gbas']!;

    Future<void> addLabel(WidgetTester tester) async {
      final label = find.byKey(const ValueKey('toolbox.Label'));
      await tester.tap(label);
      await tester.pump(kDoubleTapMinTime);
      await tester.tap(label);
      await tester.pumpAndSettle();
    }

    testWidgets('a name the code does not use, on Enter', (tester) async {
      await open(tester);
      await addLabel(tester);
      expect(fieldText(tester, '(Name)'), 'Label1');
      await tester.enterText(field('(Name)'), 'lblTitle');
      await tester.pump();
      expect(formText(tester), contains('name: Label1'), reason: 'not yet');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(formText(tester), contains('  - name: lblTitle\n'));
      expect(formText(tester), contains('      Caption: Label1\n'));
      expect(
        tester
            .widget<DropdownButton<String>>(find.byKey(propertiesTargetKey))
            .value,
        'lblTitle',
      );
      // The form has the focus: one undo step back.
      await ctrl(tester, LogicalKeyboardKey.keyZ);
      expect(formText(tester), contains('  - name: Label1\n'));
    });

    testWidgets('a name the code uses cannot change, and says where', (
      tester,
    ) async {
      await open(tester);
      await click(tester, const Offset(30, 70));
      expect(find.byType(NameField), findsOneWidget);
      expect(
        tester.widgetList(field('(Name)')).single,
        isA<Text>(),
        reason: 'read-only',
      );
      final lines = linesUsingName(code, 'btnHello').join(', ');
      expect(
        find.text(
          'btnHello is used in Form1.gbas on lines $lines, so it cannot be '
          'renamed here. Change those lines first. Renaming the code '
          'together with the control comes with the code editor.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('names that cannot be used say why', (tester) async {
      await open(tester);
      await addLabel(tester);
      final inCode = linesUsingName(code, 'clickCount').join(', ');
      for (final (name, why) in [
        ('1abc', s.badName.replaceAll('{0}', '1abc')),
        ('If', s.badName.replaceAll('{0}', 'If')),
        ('Form', s.badName.replaceAll('{0}', 'Form')),
        ('', s.badName.replaceAll('{0}', '')),
        ('LBLMESSAGE', s.nameTaken.replaceAll('{0}', 'LBLMESSAGE')),
        (
          'clickCount',
          s.nameInCode
              .replaceAll('{0}', 'clickCount')
              .replaceAll('{1}', 'Form1.gbas')
              .replaceAll('{2}', inCode),
        ),
      ]) {
        await tester.enterText(field('(Name)'), name);
        await tester.pump();
        expect(find.text(why), findsOneWidget, reason: name);
      }
      final before = formText(tester);
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(formText(tester), before, reason: 'not renamed');
      expect(fieldText(tester, '(Name)'), 'Label1');
      // Only the case changes: the same control, allowed.
      await tester.enterText(field('(Name)'), 'label1');
      await tester.pump();
      expect(find.textContaining('cannot be a name'), findsNothing);
    });

    testWidgets("the form's name is its file's", (tester) async {
      await open(tester);
      expect(tester.widget(field('(Name)')), isA<Text>());
    });
  });

  testWidgets('Korean words', (tester) async {
    await open(tester, strings: IdeStrings.ko);
    expect(find.text('속성'), findsOneWidget);
    await click(tester, const Offset(30, 70));
    await tester.enterText(field('Width'), 'x');
    await tester.pump();
    expect(
      find.text('Width 속성에는 정수만 쓸 수 있습니다. 범위: 0 ~ 2147483647'),
      findsOneWidget,
    );
  });
}
