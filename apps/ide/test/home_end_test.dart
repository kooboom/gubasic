import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

/// Home and End in the code editor (D71): along the caret's line on every
/// system, Home first after the indentation, then at the line's start.
void main() {
  const codeFile = 'Form1.gbas';
  const code = 'Sub A()\n    x = 1\nEnd Sub\n';
  final indent = code.indexOf('x = 1');
  final lineStart = indent - 4;
  final lineEnd = code.indexOf('\nEnd Sub');

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

  Future<TextSelection> press(
    WidgetTester tester,
    LogicalKeyboardKey key, {
    bool shift = false,
    bool meta = false,
  }) async {
    if (shift) await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    if (meta) await tester.sendKeyDownEvent(LogicalKeyboardKey.metaLeft);
    await tester.sendKeyEvent(key);
    if (meta) await tester.sendKeyUpEvent(LogicalKeyboardKey.metaLeft);
    if (shift) await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    return editor(tester).selection;
  }

  testWidgets(
    'Home goes after the indentation, then to the start, then back; End '
    'to the end of the line; with Shift they select',
    variant: const TargetPlatformVariant({
      TargetPlatform.macOS,
      TargetPlatform.windows,
      TargetPlatform.linux,
    }),
    (tester) async {
      await open(tester, code);
      final middle = indent + 2;
      editor(tester).selection = TextSelection.collapsed(offset: middle);
      await tester.pump();

      const home = LogicalKeyboardKey.home;
      const end = LogicalKeyboardKey.end;
      expect(
        await press(tester, home),
        TextSelection.collapsed(offset: indent),
      );
      expect(
        await press(tester, home),
        TextSelection.collapsed(offset: lineStart),
      );
      expect(
        await press(tester, home),
        TextSelection.collapsed(offset: indent),
      );
      expect(
        await press(tester, end),
        TextSelection.collapsed(offset: lineEnd),
      );
      expect(
        await press(tester, end),
        TextSelection.collapsed(offset: lineEnd),
      );

      // Shift: the selection's other end stays.
      expect(
        await press(tester, home, shift: true),
        TextSelection(baseOffset: lineEnd, extentOffset: indent),
      );
      expect(
        await press(tester, home, shift: true),
        TextSelection(baseOffset: lineEnd, extentOffset: lineStart),
      );
      editor(tester).selection = TextSelection.collapsed(offset: middle);
      await tester.pump();
      expect(
        await press(tester, end, shift: true),
        TextSelection(baseOffset: middle, extentOffset: lineEnd),
      );
      expect(editor(tester).text, code, reason: 'nothing typed');
    },
  );

  testWidgets('on a line of spaces only, Home goes to its start', (
    tester,
  ) async {
    const blank = 'Sub A()\n        \nEnd Sub\n';
    final start = blank.indexOf('\n') + 1;
    await open(tester, blank);
    editor(tester).selection = TextSelection.collapsed(offset: start + 6);
    await tester.pump();
    expect(
      await press(tester, LogicalKeyboardKey.home),
      TextSelection.collapsed(offset: start),
    );
    expect(
      await press(tester, LogicalKeyboardKey.home),
      TextSelection.collapsed(offset: start),
    );
  });

  testWidgets(
    'on macOS, ⌘← and ⌘↓ still do what macOS does',
    variant: TargetPlatformVariant.only(TargetPlatform.macOS),
    (tester) async {
      await open(tester, code);
      editor(tester).selection = TextSelection.collapsed(offset: indent + 2);
      await tester.pump();
      expect(
        await press(tester, LogicalKeyboardKey.arrowLeft, meta: true),
        TextSelection.collapsed(offset: lineStart),
        reason: 'the line start, indentation and all',
      );
      expect(
        (await press(
          tester,
          LogicalKeyboardKey.arrowDown,
          meta: true,
        )).baseOffset,
        code.length,
      );
    },
  );

  testWidgets('End on a long line brings its end into view, Home its start', (
    tester,
  ) async {
    final long = 'Sub A()\n    s = "${'x' * 400}"\nEnd Sub\n';
    await open(tester, long);
    editor(tester).selection = TextSelection.collapsed(
      offset: long.indexOf('s ='),
    );
    await tester.pump();
    final sideways = tester
        .state<ScrollableState>(
          find
              .descendant(
                of: find.byType(CodeEditor),
                matching: find.byWidgetPredicate(
                  (w) =>
                      w is Scrollable && w.axisDirection == AxisDirection.right,
                ),
              )
              .first,
        )
        .position;
    expect(sideways.pixels, 0);
    await press(tester, LogicalKeyboardKey.end);
    expect(editor(tester).selection.baseOffset, long.indexOf('\nEnd Sub'));
    expect(sideways.pixels, greaterThan(0));
    await press(tester, LogicalKeyboardKey.home);
    await press(tester, LogicalKeyboardKey.home);
    expect(sideways.pixels, 0);
  });
}
