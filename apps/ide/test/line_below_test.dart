import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/code/completion_list.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

/// ⌘Enter / Ctrl+Enter (D73): a new line below the caret's, wherever the
/// caret is on it, made as an Enter at the line's end makes it.
void main() {
  const codeFile = 'Form1.gbas';
  const code =
      'Sub A()\n'
      '    If x > 0 Then\n'
      '        x = 1\n'
      '    End If\n'
      'End Sub\n';
  const both = TargetPlatformVariant({
    TargetPlatform.macOS,
    TargetPlatform.windows,
  });

  Future<void> open(WidgetTester tester, String text) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {
          'hello': {...exampleProjects['hello']!, codeFile: text},
        },
        strings: IdeStrings.en,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(codeFile));
    await tester.pumpAndSettle();
  }

  TextEditingController editor(WidgetTester tester) =>
      tester.widget<TextField>(find.byKey(codeFieldKey)).controller!;

  /// ⌘Enter on a Mac, Ctrl+Enter elsewhere, with the caret at [at].
  Future<void> lineBelow(WidgetTester tester, int at) async {
    editor(tester).selection = TextSelection.collapsed(offset: at);
    await tester.pump();
    final modifier = defaultTargetPlatform == TargetPlatform.macOS
        ? LogicalKeyboardKey.metaLeft
        : LogicalKeyboardKey.controlLeft;
    await tester.sendKeyDownEvent(modifier);
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.sendKeyUpEvent(modifier);
    await tester.pumpAndSettle();
  }

  testWidgets(
    'in the middle of a line: a line below it, indented as it is; '
    'the line itself unchanged',
    variant: both,
    (tester) async {
      await open(tester, code);
      await lineBelow(tester, code.indexOf('= 1'));
      final want = code.replaceFirst('x = 1\n', 'x = 1\n        \n');
      expect(editor(tester).text, want);
      expect(
        editor(tester).selection,
        TextSelection.collapsed(
          offset: want.indexOf('        \n    End If') + 8,
        ),
      );
    },
  );

  testWidgets('on End If: the way out of the block', variant: both, (
    tester,
  ) async {
    await open(tester, code);
    await lineBelow(tester, code.indexOf('nd If'));
    final want = code.replaceFirst('End If\n', 'End If\n    \n');
    expect(editor(tester).text, want);
    expect(
      editor(tester).selection,
      TextSelection.collapsed(offset: want.indexOf('    \nEnd Sub') + 4),
    );
  });

  testWidgets(
    'on a Sub with no End Sub, the caret anywhere on it: the block '
    'is closed as Enter closes it',
    variant: both,
    (tester) async {
      const open1 = 'Sub Go()';
      await open(tester, open1);
      await lineBelow(tester, 2);
      expect(editor(tester).text, 'Sub Go()\n    \nEnd Sub');
      expect(
        editor(tester).selection,
        const TextSelection.collapsed(offset: 13),
      );
    },
  );

  testWidgets(
    'with the completion list open: the list closes, the word '
    'stays as typed, and the line below is made',
    variant: both,
    (tester) async {
      const typed = 'Sub A()\n    Ms\nEnd Sub\n';
      await open(tester, typed);
      editor(tester).selection = TextSelection.collapsed(
        offset: typed.indexOf('Ms') + 2,
      );
      await tester.pump();
      final apple = defaultTargetPlatform == TargetPlatform.macOS;
      final modifier = apple
          ? LogicalKeyboardKey.altLeft
          : LogicalKeyboardKey.controlLeft;
      await tester.sendKeyDownEvent(modifier);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.sendKeyUpEvent(modifier);
      await tester.pumpAndSettle();
      expect(find.byType(CompletionList), findsOneWidget);

      await lineBelow(tester, editor(tester).selection.baseOffset);
      expect(find.byType(CompletionList), findsNothing);
      expect(editor(tester).text, 'Sub A()\n    Ms\n    \nEnd Sub\n');
    },
  );
}
