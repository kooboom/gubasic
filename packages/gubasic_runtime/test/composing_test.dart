import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

void main() {
  TextEditingValue at(String text, [int? caret]) => TextEditingValue(
    text: text,
    selection: TextSelection.collapsed(offset: caret ?? text.length),
  );

  /// The committed text after each value, typed in order.
  List<String> committed(ComposingTracker t, List<TextEditingValue> values) => [
    for (final v in values) committedText(t.track(v)),
  ];

  group('on the macOS desktop', () {
    setUp(() => debugDefaultTargetPlatformOverride = TargetPlatform.macOS);
    tearDown(() => debugDefaultTargetPlatformOverride = null);

    test('a syllable is composed until the next one starts', () {
      final t = ComposingTracker();
      expect(
        committed(t, [at('ㄱ'), at('가'), at('갈'), at('갉'), at('갈'), at('갈가')]),
        ['', '', '', '', '', '갈'],
      );
      expect(t.composing, isTrue);
      t.commit();
      expect(committedText(t.value), '갈가', reason: 'Enter, a click');
    });

    test('a key that is not Hangul commits', () {
      final t = ComposingTracker();
      expect(committed(t, [at('닭'), at('닭 ')]), ['', '닭 ']);
      expect(t.composing, isFalse);
    });

    test('erasing the jamo being composed, then a committed syllable', () {
      final t = ComposingTracker(at('한'));
      expect(committed(t, [at('한ㄱ'), at('한그'), at('한ㄱ'), at('한'), at('')]), [
        '한',
        '한',
        '한',
        '한',
        '',
      ]);
    });

    test('moving the caret commits', () {
      final t = ComposingTracker();
      committed(t, [at('ㄱ'), at('가')]);
      expect(committedText(t.track(at('가', 0))), '가');
    });

    test('a range the platform sends is trusted from then on', () {
      final t = ComposingTracker();
      final v = t.track(
        const TextEditingValue(
          text: '가',
          selection: TextSelection.collapsed(offset: 1),
          composing: TextRange(start: 0, end: 1),
        ),
      );
      expect(v.composing, const TextRange(start: 0, end: 1));
      expect(committedText(t.track(at('가나'))), '가나', reason: 'no guess');
    });
  });

  test('elsewhere, nothing is guessed', () {
    final t = ComposingTracker();
    expect(committed(t, [at('ㄱ'), at('가')]), ['ㄱ', '가']);
  });
}
