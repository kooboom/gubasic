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

  test('Korean messages use the same placeholders as English', () {
    for (final code in DiagnosticCode.values) {
      expect(_placeholders(koreanMessages[code]!),
          _placeholders(englishMessages[code]!),
          reason: code.code);
    }
  });

  test('Korean messages are used through the same lookup', () {
    final d = lex('Dim 점수').diagnostics.single;
    final ko = d.formatMessage(koreanMessages);
    expect(ko, contains('"점수"'));
    expect(ko, endsWith('한글은 문자열("...")이나 주석(\')에 써 주세요.'));
  });

  test('L006 suggests the Double spelling of the same number', () {
    final d = lex('x = 99999999999999999999').diagnostics.single;
    expect(d.message, endsWith('99999999999999999999.0'));
    expect(
        d.formatMessage(koreanMessages), contains('99999999999999999999.0처럼'));
  });
}
