import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/code/completion_list.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// The completion list of the code editor (D50), in the quiz example,
/// whose form has lblNumber, lblQuestion (Label), lstChoices (ListBox),
/// chkShowAnswer (CheckBox) and btnNext (Button).
void main() {
  final quiz = exampleProjects['quiz']!;
  const codeFile = 'Form1.gbas';

  Future<void> open(
    WidgetTester t,
    String code, {
    IdeStrings strings = IdeStrings.en,
  }) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      IdeApp(
        projects: {
          // Opened first, as the IDE opens hello.
          'hello': {...quiz, codeFile: code},
        },
        strings: strings,
      ),
    );
    await t.tap(explorerItem(codeFile));
    await t.pumpAndSettle();
    await t.tap(find.byKey(codeFieldKey));
    await t.pump();
  }

  String file(WidgetTester t) => t
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[codeFile]!;
  TextEditingController editor(WidgetTester t) =>
      t.widget<TextField>(find.byKey(codeFieldKey)).controller!;

  /// Puts the caret at the `|` of [code] (the text without it).
  Future<void> caretAt(WidgetTester t, String code) async {
    final at = code.indexOf('|');
    t.testTextInput.updateEditingValue(
      TextEditingValue(
        text: code.replaceFirst('|', ''),
        selection: TextSelection.collapsed(offset: at),
      ),
    );
    await t.pump();
  }

  /// Types [text] one character at a time at the caret, as a keyboard
  /// without an input method does.
  Future<void> typeText(WidgetTester t, String text) async {
    for (final ch in text.split('')) {
      final v = editor(t).value;
      final at = v.selection.baseOffset;
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: v.text.replaceRange(at, at, ch),
          selection: TextSelection.collapsed(offset: at + 1),
        ),
      );
      await t.pump();
    }
  }

  Finder list() => find.byKey(completionListKey);
  Finder row(String name) => find.byKey(completionRowKey(name));
  List<String> rows(WidgetTester t) => [
    for (final w in t.widgetList<InkWell>(
      find.descendant(of: list(), matching: find.byType(InkWell)),
    ))
      (w.key! as ValueKey<String>).value.substring('code.completion.'.length),
  ];

  const body = 'Sub Form_Load()\n    |\nEnd Sub\n';

  testWidgets('a dot lists the members; Enter puts the chosen one in', (
    t,
  ) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'lstChoices.');
    expect(list(), findsOneWidget);
    expect(rows(t).take(4), ['AddItem', 'Anchor', 'Clear', 'Height']);
    await typeText(t, 'li');
    expect(rows(t), ['List', 'ListCount', 'ListIndex']);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(list(), findsNothing);
    expect(
      editor(t).text,
      'Sub Form_Load()\n    lstChoices.ListIndex\nEnd Sub\n',
    );
    expect(editor(t).selection.baseOffset, 40);
    expect(file(t), editor(t).text);
  });

  testWidgets('two letters of a name open it, one does not; Tab takes it', (
    t,
  ) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'm');
    expect(list(), findsNothing);
    await typeText(t, 's');
    expect(rows(t), ['MsgBox']);
    await t.sendKeyEvent(LogicalKeyboardKey.tab);
    await t.pump();
    expect(editor(t).text, contains('    MsgBox\n'));
    // Tab took it: no spaces were added.
    expect(
      editor(t).selection.baseOffset,
      'Sub Form_Load()\n    MsgBox'.length,
    );
  });

  testWidgets('arrows wrap round; ↑ from the top chooses the last', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'lstChoices.Li');
    await t.sendKeyEvent(LogicalKeyboardKey.arrowUp);
    await t.pump();
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await t.pump();
    expect(editor(t).text, contains('lstChoices.ListIndex\n'));
  });

  testWidgets('a click on a row puts it in', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'chkShowAnswer.C');
    // One letter after a dot keeps the list the dot opened.
    expect(rows(t), ['Caption', 'Checked']);
    await t.tap(row('Checked'));
    await t.pump();
    expect(list(), findsNothing);
    expect(editor(t).text, contains('chkShowAnswer.Checked\n'));
  });

  testWidgets('Esc closes it, and it stays closed for that word', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'lbl');
    expect(rows(t), ['lblNumber', 'lblQuestion', 'lblScore']);
    await t.sendKeyEvent(LogicalKeyboardKey.escape);
    await t.pump();
    expect(list(), findsNothing);
    await typeText(t, 'Q');
    expect(list(), findsNothing);
    // A new word opens it again.
    await typeText(t, ' = ms');
    expect(rows(t), ['MsgBox']);
  });

  testWidgets('a character that cannot be in a name closes it', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'lbl');
    expect(list(), findsOneWidget);
    await typeText(t, ' ');
    expect(list(), findsNothing);
    await typeText(t, 'ls');
    expect(rows(t), ['lstChoices']);
    await typeText(t, '(');
    expect(list(), findsNothing);
  });

  testWidgets('Backspace follows the word; leaving it closes the list', (
    t,
  ) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'lstChoices.ListI');
    expect(rows(t), ['ListIndex']);
    final v = editor(t).value;
    t.testTextInput.updateEditingValue(
      TextEditingValue(
        text: v.text.replaceRange(
          v.selection.baseOffset - 1,
          v.selection.baseOffset,
          '',
        ),
        selection: TextSelection.collapsed(offset: v.selection.baseOffset - 1),
      ),
    );
    await t.pump();
    expect(rows(t), ['List', 'ListCount', 'ListIndex']);
    // The caret moves to another line.
    t.testTextInput.updateEditingValue(
      editor(t).value
          .copyWith(selection: const TextSelection.collapsed(offset: 3)),
    );
    await t.pump();
    expect(list(), findsNothing);
  });

  testWidgets('Enter on a word typed in full breaks the line', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'If x The');
    expect(rows(t), ['Then']);
    await typeText(t, 'n');
    // Only the word itself: nothing to show.
    expect(list(), findsNothing);
    await typeText(t, '\n');
    // The line break, and the block's closing line (block completion).
    expect(
      editor(t).text,
      'Sub Form_Load()\n    If x Then\n        \n    End If\nEnd Sub\n',
    );
  });

  testWidgets('nothing in strings and comments', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    await typeText(t, 'MsgBox("lst.');
    expect(list(), findsNothing);
    await caretAt(t, "Sub Form_Load()\n    ' |\nEnd Sub\n");
    await typeText(t, 'lstChoices.');
    expect(list(), findsNothing);
  });

  testWidgets('nothing while the input method composes', (t) async {
    await open(t, body.replaceFirst('|', ''));
    await caretAt(t, body);
    // A Latin word still being composed (as Japanese input methods do).
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: 'Sub Form_Load()\n    ms\nEnd Sub\n',
        selection: TextSelection.collapsed(offset: 22),
        composing: TextRange(start: 20, end: 22),
      ),
    );
    await t.pump();
    expect(list(), findsNothing);
  });

  for (final mac in [true, false]) {
    testWidgets(
      'the shortcut opens it anywhere, with "did you mean" first '
      '(${mac ? '⌥Space' : 'Ctrl+Space'})',
      variant: TargetPlatformVariant.only(
        mac ? TargetPlatform.macOS : TargetPlatform.windows,
      ),
      (t) async {
        const code = 'Sub Form_Load()\n    lblNumber.Text| = "1"\nEnd Sub\n';
        await open(t, code.replaceFirst('|', ''), strings: IdeStrings.ko);
        await caretAt(t, code);
        final modifier = mac
            ? LogicalKeyboardKey.alt
            : LogicalKeyboardKey.control;
        await t.sendKeyDownEvent(modifier);
        await t.sendKeyEvent(LogicalKeyboardKey.space);
        await t.sendKeyUpEvent(modifier);
        await t.pump();
        expect(find.text('혹시 이것인가요?'), findsOneWidget);
        expect(rows(t).first, 'Caption');
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await t.pump();
        expect(editor(t).text, contains('lblNumber.Caption = "1"'));
        expect(file(t), editor(t).text);
      },
    );
  }

  testWidgets('kinds, types and read-only properties are shown, in Korean', (
    t,
  ) async {
    await open(t, body.replaceFirst('|', ''), strings: IdeStrings.ko);
    await caretAt(t, body);
    await typeText(t, 'lstChoices.ListC');
    expect(
      find.descendant(of: row('ListCount'), matching: find.text('Integer')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: row('ListCount'), matching: find.text('속성, 읽기 전용')),
      findsOneWidget,
    );
  });

  testWidgets('the list shows only while its word is in view', (t) async {
    // The quiz's code has "|" in it: the caret is placed by offset.
    final code = quiz[codeFile]!.replaceFirst(
      'Sub Form_Load()\n',
      'Sub Form_Load()\n    \n',
    );
    await open(t, code);
    t.testTextInput.updateEditingValue(
      TextEditingValue(
        text: code,
        selection: TextSelection.collapsed(
          offset: code.indexOf('Sub Form_Load()\n') + 20,
        ),
      ),
    );
    await t.pump();
    await typeText(t, 'lstChoices.');
    expect(list(), findsOneWidget);
    final wheel = TestPointer(1, PointerDeviceKind.mouse);
    // The field is as tall as the code: a point near its top is on screen.
    final field =
        t.getTopLeft(find.byKey(codeFieldKey)) + const Offset(100, 100);
    await t.sendEventToBinding(wheel.hover(field));
    await t.sendEventToBinding(wheel.scroll(const Offset(0, 3000)));
    await t.pump();
    expect(list(), findsNothing);
    await t.sendEventToBinding(wheel.scroll(const Offset(0, -3000)));
    await t.pump();
    expect(list(), findsOneWidget);
  });
}
