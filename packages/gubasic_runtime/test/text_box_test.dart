import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// TextBox with a real input method's signals (docs/LANGUAGE.md §11.1).
/// test/ime_logs/ holds what tool/ime_probe recorded from real input
/// methods; each value Flutter received is replayed here in order.
void main() {
  late GbFormModel model;
  late List<String> events;

  String text() => model.control('txtName')!.text('Text');

  Future<void> show(WidgetTester tester) async {
    events = [];
    model = GbFormModel(
      form: {'Caption': '', 'Width': 400, 'Height': 200},
      controls: [
        GbControlState('txtName', GbControlKind.textBox, {
          'Text': '', 'Left': 8, 'Top': 8, 'Width': 240, 'Height': 40, //
        }),
        GbControlState('btnOk', GbControlKind.button, {
          'Caption': 'OK',
          'Left': 8,
          'Top': 60,
          'Width': 100,
          'Height': 40,
        }),
      ],
      // Each event with the committed text at that moment.
      onEvent: (c, e) => events.add('$c.$e [${text()}]'),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GbFormView(model: model)),
      ),
    );
    await tester.tap(find.byType(TextField));
    await tester.pump();
  }

  Future<void> replay(
    WidgetTester tester,
    List<Map<String, Object?>> log,
  ) async {
    for (final e in log.where((e) => e['kind'] == 'value')) {
      final composing = (e['composing']! as List).cast<int>();
      final selection = (e['selection']! as List).cast<int>();
      tester.testTextInput.updateEditingValue(
        TextEditingValue(
          text: e['text']! as String,
          selection: TextSelection(
            baseOffset: selection[0],
            extentOffset: selection[1],
          ),
          composing: TextRange(start: composing[0], end: composing[1]),
        ),
      );
      await tester.pump();
    }
  }

  List<String> changes() => [
    for (final e in events)
      if (e.startsWith('txtName.Changed')) e.substring(16),
  ];

  for (final file in Directory('test/ime_logs').listSync().whereType<File>()) {
    final source = file.uri.pathSegments.last;
    final log = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final scenarios = (log['scenarios']! as Map<String, Object?>).map(
      (k, v) => MapEntry(k, (v! as List).cast<Map<String, Object?>>()),
    );

    /// The scenario's entries from its last reset (or the start) on.
    List<Map<String, Object?>> last(String id, {int skipResets = 0}) {
      final entries = scenarios[id]!;
      final resets = [
        for (var i = 0; i < entries.length; i++)
          if (entries[i]['kind'] == 'reset') i,
      ];
      final from = resets.length > skipResets
          ? resets[resets.length - 1 - skipResets] + 1
          : 0;
      return entries.sublist(from);
    }

    group(source, () {
      testWidgets('dokkaebibul 갈가: 갈 is committed only when ㅏ is typed', (
        tester,
      ) async {
        await show(tester);
        await replay(tester, scenarios['dokkaebi']!);
        // 갈 and 갉 were still being composed: no Changed until 갈가.
        expect(changes(), ['[갈]', '[갈가]']);
        expect(text(), '갈가');
      });

      testWidgets('double final consonants 닭 and 값', (tester) async {
        await show(tester);
        await replay(tester, scenarios['double_final']!);
        expect(changes().last, '[닭 값 ]');
        expect(changes(), contains('[닭]'));
        expect(changes(), isNot(contains('[달]')));
        expect(changes(), isNot(contains('[닭ㄱ]')));
      });

      testWidgets('Backspace while composing: 한 becomes 하, not empty', (
        tester,
      ) async {
        await show(tester);
        await replay(tester, scenarios['backspace']!);
        expect(changes(), ['[하]']);
        expect(text(), '하');
      });

      testWidgets('a click while composing: commit, Changed, then Click', (
        tester,
      ) async {
        await show(tester);
        // Everything typed before the click, without the commit that the
        // browser made when the field lost the focus: the runtime must
        // commit by itself on platforms that do not.
        final typed = last('click').takeWhile((e) => e['kind'] != 'click');
        final composing = typed
            .where(
              (e) =>
                  e['kind'] == 'value' && (e['composing']! as List).first != -1,
            )
            .toList();
        await replay(tester, composing);
        expect(text(), '한', reason: '글 is still being composed');
        events.clear();
        await tester.tap(find.text('OK'));
        await tester.pump();
        expect(events, ['txtName.Changed [한글]', 'btnOk.Click [한글]']);
      });

      testWidgets('a click after the browser committed: Click sees 한글', (
        tester,
      ) async {
        await show(tester);
        for (final skip in [1, 0]) {
          final typed = last(
            'click',
            skipResets: skip,
          ).takeWhile((e) => e['kind'] != 'click');
          await replay(tester, typed.toList());
          events.clear();
          await tester.tap(find.text('OK'));
          await tester.pump();
          expect(events, ['btnOk.Click [한글]']);
          await tester.tap(find.byType(TextField));
          await tester.pump();
        }
      });
    });
  }

  testWidgets('the program sets Text: shown, and no Changed from here', (
    tester,
  ) async {
    await show(tester);
    model.control('txtName')!.set('Text', '프로그램');
    await tester.pump();
    expect(find.text('프로그램'), findsOneWidget);
    expect(events, isEmpty);
    // The user goes on typing after it.
    tester.testTextInput.updateEditingValue(
      const TextEditingValue(
        text: '프로그램!',
        selection: TextSelection.collapsed(offset: 5),
      ),
    );
    await tester.pump();
    expect(events, ['txtName.Changed [프로그램!]']);
  });

  test('committedText leaves out the part being composed', () {
    expect(
      committedText(
        const TextEditingValue(
          text: '한글',
          composing: TextRange(start: 1, end: 2),
        ),
      ),
      '한',
    );
    expect(committedText(const TextEditingValue(text: '한글')), '한글');
    expect(
      committedText(
        const TextEditingValue(
          text: 'ab',
          composing: TextRange(start: 1, end: 9),
        ),
      ),
      'ab',
      reason: 'a composing range past the text is ignored (#193847)',
    );
  });
}
