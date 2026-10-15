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

  List<String> changes() => [
    for (final e in events)
      if (e.startsWith('txtName.Changed')) e.substring(16),
  ];

  /// Replays the recorded values in order and checks, after each one, what
  /// LANGUAGE §11.1 promises for every input method:
  /// - `Text` holds only the characters the input method has committed;
  /// - `Changed` runs each time the committed text changes, and only then.
  Future<void> replay(
    WidgetTester tester,
    Iterable<Map<String, Object?>> log,
  ) async {
    for (final e in log.where((e) => e['kind'] == 'value')) {
      final composing = (e['composing']! as List).cast<int>();
      final selection = (e['selection']! as List).cast<int>();
      final value = TextEditingValue(
        text: e['text']! as String,
        selection: TextSelection(
          baseOffset: selection[0],
          extentOffset: selection[1],
        ),
        composing: TextRange(start: composing[0], end: composing[1]),
      );
      final before = text();
      final changed = changes().length;
      tester.testTextInput.updateEditingValue(value);
      await tester.pump();
      final at = 'at ${e['ms']} ms (${e['text']}, composing $composing)';
      expect(text(), committedText(value), reason: 'only committed text $at');
      expect(
        changes().length,
        changed + (text() == before ? 0 : 1),
        reason: 'Changed once per commit $at',
      );
    }
  }

  /// No Changed shows a syllable in the middle of being typed: a lone jamo
  /// (ㄱ, ㅏ) never comes out of a finished syllable in 2-set typing.
  void expectNoLoneJamo() {
    for (final c in changes()) {
      expect(
        c.runes.any((r) => r >= 0x3131 && r <= 0x318E),
        isFalse,
        reason: 'mid-syllable $c',
      );
    }
  }

  for (final file in Directory('test/ime_logs').listSync().whereType<File>()) {
    final source = file.uri.pathSegments.last;
    final log = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    final scenarios = (log['scenarios']! as Map<String, Object?>).map(
      (k, v) => MapEntry(k, (v! as List).cast<Map<String, Object?>>()),
    );

    /// The scenario's entries from its last reset (or the start) on: the
    /// probe's 다시 starts a scenario over, and only the last try counts.
    /// Every scenario is replayed through this.
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

    /// The events this recording made, pinned exactly (see [recorded]).
    void expectRecorded(String scenario) {
      final pinned = recorded[source]?[scenario];
      if (pinned == null) {
        fail(
          'No pinned events for $source $scenario. If the rules above pass, '
          'check these and add them to `recorded`: ${jsonEncode(events)}',
        );
      }
      expect(events, pinned);
    }

    group(source, () {
      testWidgets('dokkaebibul 갈가: 갈 is committed only when ㅏ is typed', (
        tester,
      ) async {
        await show(tester);
        await replay(tester, last('dokkaebi'));
        // 갉 was only ever being composed.
        expectNoLoneJamo();
        expect(changes(), everyElement(isNot(contains('갉'))));
        expect(text(), '갈가');
        expectRecorded('dokkaebi');
      });

      testWidgets('double final consonants 닭 and 값', (tester) async {
        await show(tester);
        await replay(tester, last('double_final'));
        // 달 and 갑 were only ever being composed.
        expectNoLoneJamo();
        expect(changes(), everyElement(isNot(contains('달'))));
        expect(changes(), everyElement(isNot(contains('갑'))));
        expect(text(), '닭 값 ');
        expectRecorded('double_final');
      });

      testWidgets('Backspace while composing: 한 becomes 하, not empty', (
        tester,
      ) async {
        await show(tester);
        await replay(tester, last('backspace'));
        // 한 was only ever being composed.
        expectNoLoneJamo();
        expect(changes(), everyElement(isNot(contains('한'))));
        expect(text(), '하');
        expectRecorded('backspace');
      });

      testWidgets('a click while composing: commit, Changed, then Click', (
        tester,
      ) async {
        await show(tester);
        // Everything typed before the click, without the commit that the
        // browser made when the field lost the focus: the runtime must
        // commit by itself on platforms that do not.
        final typed = last('click').takeWhile((e) => e['kind'] != 'click');
        await replay(
          tester,
          typed.where(
            (e) =>
                e['kind'] == 'value' && (e['composing']! as List).first != -1,
          ),
        );
        expect(text(), '한', reason: '글 is still being composed');
        final before = events.length;
        await tester.tap(find.text('OK'));
        await tester.pump();
        expect(events.sublist(before), [
          'txtName.Changed [한글]',
          'btnOk.Click [한글]',
        ]);
        expectNoLoneJamo();
        expectRecorded('click_composing');
      });

      // Recordings made before scenario 5 existed do not have it.
      testWidgets(
        'erasing committed text: 닭값, erased, then 닭 값',
        skip: !scenarios.containsKey('erase_retype'),
        (tester) async {
          await show(tester);
          await replay(tester, last('erase_retype'));
          expectNoLoneJamo();
          expect(changes(), contains('[]'), reason: 'erased to empty');
          expect(text(), '닭 값 ');
          expectRecorded('erase_retype');
        },
      );

      testWidgets(
        'erasing committed text: 한글, 한긂, erased to empty',
        skip: !scenarios.containsKey('erase_jamo'),
        (tester) async {
          await show(tester);
          await replay(tester, last('erase_jamo'));
          // 긂 was only ever being composed.
          expectNoLoneJamo();
          expect(changes(), everyElement(isNot(contains('긂'))));
          expect(text(), '');
          expectRecorded('erase_jamo');
        },
      );

      testWidgets('a click after the browser committed: Click sees 한글', (
        tester,
      ) async {
        await show(tester);
        // Scenario 4 is done twice on purpose: button A, 다시, button B.
        for (final skip in [1, 0]) {
          final typed = last(
            'click',
            skipResets: skip,
          ).takeWhile((e) => e['kind'] != 'click');
          await replay(tester, typed);
          final before = events.length;
          await tester.tap(find.text('OK'));
          await tester.pump();
          expect(events.sublist(before), ['btnOk.Click [한글]']);
          await tester.tap(find.byType(TextField));
          await tester.pump();
        }
        expectNoLoneJamo();
        expectRecorded('click_committed');
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

/// What each recording made, event by event, with the committed text at
/// that moment. The rules above hold for every input method; these pin
/// down how each one got there, so a Flutter upgrade that changes what one
/// input method does fails here. A new recording fails until its events
/// are checked by hand and added.
const recorded = <String, Map<String, List<String>>>{
  'macos-chrome.json': {
    'dokkaebi': ['txtName.Changed [갈]', 'txtName.Changed [갈가]'],
    // The space goes into the composition, so 닭 is never committed alone.
    'double_final': ['txtName.Changed [닭 ]', 'txtName.Changed [닭 값 ]'],
    'backspace': ['txtName.Changed [하]'],
    'click_composing': [
      'txtName.Changed [한]',
      'txtName.Changed [한글]',
      'btnOk.Click [한글]',
    ],
    'click_committed': [
      'txtName.Changed [한]',
      'txtName.Changed [한글]',
      'btnOk.Click [한글]',
      'txtName.Changed []',
      'txtName.Changed [한]',
      'txtName.Changed [한글]',
      'btnOk.Click [한글]',
    ],
  },
  'windows-chrome.json': {
    'dokkaebi': ['txtName.Changed [갈]', 'txtName.Changed [갈가]'],
    // Mixed in: a try at 닭값 without spaces, typed and erased before the
    // real one (no 다시 between them). Kept until the re-recording.
    'double_final': [
      'txtName.Changed [닭]',
      'txtName.Changed [닭값]',
      'txtName.Changed [닭]',
      'txtName.Changed []',
      'txtName.Changed [닭 ]',
      'txtName.Changed [닭 값 ]',
    ],
    'backspace': ['txtName.Changed [하]'],
    'click_composing': [
      'txtName.Changed [한]',
      'txtName.Changed [한글]',
      'btnOk.Click [한글]',
    ],
    // Mixed in: 한긂 typed and erased before 한글 in button A's try.
    // Kept until the re-recording.
    'click_committed': [
      'txtName.Changed [한]',
      'txtName.Changed []',
      'txtName.Changed [한]',
      'txtName.Changed [한글]',
      'btnOk.Click [한글]',
      'txtName.Changed []',
      'txtName.Changed [한]',
      'txtName.Changed [한글]',
      'btnOk.Click [한글]',
    ],
  },
};
