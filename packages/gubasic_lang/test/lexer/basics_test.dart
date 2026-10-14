import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('empty source gives only eof', () {
    final r = lexClean('');
    expect(r.tokens.map((t) => t.kind), [TokenKind.eof]);
  });

  test('every operator and punctuation mark', () {
    const cases = {
      '+': TokenKind.plus,
      '-': TokenKind.minus,
      '*': TokenKind.star,
      '/': TokenKind.slash,
      r'\': TokenKind.backslash,
      '^': TokenKind.caret,
      '&': TokenKind.ampersand,
      '=': TokenKind.equal,
      '<>': TokenKind.notEqual,
      '<': TokenKind.less,
      '>': TokenKind.greater,
      '<=': TokenKind.lessEqual,
      '>=': TokenKind.greaterEqual,
      '(': TokenKind.leftParen,
      ')': TokenKind.rightParen,
      ',': TokenKind.comma,
      '.': TokenKind.dot,
    };
    cases.forEach((text, kind) {
      lexClean(text);
      expect(kindsOf(text), [kind], reason: text);
      expect(textsOf(text), [text], reason: text);
    });
  });

  test('two-character operators are not split, spaced ones are', () {
    expect(kindsOf('a<=b>=c<>d'), [
      TokenKind.identifier,
      TokenKind.lessEqual,
      TokenKind.identifier,
      TokenKind.greaterEqual,
      TokenKind.identifier,
      TokenKind.notEqual,
      TokenKind.identifier,
    ]);
    expect(kindsOf('< >'), [TokenKind.less, TokenKind.greater]);
    expect(kindsOf('=<'), [TokenKind.equal, TokenKind.less]);
  });

  test('tokens record line, column, offset and length', () {
    final r = lexClean('Dim x\n  y = 10');
    final t = r.tokens;
    expect(t[0], _at('Dim', line: 1, column: 1, offset: 0));
    expect(t[1], _at('x', line: 1, column: 5, offset: 4));
    expect(t[2].kind, TokenKind.newline);
    expect(t[2], _at('\n', line: 1, column: 6, offset: 5));
    expect(t[3], _at('y', line: 2, column: 3, offset: 8));
    expect(t[4], _at('=', line: 2, column: 5, offset: 10));
    expect(t[5], _at('10', line: 2, column: 7, offset: 12));
    expect(t[5].length, 2);
  });

  test('a tab counts as one column', () {
    final r = lexClean('\tx\t= 1');
    expect(r.tokens[0], _at('x', line: 1, column: 2, offset: 1));
    expect(r.tokens[1], _at('=', line: 1, column: 4, offset: 3));
  });

  test('CRLF and CR line endings', () {
    final r = lexClean('a\r\nb\rc');
    final t = r.tokens;
    expect(t.map((t) => t.text), ['a', '\r\n', 'b', '\r', 'c', '', '']);
    expect(t[2], _at('b', line: 2, column: 1, offset: 3));
    expect(t[4], _at('c', line: 3, column: 1, offset: 5));
  });

  test('a leading byte order mark is skipped', () {
    final r = lexClean('﻿Dim x');
    expect(r.tokens.first, _at('Dim', line: 1, column: 1, offset: 1));
  });

  test('token text always matches the source slice', () {
    const src = 'Sub A()\r\n  b = "x""y" \' note\nEnd Sub';
    for (final t in lex(src).tokens) {
      expect(src.substring(t.offset, t.end), t.text);
    }
  });
}

Matcher _at(String text,
        {required int line, required int column, required int offset}) =>
    isA<Token>()
        .having((t) => t.text, 'text', text)
        .having((t) => t.line, 'line', line)
        .having((t) => t.column, 'column', column)
        .having((t) => t.offset, 'offset', offset)
        .having((t) => t.length, 'length', text.length);
