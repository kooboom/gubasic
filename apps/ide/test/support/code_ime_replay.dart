import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_controller.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// Replays the real input methods' recordings ([logs]: file name → JSON,
/// from packages/gubasic_runtime/test/ime_logs) into the code editor, in a
/// comment and in a string, and checks what D36 promises: the file gets
/// only committed characters, the editor shows what the input method
/// sent, the colouring keeps the text and its kind, and the final text is
/// the recording's.
void defineCodeImeTests(Map<String, String> logs) {
  final hello = exampleProjects['hello']!;
  const codeFile = 'Form1.gbas';

  String file(WidgetTester t) => t
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[codeFile]!;
  TextEditingController editor(WidgetTester t) =>
      t.widget<TextField>(find.byKey(codeFieldKey)).controller!;

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

  TextEditingValue shifted(
    Map<String, Object?> e,
    String before,
    String after,
  ) {
    final c = (e['composing']! as List).cast<int>();
    final s = (e['selection']! as List).cast<int>();
    final n = before.length;
    return TextEditingValue(
      text: '$before${e['text']}$after',
      selection: TextSelection(baseOffset: s[0] + n, extentOffset: s[1] + n),
      composing: c[0] < 0
          ? TextRange.empty
          : TextRange(start: c[0] + n, end: c[1] + n),
    );
  }

  final places = {
    'a comment': ("' ", '\n', CodeKind.comment),
    'a string': (
      'Sub Form_Load()\n    Debug.Print("',
      '")\nEnd Sub\n',
      CodeKind.string,
    ),
  };

  for (final MapEntry(key: source, value: json) in logs.entries) {
    final scenarios = (jsonDecode(json)['scenarios'] as Map<String, Object?>)
        .map((k, v) => MapEntry(k, (v! as List).cast<Map<String, Object?>>()));
    for (final MapEntry(key: id, value: all) in scenarios.entries) {
      final resets = [
        for (var i = 0; i < all.length; i++)
          if (all[i]['kind'] == 'reset') i,
      ];
      final log = all.sublist(resets.isEmpty ? 0 : resets.last + 1);
      for (final MapEntry(key: where, value: (before, after, kind))
          in places.entries) {
        testWidgets('code editor, $source $id, in $where', (t) async {
          await open(t, '$before$after');
          var inField = true;
          var last = const TextEditingValue();
          for (final e in log) {
            switch (e['kind']) {
              case 'value':
                final v = shifted(e, before, after);
                last = v;
                final fileBefore = file(t);
                t.testTextInput.updateEditingValue(v);
                await t.pump();
                final at = 'at ${e['ms']} ms (${jsonEncode(e['text'])})';
                expect(editor(t).text, v.text, reason: 'shown $at');
                expect(
                  file(t),
                  inField ? committedText(v) : fileBefore,
                  reason: 'the file $at',
                );
                final kinds = codeKinds(v.text, const {});
                for (
                  var i = before.length;
                  i < v.text.length - after.length;
                  i++
                ) {
                  expect(CodeKind.values[kinds[i]], kind, reason: 'colour $at');
                }
              case 'focus' when e['hasFocus'] == false && inField:
                FocusManager.instance.primaryFocus?.unfocus();
                await t.pump();
                inField = false;
              case 'focus' when e['hasFocus'] == true && !inField:
                await t.tap(find.byKey(codeFieldKey));
                await t.pump();
                inField = true;
            }
          }
          FocusManager.instance.primaryFocus?.unfocus();
          await t.pumpAndSettle();
          expect(file(t), last.text, reason: 'the final text');
        });
      }
    }
  }

  testWidgets('Enter while composing commits it, then breaks the line', (
    t,
  ) async {
    await open(t, "' \n");
    for (final (text, s, e) in [
      ('ㅎ', 0, 1),
      ('하', 0, 1),
      ('한', 0, 1),
      ('한ㄱ', 1, 2),
      ('한그', 1, 2),
      ('한글', 1, 2),
    ]) {
      t.testTextInput.updateEditingValue(
        TextEditingValue(
          text: "' $text\n",
          selection: TextSelection.collapsed(offset: 2 + text.length),
          composing: TextRange(start: 2 + s, end: 2 + e),
        ),
      );
      await t.pump();
    }
    expect(file(t), "' 한\n");
    // What a browser sends on Enter: the commit, then the line break.
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "' 한글\n",
        selection: TextSelection.collapsed(offset: 4),
      ),
    );
    await t.pump();
    t.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: "' 한글\n\n",
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await t.pumpAndSettle();
    expect(file(t), "' 한글\n\n");
  });
}
