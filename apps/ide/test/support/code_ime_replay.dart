import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/code/code_controller.dart';
import 'package:gubasic_ide/src/code/code_editor.dart';
import 'package:gubasic_ide/src/code/completion_list.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// Replays the real input methods' recordings ([logs]: file name → JSON,
/// from packages/gubasic_runtime/test/ime_logs) into the code editor, in a
/// comment and in a string, and checks what D36 promises: the file gets
/// only committed characters, the editor shows what the input method
/// sent, the colouring keeps the text and its kind, and the final text is
/// the recording's. Also right after a name being completed (`lbl`): the
/// completion list closes at the first jamo and never shows while Hangul
/// is typed (D50). And in a comment after `If … Then`, where Enter then
/// closes the block only if it does not commit Hangul being composed.
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

  // (before, after, the colour of what is typed; null: not checked).
  final places = <String, (String, String, CodeKind?)>{
    'a comment': ("' ", '\n', CodeKind.comment),
    'a string': (
      'Sub Form_Load()\n    Debug.Print("',
      '")\nEnd Sub\n',
      CodeKind.string,
    ),
    'a comment after If … Then': (
      "Sub Form_Load()\n    If x Then ' ",
      '\nEnd Sub\n',
      CodeKind.comment,
    ),
    // Hangul is not code (L002), but a beginner may type it there.
    'code, after a name being completed': (
      'Sub Form_Load()\n    lbl',
      '\nEnd Sub\n',
      null,
    ),
  };
  final list = find.byKey(completionListKey);

  /// Enter at the caret, as the platform sends it: while Hangul is being
  /// composed, a browser commits it first; the macOS app, which sends no
  /// composing range, only breaks the line. The block of the `If` line
  /// ([closes] is where its comment starts) gets `End If` only when
  /// nothing was being composed and the caret was at the line's end.
  Future<TextEditingValue> enter(
    WidgetTester t, {
    required int closes,
    bool? composing,
  }) async {
    final v = editor(t).value;
    final isComposing = file(t) != v.text;
    if (composing != null) {
      expect(isComposing, composing, reason: 'composing as Enter is pressed');
    }
    final at = v.selection.baseOffset;
    await t.sendKeyEvent(LogicalKeyboardKey.enter);
    if (v.composing.isValid && !v.composing.isCollapsed) {
      t.testTextInput.updateEditingValue(
        v.copyWith(composing: TextRange.empty),
      );
      await t.pump();
    }
    final broken = TextEditingValue(
      text: v.text.replaceRange(at, at, '\n'),
      selection: TextSelection.collapsed(offset: at + 1),
    );
    t.testTextInput.updateEditingValue(broken);
    await t.pump();
    final atEnd = at >= closes && v.text.indexOf('\n', at) == at;
    expect(
      editor(t).text.contains('End If'),
      !isComposing && atEnd,
      reason:
          'End If after Enter (composing: $isComposing, at the end: $atEnd)',
    );
    return editor(t).value;
  }

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
        testWidgets(
          'code editor, $source $id, in $where',
          variant: source.endsWith('-app.json')
              ? TargetPlatformVariant.only(TargetPlatform.macOS)
              : const DefaultTestVariant(),
          (t) async {
            if (kind == null) {
              // Type the name's last letter: the list opens.
              final shorter = '${before.substring(0, before.length - 1)}$after';
              await open(t, shorter);
              t.testTextInput.updateEditingValue(
                TextEditingValue(
                  text: shorter,
                  selection: TextSelection.collapsed(offset: before.length - 1),
                ),
              );
              await t.pump();
              t.testTextInput.updateEditingValue(
                TextEditingValue(
                  text: '$before$after',
                  selection: TextSelection.collapsed(offset: before.length),
                ),
              );
              await t.pump();
              expect(list, findsOneWidget, reason: 'the list for lbl');
            } else {
              await open(t, '$before$after');
            }
            var inField = true;
            var last = const TextEditingValue();
            // After If … Then, Enter is pressed at the last moment the
            // recording composes (every recording ends committed): the
            // last value with a composing range, or, in the macOS app,
            // which sends none, the last value before the focus leaves.
            final closesBlock = where == 'a comment after If … Then';
            final app = source.endsWith('-app.json');
            int? enterAt;
            for (var i = 0; closesBlock && i < log.length; i++) {
              final e = log[i];
              if (e['kind'] == 'focus' && e['hasFocus'] == false) break;
              if (e['kind'] == 'value' &&
                  (app || (e['composing']! as List).first as int >= 0)) {
                enterAt = i;
              }
            }
            for (final (i, e) in log.indexed) {
              if (i - 1 == enterAt) break;
              switch (e['kind']) {
                case 'value':
                  final v = shifted(e, before, after);
                  last = v;
                  final fileBefore = file(t);
                  t.testTextInput.updateEditingValue(v);
                  await t.pump();
                  final at = 'at ${e['ms']} ms (${jsonEncode(e['text'])})';
                  expect(editor(t).text, v.text, reason: 'shown $at');
                  // A desktop app's recording has no composing ranges: the
                  // editor guesses them (D37), so no jamo may reach the file.
                  if (source.endsWith('-app.json') && inField) {
                    expect(
                      file(t).runes.any((r) => r >= 0x3131 && r <= 0x318E),
                      isFalse,
                      reason: 'jamo in the file $at',
                    );
                  } else {
                    expect(
                      file(t),
                      inField ? committedText(v) : fileBefore,
                      reason: 'the file $at',
                    );
                  }
                  if (v.text.length > before.length + after.length) {
                    expect(list, findsNothing, reason: 'the list $at');
                  }
                  final kinds = codeKinds(v.text, const {});
                  for (
                    var i = before.length;
                    kind != null && i < v.text.length - after.length;
                    i++
                  ) {
                    expect(
                      CodeKind.values[kinds[i]],
                      kind,
                      reason: 'colour $at',
                    );
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
            if (enterAt != null) {
              final chromeComposing = !app;
              last = await enter(
                t,
                closes: before.length,
                composing: chromeComposing ? true : null,
              );
            }
            FocusManager.instance.primaryFocus?.unfocus();
            await t.pumpAndSettle();
            expect(file(t), last.text, reason: 'the final text');
          },
        );
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
