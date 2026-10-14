import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('numbers', () {
    test('integers', () {
      final t = lexClean('0 123 9223372036854775807').tokens;
      expect(
          t.take(3).map((t) => t.kind), everyElement(TokenKind.integerLiteral));
      expect(t.take(3).map((t) => t.value), [0, 123, 9223372036854775807]);
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
