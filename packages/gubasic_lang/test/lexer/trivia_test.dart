import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

void main() {
  group('comments', () {
    test("' runs to the end of the line and is kept apart", () {
      final r = lexClean("x = 1 ' set x\ny = 2");
      expect(r.tokens.map((t) => t.text),
          ['x', '=', '1', '\n', 'y', '=', '2', '', '']);
      expect(r.comments.single.kind, TokenKind.comment);
      expect(r.comments.single.text, "' set x");
      expect(r.comments.single.column, 7);
    });

    test('REM starts a comment in any case', () {
      for (final rem in ['REM', 'rem', 'Rem']) {
        final r = lexClean('$rem this is a note\nx');
        expect(r.comments.single.text, '$rem this is a note');
        expect(r.tokens.map((t) => t.text), ['x', '', '']);
      }
    });

    test('REM after a statement is a comment too', () {
      final r = lexClean('x = 1 REM note');
      expect(r.comments.single.text, 'REM note');
      expect(textsOf('x = 1 REM note'), ['x', '=', '1']);
    });

    test('REM only counts as a whole word', () {
      expect(kindsOf('Remark = Rem2'), [
        TokenKind.identifier,
        TokenKind.equal,
        TokenKind.identifier,
      ]);
      expect(lex('Remark = Rem2').comments, isEmpty);
    });

    test('Korean text is allowed in comments', () {
      final r = lexClean("' 점수를 계산합니다\nREM 한글 주석");
      expect(r.comments.map((c) => c.text), ["' 점수를 계산합니다", 'REM 한글 주석']);
    });
  });

  group('newlines', () {
    test('a line break ends a statement', () {
      expect(kindsOf('a\nb'), [
        TokenKind.identifier,
        TokenKind.newline,
        TokenKind.identifier,
      ]);
    });

    test('blank and comment-only lines collapse into one newline', () {
      const src = "a\n\n   \n' note\n\r\n\tb";
      final r = lexClean(src);
      expect(r.tokens.map((t) => t.kind), [
        TokenKind.identifier,
        TokenKind.newline,
        TokenKind.identifier,
        TokenKind.newline,
        TokenKind.eof,
      ]);
      expect(r.tokens[2].line, 6);
    });

    test('no newline token at the start of the file', () {
      final r = lexClean("\n\n' header\n\nx");
      expect(r.tokens.first.text, 'x');
      expect(r.tokens.first.line, 5);
    });

    test('a newline is added before eof when the file does not end with one',
        () {
      final r = lexClean('x');
      expect(r.tokens.map((t) => t.kind),
          [TokenKind.identifier, TokenKind.newline, TokenKind.eof]);
      expect(r.tokens[1].length, 0);
      expect(r.tokens[1].offset, 1);
    });

    test('a file ending with a newline gets exactly one', () {
      final r = lexClean('x\n\n\n');
      expect(r.tokens.map((t) => t.kind),
          [TokenKind.identifier, TokenKind.newline, TokenKind.eof]);
      expect(r.tokens[1].text, '\n');
    });
  });

  group('line continuation', () {
    test('_ at the end of a line joins the next line', () {
      final r = lexClean('MsgBox("a" & _\n       "b")');
      expect(r.tokens.where((t) => t.kind == TokenKind.newline).length, 1);
      expect(r.tokens.map((t) => t.text).toList().sublist(0, 6),
          ['MsgBox', '(', '"a"', '&', '"b"', ')']);
      expect(r.tokens[4].line, 2);
      expect(r.tokens[4].column, 8);
    });

    test('_ may be followed by spaces, tabs and CRLF', () {
      final r = lexClean('x = 1 + _  \t\r\n2');
      expect(textsOf('x = 1 + _  \t\r\n2'), ['x', '=', '1', '+', '2']);
      expect(r.tokens[4].line, 2);
    });

    test('_ at the very end of the file', () {
      expect(textsOf('x _'), ['x']);
    });

    test('_ joined to a name is part of the identifier', () {
      final r = lexClean('x_\ny');
      expect(r.tokens.map((t) => t.text), ['x_', '\n', 'y', '', '']);
    });
  });
}
