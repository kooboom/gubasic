import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

/// Enter at the end of a line that opens a block puts in its closing line
/// (DESIGN.md D50), but not when Enter commits what the input method is
/// composing.
void main() {
  final hello = exampleProjects['hello']!;
  const codeFile = 'Form1.gbas';

  Future<void> open(WidgetTester t, String code) async {
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
    await t.tap(find.text(codeFile));
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

  Future<void> value(WidgetTester t, TextEditingValue v) async {
    t.testTextInput.updateEditingValue(v);
    await t.pump();
  }

  /// Opens [code] with the caret at its `|`, and presses Enter there: the
  /// key, then the line break the platform sends.
  Future<String> enterAt(WidgetTester t, String code) async {
    final at = code.indexOf('|');
    final text = code.replaceFirst('|', '');
    await open(t, text);
    await value(
      t,
      TextEditingValue(
        text: text,
        selection: TextSelection.collapsed(offset: at),
      ),
    );
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    await value(
      t,
      TextEditingValue(
        text: text.replaceRange(at, at, '\n'),
        selection: TextSelection.collapsed(offset: at + 1),
      ),
    );
    final v = editor(t).value;
    return v.text.replaceRange(
      v.selection.baseOffset,
      v.selection.baseOffset,
      '|',
    );
  }

  for (final (opener, closer) in [
    ('If x > 1 Then', 'End If'),
    ('For i = 1 To 3', 'Next'),
    ('For Each n In names', 'Next'),
    ('Do While x < 3', 'Loop'),
    ('Do', 'Loop'),
    ('Select Case x', 'End Select'),
    ('Try', 'End Try'),
  ]) {
    testWidgets('$opener gets $closer', (t) async {
      final after = await enterAt(
        t,
        'Sub Form_Load()\n    $opener|\nEnd Sub\n',
      );
      expect(
        after,
        'Sub Form_Load()\n    $opener\n        |\n    $closer\nEnd Sub\n',
      );
      expect(file(t), after.replaceFirst('|', ''));
    });
  }

  testWidgets('Sub gets End Sub', (t) async {
    expect(
      await enterAt(t, 'Private Sub Work()|\n'),
      'Private Sub Work()\n    |\nEnd Sub\n',
    );
  });

  testWidgets('Function gets End Function, before the next procedure', (
    t,
  ) async {
    expect(
      await enterAt(
        t,
        'Function Twice(n As Integer) As Integer|\n\nSub A()\nEnd Sub\n',
      ),
      'Function Twice(n As Integer) As Integer\n    |\nEnd Function\n\nSub A()\nEnd Sub\n',
    );
  });

  testWidgets('a comment after the opener does not matter', (t) async {
    expect(
      await enterAt(t, "Sub Form_Load()\n    If x Then ' check|\nEnd Sub\n"),
      "Sub Form_Load()\n    If x Then ' check\n        |\n    End If\nEnd Sub\n",
    );
  });

  for (final (what, code) in [
    (
      'a block already closed',
      'Sub Form_Load()\n    If x Then|\n    End If\nEnd Sub\n',
    ),
    ('a single-line If', 'Sub Form_Load()\n    If x Then y = 1|\nEnd Sub\n'),
    (
      'a line split in the middle',
      'Sub Form_Load()\n    If x |Then\nEnd Sub\n',
    ),
    ('a line that opens nothing', 'Sub Form_Load()\n    x = 1|\nEnd Sub\n'),
  ]) {
    testWidgets('nothing for $what', (t) async {
      final after = await enterAt(t, code);
      expect(after, isNot(contains('End If\n    End If')));
      expect(
        'End If'.allMatches(after).length,
        'End If'.allMatches(code).length,
      );
    });
  }

  group('Enter that commits Hangul being composed', () {
    const code = "Sub Form_Load()\n    If x Then ' 확인\nEnd Sub\n";
    final end = code.indexOf('\nEnd Sub');

    testWidgets('as a browser sends it: the commit, then the line break', (
      t,
    ) async {
      await open(t, code);
      // 인 is being composed.
      await value(
        t,
        TextEditingValue(
          text: code,
          selection: TextSelection.collapsed(offset: end),
          composing: TextRange(start: end - 1, end: end),
        ),
      );
      // Enter: the key (Windows sends "Process"), the commit, the break.
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await value(
        t,
        TextEditingValue(
          text: code,
          selection: TextSelection.collapsed(offset: end),
        ),
      );
      await value(
        t,
        TextEditingValue(
          text: code.replaceRange(end, end, '\n'),
          selection: TextSelection.collapsed(offset: end + 1),
        ),
      );
      expect(editor(t).text, isNot(contains('End If')));
      expect(file(t), "Sub Form_Load()\n    If x Then ' 확인\n    \nEnd Sub\n");
    });

    testWidgets('as a browser sends it, Enter later still closes the block', (
      t,
    ) async {
      await open(t, code);
      await value(
        t,
        TextEditingValue(
          text: code,
          selection: TextSelection.collapsed(offset: end),
          composing: TextRange(start: end - 1, end: end),
        ),
      );
      // Committed some other way (a click on the line), no line break.
      await value(
        t,
        TextEditingValue(
          text: code,
          selection: TextSelection.collapsed(offset: end),
        ),
      );
      // Then a real Enter.
      await t.sendKeyEvent(LogicalKeyboardKey.enter);
      await value(
        t,
        TextEditingValue(
          text: code.replaceRange(end, end, '\n'),
          selection: TextSelection.collapsed(offset: end + 1),
        ),
      );
      expect(editor(t).text, contains('\n    End If\nEnd Sub'));
    });

    testWidgets(
      'in the macOS app, which sends no composing range',
      variant: TargetPlatformVariant.only(TargetPlatform.macOS),
      (t) async {
        final start = code.replaceFirst('확인', '확');
        final at = start.indexOf('\nEnd Sub');
        await open(t, start);
        await value(
          t,
          TextEditingValue(
            text: start,
            selection: TextSelection.collapsed(offset: at),
          ),
        );
        // ㅇ, 이, 인 after 확: the syllable is guessed as being composed.
        for (final syllable in ['ㅇ', '이', '인']) {
          final text = start.replaceRange(at, at, syllable);
          await value(
            t,
            TextEditingValue(
              text: text,
              selection: TextSelection.collapsed(offset: at + 1),
            ),
          );
        }
        await t.sendKeyEvent(LogicalKeyboardKey.enter);
        await value(
          t,
          TextEditingValue(
            text: code.replaceRange(end, end, '\n'),
            selection: TextSelection.collapsed(offset: end + 1),
          ),
        );
        expect(editor(t).text, isNot(contains('End If')));
      },
    );
  });
}
