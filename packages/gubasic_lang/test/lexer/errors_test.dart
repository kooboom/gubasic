import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  test('L001: an unterminated string becomes one error token to line end', () {
    final r = lex('x = "abc\ny = 2');
    expect(codesOf(r), ['L001']);
    final d = r.diagnostics.single;
    expect([d.line, d.column, d.offset, d.length], [1, 5, 4, 4]);
    expect(r.tokens.map((t) => t.kind), [
      TokenKind.identifier,
      TokenKind.equal,
      TokenKind.error,
      TokenKind.newline,
      TokenKind.identifier,
      TokenKind.equal,
      TokenKind.integerLiteral,
      TokenKind.newline,
      TokenKind.eof,
    ]);
    expect(r.tokens[2].text, '"abc');
    expect(r.tokens[4].line, 2);
  });

  test('L001: an unterminated string at the end of the file', () {
    final r = lex('MsgBox("끝');
    expect(codesOf(r), ['L001']);
    expect(r.tokens[2].kind, TokenKind.error);
    expect(r.tokens[2].text, '"끝');
    expect(r.tokens.last.kind, TokenKind.eof);
  });

  test('L001: a doubled quote at line end does not close the string', () {
    final r = lex('x = "a""\ny');
    expect(codesOf(r), ['L001']);
    expect(r.tokens[2].text, '"a""');
  });

  test('L002: Korean in a name is one identifier with one diagnostic', () {
    final r = lex('Dim 점수 As Integer');
    expect(codesOf(r), ['L002']);
    expect(r.tokens.map((t) => t.kind).toList().sublist(0, 4), [
      TokenKind.keyword,
      TokenKind.identifier,
      TokenKind.keyword,
      TokenKind.identifier,
    ]);
    expect(r.tokens[1].text, '점수');
    final d = r.diagnostics.single;
    expect([d.line, d.column, d.offset, d.length], [1, 5, 4, 2]);
    expect(d.message, contains('English letters'));
    expect(d.message, contains('점수'));
  });

  test('L002: a mixed ASCII and Korean word', () {
    final r = lex('name이름 = 1');
    expect(codesOf(r), ['L002']);
    expect(r.tokens.first.text, 'name이름');
    expect(r.tokens.first.kind, TokenKind.identifier);
  });

  test('L002: other non-ASCII characters outside strings', () {
    final r = lex('x = 😀');
    expect(codesOf(r), ['L002']);
    expect(r.tokens[2].text, '😀');
    expect(r.diagnostics.single.length, 2, reason: 'surrogate pair');
  });

  test('L003: ":" ends the statement and is reported', () {
    final r = lex('x = 1 : y = 2');
    expect(codesOf(r), ['L003']);
    expect(r.tokens.map((t) => t.kind), [
      TokenKind.identifier,
      TokenKind.equal,
      TokenKind.integerLiteral,
      TokenKind.newline,
      TokenKind.identifier,
      TokenKind.equal,
      TokenKind.integerLiteral,
      TokenKind.newline,
      TokenKind.eof,
    ]);
    expect(r.tokens[3].text, ':');
    final d = r.diagnostics.single;
    expect([d.line, d.column, d.offset, d.length], [1, 7, 6, 1]);
    expect(d.message, contains('one statement per line'));
  });

  test('L003: ":" next to a line break does not double the newline', () {
    final r = lex('x = 1:\ny = 2');
    expect(codesOf(r), ['L003']);
    expect(r.tokens.where((t) => t.kind == TokenKind.newline).length, 2);
  });

  test('L004: unknown characters become error tokens', () {
    final r = lex(r'a @ b # c $ d ! e ? f ~ g');
    expect(codesOf(r), List.filled(6, 'L004'));
    expect(r.tokens.where((t) => t.kind == TokenKind.error).map((t) => t.text),
        ['@', '#', r'$', '!', '?', '~']);
    expect(r.diagnostics.first.message, contains('"@"'));
    expect(r.tokens.where((t) => t.kind == TokenKind.identifier).length, 7);
  });

  test('L004: control characters are shown by code point', () {
    final r = lex('a \u0001 b');
    expect(codesOf(r), ['L004']);
    expect(r.diagnostics.single.message, contains('U+0001'));
  });

  test('L005: _ that is not at the end of a line', () {
    final r = lex('x = 1 _ + 2');
    expect(codesOf(r), ['L005']);
    expect(r.tokens[3].kind, TokenKind.error);
    expect(r.tokens[3].text, '_');
    expect(textsOf('x = 1 _ + 2'), ['x', '=', '1', '_', '+', '2']);
  });

  test('L005: _ followed by a comment is not a continuation', () {
    final r = lex("x = 1 + _ ' more\n2");
    expect(codesOf(r), ['L005']);
    expect(r.tokens.where((t) => t.kind == TokenKind.newline).length, 2);
  });

  test('L005: an identifier cannot start with _', () {
    final r = lex('_count = 1');
    expect(codesOf(r), ['L005']);
    expect(r.tokens[1].text, 'count');
  });

  test('diagnostic messages are looked up by code', () {
    final d = lex('Dim 점수').diagnostics.single;
    final catalog = {DiagnosticCode.nonAsciiIdentifier: '식별자 "{0}"'};
    expect(d.formatMessage(catalog), '식별자 "점수"');
    expect(d.formatMessage(const {}), d.message, reason: 'falls back to en');
    for (final code in DiagnosticCode.values) {
      expect(englishMessages[code], isNotNull, reason: code.code);
    }
    expect(
        DiagnosticCode.values
            .map((c) => c.code)
            .where((c) => c.startsWith('L'))
            .toSet(),
        {
          'L001',
          'L002',
          'L003',
          'L004',
          'L005',
          'L006',
          'L008',
          'L009',
          'L010'
        });
  });

  test('several errors: lexing reaches the end and collects them all', () {
    const src = 'Dim 점수 As Integer\n'
        'Dim s = "unterminated\n'
        'x = 1 : y = 2\n'
        'z = 3 @ 4 _ + 5\n'
        'n = 99999999999999999999\n'
        'MsgBox("끝")\n';
    final r = lex(src);
    expect(codesOf(r), ['L002', 'L001', 'L003', 'L004', 'L005', 'L006']);
    expect(r.diagnostics.map((d) => d.line), [1, 2, 3, 4, 4, 5]);

    final last = r.tokens.reversed.take(6).toList().reversed;
    expect(last.map((t) => t.text), ['MsgBox', '(', '"끝"', ')', '\n', '']);
    expect(r.tokens.last.kind, TokenKind.eof);
    expect(r.tokens.firstWhere((t) => t.text == 'MsgBox').line, 6);
  });
}
