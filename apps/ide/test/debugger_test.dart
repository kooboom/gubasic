import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_player/gubasic_player.dart';

import 'support/explorer.dart';

/// The debugger in the IDE (docs/DESIGN.md D124 E, D127): a click in the
/// gutter or F9 sets a breakpoint, the program pauses there with its code
/// shown and its variables below, F8 steps into a call, Shift+F8 over one,
/// F5 goes on, and breakpoints move with their lines as the code changes.
void main() {
  const files = {
    'Debug.gbproj':
        'formatVersion: 1\nname: Debug\nstartup: Form1\nforms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 1\ncontrols:\n  - name: btnGo\n    type: Button\n'
        '    properties:\n      Caption: Go\n',
    'Form1.gbas':
        'Dim total As Integer\n'
        'Sub btnGo_Click()\n'
        '    Dim n As Integer = 2\n'
        '    total = Add(n, 3)\n'
        '    MsgBox("sum " & total)\n'
        'End Sub\n'
        'Function Add(a As Integer, b As Integer) As Integer\n'
        '    Return a + b\n'
        'End Function\n',
  };

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': files}, strings: IdeStrings.en),
    );
    await tester.tap(explorerItem('Form1.gbas'));
    await tester.pumpAndSettle();
    expect(find.byKey(codeFieldKey), findsOneWidget);
  }

  /// A tap in the gutter on [line].
  Future<void> tapGutter(WidgetTester tester, int line) async {
    final gutter = tester.getTopLeft(find.byKey(codeGutterKey));
    final pitch = codeFontSize * codeLineHeight;
    await tester.tapAt(gutter + Offset(10, (line - 1) * pitch + pitch / 2));
    await tester.pumpAndSettle();
  }

  Future<void> settleRun(WidgetTester tester) async {
    for (var i = 0; i < 50; i++) {
      await tester.pump(const Duration(milliseconds: 20));
    }
  }

  testWidgets('a breakpoint pauses the program: code, variables, steps, '
      'continue', (tester) async {
    await open(tester);
    await tapGutter(tester, 4);
    expect(find.byKey(codeBreakpointKey(4)), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsOneWidget);
    await tester.tap(find.text('Go'));
    await settleRun(tester);

    // Paused at line 4: the code is shown with the line marked, and the
    // variables beside the output.
    expect(find.byKey(codePausedLineKey), findsOneWidget);
    expect(find.byKey(const ValueKey('debug.variables')), findsOneWidget);
    expect(
      find.text('Paused at line 4 of Form1.gbas, in btnGo_Click'),
      findsOneWidget,
    );
    expect(find.textContaining('n = 2'), findsOneWidget);
    expect(find.textContaining('total = 0'), findsOneWidget);
    expect(find.byKey(const ValueKey('toolbar.stepInto')), findsOneWidget);
    expect(find.text('Continue (F5)'), findsOneWidget);

    // The Immediate window (D128): an expression in the paused frame.
    await tester.enterText(
      find.byKey(const ValueKey('debug.immediate')),
      '? n + 1',
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await settleRun(tester);
    expect(find.text('? n + 1'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(
      find.text('Paused at line 4 of Form1.gbas, in btnGo_Click'),
      findsOneWidget,
      reason: 'still paused there',
    );

    // F8 into Add.
    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await settleRun(tester);
    expect(find.text('Paused at line 8 of Form1.gbas, in Add'), findsOneWidget);
    expect(find.textContaining('a = 2'), findsOneWidget);
    expect(find.textContaining('btnGo_Click  Form1.gbas:4'), findsOneWidget);

    // Shift+F8: Return runs; Add's end is the next step in btnGo_Click.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f8);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await settleRun(tester);
    expect(
      find.text('Paused at line 5 of Form1.gbas, in btnGo_Click'),
      findsOneWidget,
    );
    expect(find.textContaining('total = 5'), findsOneWidget);

    // F5 goes on: the MsgBox shows, in the run window again.
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await settleRun(tester);
    expect(find.byKey(codePausedLineKey), findsNothing);
    expect(find.text('sum 5'), findsOneWidget);
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();

    // Shift+F5 stops; the breakpoint stays for the next run.
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
    await tester.pumpAndSettle();
    expect(find.byType(RunWindow), findsNothing);
    expect(find.byKey(codeBreakpointKey(4)), findsOneWidget);
  });

  testWidgets('F9 toggles the caret\'s line; a line added above moves the '
      'breakpoint; Clear All takes them away', (tester) async {
    await open(tester);
    // The caret on line 5.
    await tester.tap(find.byKey(codeFieldKey));
    await tester.pumpAndSettle();
    final field = tester.widget<TextField>(find.byKey(codeFieldKey));
    final text = field.controller!.text;
    field.controller!.selection = TextSelection.collapsed(
      offset: text.indexOf('    MsgBox'),
    );
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    expect(find.byKey(codeBreakpointKey(5)), findsOneWidget);

    // A line added at the top: the breakpoint is on line 6 now.
    field.controller!.value = TextEditingValue(
      text: "' a comment\n$text",
      selection: const TextSelection.collapsed(offset: 0),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(codeBreakpointKey(6)), findsOneWidget);
    expect(find.byKey(codeBreakpointKey(5)), findsNothing);

    await tester.sendKeyEvent(LogicalKeyboardKey.f9);
    await tester.pumpAndSettle();
    expect(find.byKey(codeBreakpointKey(1)), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('menu.debug')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.clearBreakpoints')));
    await tester.pumpAndSettle();
    expect(find.byKey(codeBreakpointKey(1)), findsNothing);
    expect(find.byKey(codeBreakpointKey(6)), findsNothing);
  });

  testWidgets('Pause stops at the next statement; Stop while paused ends '
      'the run', (tester) async {
    await open(tester);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toolbar.pause')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    await settleRun(tester);
    expect(
      find.text('Paused at line 3 of Form1.gbas, in btnGo_Click'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey('toolbar.stop')));
    await tester.pumpAndSettle();
    expect(find.byKey(codePausedLineKey), findsNothing);
    expect(find.text(IdeStrings.en.stopped), findsOneWidget);
  });
}
