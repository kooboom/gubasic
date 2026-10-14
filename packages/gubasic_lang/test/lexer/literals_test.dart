import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('numbers', () {
    test('integers', () {
      final t = lexClean('0 123 9007199254740991').tokens;
      expect(
          t.take(3).map((t) => t.kind), everyElement(TokenKind.integerLiteral));
      expect(t.take(3).map((t) => t.value), [0, 123, 9007199254740991]);
    });

    test('the largest Integer is accepted, with only the web warning', () {
      final r = lex('9223372036854775807');
      expect(codesOf(r), ['L007']);
      expect(r.tokens.first.kind, TokenKind.integerLiteral);
      expect(r.tokens.first.text, '9223372036854775807');
    });

    test('reals', () {
      final t = lexClean('1.5 0.25 10.0').tokens;
      expect(
          t.take(3).map((t) => t.kind), everyElement(TokenKind.doubleLiteral));
      expect(t.take(3).map((t) => t.value), [1.5, 0.25, 10.0]);
      expect(t.take(3).map((t) => t.text), ['1.5', '0.25', '10.0']);
    });

    test('.5 is a dot followed by an integer', () {
      expect(kindsOf('.5'), [TokenKind.dot, TokenKind.integerLiteral]);
    });

    test('1. is an integer followed by a dot', () {
      expect(kindsOf('1.'), [TokenKind.integerLiteral, TokenKind.dot]);
    });

    test('exponent notation is not a number', () {
      expect(kindsOf('1e5'), [TokenKind.integerLiteral, TokenKind.identifier]);
      expect(textsOf('1e5'), ['1', 'e5']);
    });

    test('a minus sign is a separate token', () {
      expect(kindsOf('-3'), [TokenKind.minus, TokenKind.integerLiteral]);
    });

    test('L006: an integer too large for 64 bits', () {
      final r = lex('x = 9223372036854775808');
      expect(codesOf(r), ['L006']);
      final number = r.tokens[2];
      expect(number.kind, TokenKind.integerLiteral);
      expect(number.value, isNull);
      expect(r.diagnostics.single.offset, 4);
      expect(r.diagnostics.single.length, 19);
      expect(r.diagnostics.single.message, contains('9223372036854775808'));
    });
    test('L006 is decided on the digits, the same on every platform', () {
      // The web has no 64-bit int, so int.tryParse there never fails.
      expect(codesOf(lex('9223372036854775807')), ['L007']);
      expect(codesOf(lex('00009223372036854775807')), ['L007']);
      expect(lex('000').tokens.first.value, 0);
      expect(codesOf(lex('9223372036854775808')), ['L006']);
      expect(codesOf(lex('10000000000000000000')), ['L006']);
      expect(codesOf(lex('99999999999999999999999999')), ['L006']);
    });
  });

  group('L007: integers the web cannot store exactly (warning)', () {
    test('boundaries: above 2^53 - 1 and up to 2^63 - 1', () {
      expect(codesOf(lex('9007199254740991')), isEmpty, reason: '2^53 - 1');
      expect(codesOf(lex('9007199254740992')), ['L007'], reason: '2^53');
      expect(codesOf(lex('9223372036854775807')), ['L007'], reason: '2^63 - 1');
      expect(codesOf(lex('9223372036854775808')), ['L006'],
          reason: 'too large: the error only, no warning on top');
    });

    test('leading zeros do not matter', () {
      expect(codesOf(lex('0009007199254740991')), isEmpty);
      expect(codesOf(lex('0009007199254740992')), ['L007']);
    });

    test('reals are approximate anyway and get no warning', () {
      expect(codesOf(lex('9007199254740993.0')), isEmpty);
    });

    test('it is a warning: the token keeps its exact text and a value', () {
      final r = lex('id = 1234567890123456789');
      final d = r.diagnostics.single;
      expect(d.code, DiagnosticCode.integerInexactOnWeb);
      expect(d.severity, DiagnosticSeverity.warning);
      expect(d.isWarning, isTrue);
      expect([d.line, d.column, d.offset, d.length], [1, 6, 5, 19]);
      expect(r.tokens[2].text, '1234567890123456789');
      expect(r.tokens[2].value, isNotNull);
      expect(r.hasErrors, isFalse, reason: 'warnings alone are not errors');
    });
  });

  group('strings', () {
    test('a simple string', () {
      final t = lexClean('"Hello"').tokens.first;
      expect(t.kind, TokenKind.stringLiteral);
      expect(t.text, '"Hello"');
      expect(t.value, 'Hello');
    });

    test('empty string', () {
      expect(lexClean('""').tokens.first.value, '');
    });

    test('a doubled quote is one quote character', () {
      final t = lexClean('"say ""hi"""').tokens.first;
      expect(t.text, '"say ""hi"""');
      expect(t.value, 'say "hi"');
      expect(lexClean('""""').tokens.first.value, '"');
    });

    test('Korean text is allowed inside strings', () {
      final r = lexClean('MsgBox("안녕하세요, 세계! 😀")');
      expect(r.tokens[2].value, '안녕하세요, 세계! 😀');
    });

    test('comment marks inside a string are just text', () {
      final r = lexClean('"it\'s REM time"');
      expect(r.tokens.first.value, "it's REM time");
      expect(r.comments, isEmpty);
    });
  });
}
