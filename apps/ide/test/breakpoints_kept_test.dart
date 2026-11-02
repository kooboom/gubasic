import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/last_project.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// Breakpoints are kept in the IDE's settings, by project (docs/DESIGN.md
/// D129): set in one IDE, they are there when the IDE opens the project
/// again, and another project has its own.
void main() {
  const files = {
    'Debug.gbproj':
        'formatVersion: 1\nname: Debug\nstartup: Form1\nforms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 1\ncontrols:\n  - name: btnGo\n    type: Button\n'
        '    properties:\n      Caption: Go\n',
    'Form1.gbas':
        'Sub btnGo_Click()\n'
        '    Dim n As Integer = 2\n'
        '    MsgBox("n " & n)\n'
        'End Sub\n',
  };

  Future<void> open(WidgetTester tester, MemoryLastProject store) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: {'hello': files, 'other': files},
        strings: IdeStrings.en,
        lastProject: store,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(explorerItem('Form1.gbas'));
    await tester.pumpAndSettle();
  }

  Future<void> tapGutter(WidgetTester tester, int line) async {
    final gutter = tester.getTopLeft(find.byKey(codeGutterKey));
    final pitch = codeFontSize * codeLineHeight;
    await tester.tapAt(gutter + Offset(10, (line - 1) * pitch + pitch / 2));
    await tester.pumpAndSettle();
  }

  testWidgets('a breakpoint is written to the settings and read back when '
      'the IDE opens the project again', (tester) async {
    final store = MemoryLastProject();
    await open(tester, store);
    await tapGutter(tester, 3);
    expect(find.byKey(codeBreakpointKey(3)), findsOneWidget);
    expect(jsonDecode(store.values['${breakpointsKeyPrefix}example:hello']!), {
      'form1.gbas': [3],
    });

    // The IDE again, with the same settings.
    await tester.pumpWidget(const SizedBox());
    await open(tester, store);
    expect(find.byKey(codeBreakpointKey(3)), findsOneWidget);

    // Taken away: the setting follows.
    await tapGutter(tester, 3);
    expect(find.byKey(codeBreakpointKey(3)), findsNothing);
    expect(
      jsonDecode(store.values['${breakpointsKeyPrefix}example:hello']!),
      <String, Object?>{},
    );
  });

  testWidgets('each project has its own breakpoints', (tester) async {
    final store = MemoryLastProject()
      ..values['${breakpointsKeyPrefix}example:other'] = jsonEncode({
        'Form1.gbas': [2],
      });
    await open(tester, store);
    expect(find.byKey(codeBreakpointKey(2)), findsNothing);
    await tapGutter(tester, 3);

    // Another project from the menu: its own breakpoints, not hello's.
    await tester.tap(
      find.descendant(
        of: find.byType(AppBar),
        matching: find.byType(DropdownButton<String>),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('other').last);
    await tester.pumpAndSettle();
    await tester.tap(explorerItem('Form1.gbas'));
    await tester.pumpAndSettle();
    expect(find.byKey(codeBreakpointKey(2)), findsOneWidget);
    expect(find.byKey(codeBreakpointKey(3)), findsNothing);
    // Hello's were not touched by the switch.
    expect(jsonDecode(store.values['${breakpointsKeyPrefix}example:hello']!), {
      'form1.gbas': [3],
    });
  });
}
