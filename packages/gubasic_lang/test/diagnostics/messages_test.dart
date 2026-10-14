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
    // integerTooLargeMinValue is a second message for L006 on purpose.
    final all = DiagnosticCode.values
        .where((c) => c != DiagnosticCode.integerTooLargeMinValue)
        .map((c) => c.code)
        .toList();
    expect(all.toSet(), hasLength(all.length));
    for (final prefix in ['L', 'P', 'A', 'R']) {
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
        d.formatMessage(koreanMessages), contains('(99999999999999999999.0)'));
  });

  test('P002 and P006 read naturally in Korean', () {
    final p002 = parse('Sub T()\nIf x\nEnd If\nEnd Sub').diagnostics.single;
    expect(p002.formatMessage(koreanMessages),
        startsWith('여기에는 Then 키워드가 필요합니다.'));
    final p006 = parse('Sub T()\nIf x Then\nEnd Sub').diagnostics.single;
    expect(p006.formatMessage(koreanMessages),
        '2번 줄에서 시작한 If 블록이 닫히지 않았습니다. End If 문장을 넣어 주세요.');
  });

  test('particles after fixed English words follow how the word is read', () {
    // true: the Korean reading ends in a final consonant (받침);
    // 'ㄹ' marks words ending in ㄹ, which take 로 like vowel endings.
    const endsWithConsonant = <String, Object>{
      'GuBASIC': true,
      'Sub': true,
      'Function': true,
      'Return': true,
      'Dim': true,
      'Static': true,
      'Public': true,
      'Private': true,
      'Call': 'ㄹ',
      'Double': 'ㄹ',
      'While': 'ㄹ',
      'Integer': false,
      'Error': false,
      'Try': false,
      'Object': false,
      'Loop': false,
      'Const': false,
      'Next': false,
      'ByRef': false,
      'Handles': false,
      'And': false,
      'Or': false,
      'Exit': false,
      'For': false,
      'Do': false,
      'Variant': false,
      'Catch': false,
    };
    // particle → whether it belongs after a consonant (true) or a vowel.
    const particles = {
      '은': true,
      '는': false,
      '이': true,
      '가': false,
      '을': true,
      '를': false,
      '과': true,
      '와': false,
      '이나': true,
      '나': false,
      '으로': true,
      '로': false,
    };
    // Longest particles first so that 이나 is not read as 이.
    final particleNames = particles.keys.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    final words = endsWithConsonant.keys.join('|');
    final wordAndParticle =
        RegExp('\\b($words)(${particleNames.join('|')})(?![가-힣])');
    for (final code in DiagnosticCode.values) {
      final message = koreanMessages[code]!;
      for (final m in wordAndParticle.allMatches(message)) {
        final word = m[1]!;
        final particle = m[2]!;
        final ending = endsWithConsonant[word]!;
        final bool expectConsonant;
        if (ending == 'ㄹ') {
          // ㄹ takes 로, otherwise behaves like a consonant.
          expectConsonant = particle != '로' && particle != '으로';
          if (particle == '으로') fail('${code.code}: $word$particle → $word로');
          if (particle == '로') continue;
        } else {
          expectConsonant = ending as bool;
        }
        expect(particles[particle], expectConsonant,
            reason: '${code.code}: "$word$particle" in $message');
      }
    }
  });

  test('P008 and P009 list the same declarations allowed outside procedures',
      () {
    for (final catalog in [englishMessages, koreanMessages]) {
      final p008 = catalog[DiagnosticCode.statementOutsideProcedure]!;
      final p009 = catalog[DiagnosticCode.declarationNotAllowedHere]!;
      for (final word in ['Dim', 'Private', 'Public', 'Const']) {
        expect(p008, contains(word));
        expect(p009, contains(word));
      }
    }
  });

  test('no message mentions development stages', () {
    for (final catalog in [englishMessages, koreanMessages]) {
      for (final message in catalog.values) {
        expect(message.toLowerCase(), isNot(contains('stage')));
        expect(message, isNot(contains('단계')));
      }
    }
  });

  test('L006 warns that a Double may change the last digits', () {
    final d = lex('x = 99999999999999999999').diagnostics.single;
    expect(d.message, contains('last digits may change'));
    expect(d.formatMessage(koreanMessages), contains('끝자리가 달라질 수 있습니다'));
  });
}
