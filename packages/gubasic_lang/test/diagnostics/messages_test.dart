import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

Set<String> _placeholders(String message) =>
    RegExp(r'\{\d+\}').allMatches(message).map((m) => m[0]!).toSet();

void main() {
  test('every diagnostic code has an English and a Korean message', () {
    for (final code in DiagnosticCode.values) {
      expect(englishMessages[code], isNotNull, reason: 'en ${code.code}');
      expect(koreanMessages[code], isNotNull, reason: 'ko ${code.code}');
    }
  });

  test('codes are unique and numbered without gaps per prefix', () {
    final all = DiagnosticCode.values.map((c) => c.code).toList();
    expect(all.toSet(), hasLength(all.length));
    for (final prefix in ['L', 'P']) {
      final numbers = all
          .where((c) => c.startsWith(prefix))
          .map((c) => int.parse(c.substring(1)))
          .toList();
      expect(numbers, List.generate(numbers.length, (i) => i + 1));
    }
  });

  test('Korean messages use the same placeholders as English', () {
    for (final code in DiagnosticCode.values) {
      expect(_placeholders(koreanMessages[code]!),
          _placeholders(englishMessages[code]!),
          reason: code.code);
    }
  });

  test('Korean messages never put a particle right after a placeholder', () {
    // "{0}가" would need 가/이 depending on the inserted word; particles go
    // on a fixed word instead ("{0} 키워드가"). Quotes or brackets right
    // after the placeholder do not help either.
    final bad = RegExp(r'\{\d+\}["\x27)\]]?[가-힣]');
    for (final code in DiagnosticCode.values) {
      final message = koreanMessages[code]!;
      final ok = message.replaceAll(RegExp(r'\{\d+\}번'), ''); // line numbers
      expect(bad.hasMatch(ok), isFalse, reason: '${code.code}: $message');
    }
  });

  test('Korean messages use the documents\' "~합니다" style', () {
    for (final code in DiagnosticCode.values) {
      final message = koreanMessages[code]!;
      // Ends with "…니다." or "…세요.", optionally before a "(…)" aside.
      expect(message, matches(RegExp(r'(니다|세요)(\([^)]*\))?\.$')),
          reason: '${code.code}: $message');
    }
  });

  test('Korean messages are used through the same lookup', () {
    final d = lex('Dim 점수').diagnostics.single;
    final ko = d.formatMessage(koreanMessages);
    expect(ko, contains('점수'));
    expect(ko, endsWith('한글은 문자열("...")이나 주석(\')에 써 주세요.'));
  });

  test('L006 suggests the Double spelling of the same number', () {
    final d = lex('x = 99999999999999999999').diagnostics.single;
    expect(d.message, contains('99999999999999999999.0'));
    expect(
        d.formatMessage(koreanMessages), contains('예: 99999999999999999999.0'));
  });

  test('P002 and P006 read naturally in Korean', () {
    final p002 = parse('Sub T()\nIf x\nEnd If\nEnd Sub').diagnostics.single;
    expect(p002.formatMessage(koreanMessages),
        startsWith('여기에는 Then 키워드가 필요합니다.'));
    final p006 = parse('Sub T()\nIf x Then\nEnd Sub').diagnostics.single;
    expect(p006.formatMessage(koreanMessages),
        '2번 줄에서 시작한 If 블록이 닫히지 않았습니다. End If 문장을 넣어 주세요.');
  });
}
