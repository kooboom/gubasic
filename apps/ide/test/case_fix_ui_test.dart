import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// The line the caret leaves is written as GuBASIC writes it once the
/// code rests (DESIGN.md D133): keywords as spelled, names as declared;
/// one undo takes the fix back, and a line whose fix was undone stays as
/// written; nothing is fixed while the input method composes.
void main() {
  final hello = exampleProjects['hello']!;
  const codeFile = 'Form1.gbas';
  const code =
      'Sub Form_Load()\n    dim total as integer\n'
      '    TOTAL = total + 1\nEnd Sub\n';
  const fixed1 = '    Dim total As Integer';

  Future<void> open(WidgetTester t) async {
    t.view.physicalSize = const Size(1400, 900);
    t.view.devicePixelRatio = 1;
    addTearDown(t.view.reset);
    await t.pumpWidget(
      IdeApp(
        projects: {
          'hello': {...hello, codeFile: code},
        },
        strings: IdeStrings.en,
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
  String line(WidgetTester t, int n) => editor(t).text.split('\n')[n];

  Future<void> value(WidgetTester t, TextEditingValue v) async {
    t.testTextInput.updateEditingValue(v);
    await t.pump();
  }

  /// The caret at [offset] of the text as it is.
  Future<void> caret(WidgetTester t, int offset) => value(
    t,
    TextEditingValue(
      text: editor(t).text,
      selection: TextSelection.collapsed(offset: offset),
    ),
  );

  Future<void> undo(WidgetTester t) async {
    await t.sendKeyDownEvent(LogicalKeyboardKey.control);
    await t.sendKeyEvent(LogicalKeyboardKey.keyZ);
    await t.sendKeyUpEvent(LogicalKeyboardKey.control);
    await t.pump();
  }

  final endOf1 = code.indexOf('\n', 16);

  testWidgets('a line left by an arrow or a click is fixed once the code '
      'rests; the caret\'s line is not', (t) async {
    await open(t);
    await caret(t, endOf1);
    await caret(t, endOf1 + 5); // down to line 2
    expect(line(t, 1), '    dim total as integer', reason: 'not at once');
    await t.pump(caseFixDelay);
    expect(line(t, 1), fixed1);
    expect(line(t, 2), '    TOTAL = total + 1', reason: 'the caret is there');
    expect(file(t).split('\n')[1], fixed1, reason: 'the file too');
    await caret(t, 0); // a click on line 0
    await t.pump(caseFixDelay);
    expect(line(t, 2), '    total = total + 1');
  });

  testWidgets('a line left and come back to before the code rests stays', (
    t,
  ) async {
    await open(t);
    await caret(t, endOf1);
    await caret(t, endOf1 + 5);
    await t.pump(caseFixDelay ~/ 2);
    await caret(t, endOf1);
    await t.pump(caseFixDelay * 2);
    expect(line(t, 1), '    dim total as integer');
  });

  testWidgets('Enter leaves the line; one undo takes the fix back, and the '
      'line then stays as written', (t) async {
    await open(t);
    await caret(t, endOf1);
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    final entered = code.replaceRange(endOf1, endOf1, '\n');
    await value(
      t,
      TextEditingValue(
        text: entered,
        selection: TextSelection.collapsed(offset: endOf1 + 1),
      ),
    );
    final typed = editor(t).text;
    await t.pump(caseFixDelay);
    expect(line(t, 1), fixed1);
    await undo(t);
    expect(editor(t).text, typed, reason: 'only the fix taken back');
    await t.pump(caseFixDelay * 2);
    await caret(t, 0);
    await t.pump(caseFixDelay * 2);
    expect(line(t, 1), '    dim total as integer', reason: 'kept as written');
    expect(file(t), editor(t).text);
  });

  testWidgets('leaving the editor leaves the line', (t) async {
    await open(t);
    await caret(t, endOf1);
    FocusManager.instance.primaryFocus?.unfocus();
    await t.pump();
    await t.pump(caseFixDelay);
    expect(line(t, 1), fixed1);
  });

  testWidgets('nothing is fixed while something is being composed (D37)', (
    t,
  ) async {
    await open(t);
    await caret(t, endOf1);
    final end = code.indexOf('End Sub') + 'End Sub'.length;
    await caret(t, end); // to the last line
    // 한 being composed in a comment at the end of the last line.
    final composing = code.replaceRange(end, end, " ' 한");
    await value(
      t,
      TextEditingValue(
        text: composing,
        selection: TextSelection.collapsed(offset: end + 4),
        composing: TextRange(start: end + 3, end: end + 4),
      ),
    );
    await t.pump(caseFixDelay * 3);
    expect(line(t, 1), '    dim total as integer', reason: 'while composing');
    await value(
      t,
      TextEditingValue(
        text: composing,
        selection: TextSelection.collapsed(offset: end + 4),
      ),
    );
    await t.pump(caseFixDelay ~/ 2);
    expect(
      line(t, 1),
      '    dim total as integer',
      reason: 'the commit is a change: the code has not rested yet',
    );
    await t.pump(caseFixDelay);
    expect(line(t, 1), fixed1, reason: 'once committed and at rest');
    expect(file(t), editor(t).text);
    await undo(t);
    expect(editor(t).text, composing, reason: 'one undo: the fix only');
  });
}
