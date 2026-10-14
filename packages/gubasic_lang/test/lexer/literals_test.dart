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

    test('the largest Integer is accepted without any diagnostic', () {
      final r = lex('9223372036854775807');
      expect(codesOf(r), isEmpty);
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

    test('exponent notation makes a Double', () {
      for (final (text, value) in [
        ('1E+21', 1e21),
        ('1.5E-7', 1.5e-7),
        ('2e10', 2e10),
        ('3E5', 3e5),
        ('9.3E+18', 9.3e18),
        ('1.7976931348623157E+308', 1.7976931348623157e308),
        ('5E-324', 5e-324),
      ]) {
        final t = lexClean(text).tokens.first;
        expect(t.kind, TokenKind.doubleLiteral, reason: text);
        expect(t.value, value, reason: text);
        expect(t.text, text);
      }
    });

    test('without digits after E it is not an exponent', () {
      expect(textsOf('2e'), ['2', 'e']);
      expect(textsOf('2E+'), ['2', 'E', '+']);
      expect(textsOf('2Ex'), ['2', 'Ex']);
      // A dot first is still not part of the number: `.` then 5E3.
      expect(kindsOf('.5E3'), [TokenKind.dot, TokenKind.doubleLiteral]);
    });

    test('L008: beyond the Double range', () {
      final r = lex('x = 1E400');
      expect(codesOf(r), ['L008']);
      expect(r.diagnostics.single.message, contains('1E400'));
      expect(r.tokens[2].kind, TokenKind.doubleLiteral);
      expect(codesOf(lex('1${'0' * 400}.0')), ['L008']);
    });

    test('too small for a Double becomes 0 (no diagnostic)', () {
      final r = lexClean('1E-400');
      expect(r.tokens.first.value, 0.0);
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
      expect(codesOf(lex('9223372036854775807')), isEmpty);
      expect(codesOf(lex('00009223372036854775807')), isEmpty);
      expect(lex('000').tokens.first.value, 0);
      expect(codesOf(lex('9223372036854775808')), ['L006']);
      expect(codesOf(lex('10000000000000000000')), ['L006']);
      expect(codesOf(lex('99999999999999999999999999')), ['L006']);
    });
  });

  test('L006 for exactly 2^63 points to Integer.MinValue', () {
    final d = lex('x = 9223372036854775808').diagnostics.single;
    expect(d.code.code, 'L006');
    expect(d.code, DiagnosticCode.integerTooLargeMinValue);
    expect(d.message, contains('Integer.MinValue'));
    expect(d.formatMessage(koreanMessages), contains('Integer.MinValue를 쓰세요'));
    expect(lex('x = 9223372036854775809').diagnostics.single.code,
        DiagnosticCode.integerTooLarge);
    expect(lex('x = 0009223372036854775808').diagnostics.single.code,
        DiagnosticCode.integerTooLargeMinValue);
  });

  group('large integers (L007 is retired: Integer is exact everywhere, D26)',
      () {
    test('no diagnostic from 2^53 up to 2^63 - 1', () {
      for (final n in [
        '9007199254740991',
        '9007199254740992',
        '1234567890123456789',
        '0009007199254740993',
        '9223372036854775807',
      ]) {
        expect(codesOf(lex(n)), isEmpty, reason: n);
      }
      expect(codesOf(lex('9223372036854775808')), ['L006']);
    });

    test('the token keeps its exact text', () {
      expect(
          lex('1234567890123456789').tokens.first.text, '1234567890123456789');
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
