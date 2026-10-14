import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_playground/src/model/i18n.dart';
import 'package:gubasic_playground/src/model/result_tab.dart';
import 'package:gubasic_playground/src/model/snapshot.dart';
import 'package:gubasic_playground/src/model/view_model.dart';
import 'package:test/test.dart';

void main() {
  group('tokenRows', () {
    test('comments are merged in source order', () {
      final rows = tokenRows(lex("' head\nx = 1 ' tail\nREM end\ny"));
      expect(rows.map((r) => r.kind), [
        'comment',
        'identifier',
        'equal',
        'integerLiteral',
        'comment',
        'newline',
        'comment',
        'identifier',
        'newline',
        'eof',
      ]);
      expect(rows.where((r) => r.isComment).map((r) => r.position),
          ['1:1', '2:7', '3:1']);
    });

    test('invisible characters are shown', () {
      expect(displayText('\r\n'), '↵');
      expect(displayText('\n'), '↵');
      expect(displayText('\r'), '↵');
      expect(displayText(''), '∅');
      expect(displayText('a\tb'), 'a→b');
      final rows = tokenRows(lex('x\n'));
      expect(rows.map((r) => r.text), ['x', '↵', '∅']);
    });

    test('values and keyword spellings', () {
      final rows =
          tokenRows(lex('dim s = "a""b" + 1.5 + 99999999999999999999'));
      expect(rows[0].kind, 'keyword');
      expect(rows[0].text, 'dim');
      expect(rows[0].value, 'Dim');
      expect(rows[3].value, '"a"b"');
      expect(rows[5].value, '1.5');
      expect(rows[7].value, '—');
    });

    test('unsupported and stage-2 keywords are tagged', () {
      final rows = tokenRows(lex('GoTo ByRef ByVal'));
      expect(rows.take(3).map((r) => r.tag),
          [UiText.tagUnsupported, UiText.tagStage2, null]);
    });

    test('error tokens are flagged', () {
      final rows = tokenRows(lex('a @ b'));
      expect(rows.map((r) => r.isError), [false, true, false, false, false]);
    });
  });

  test('rangeText shows line:col–line:col', () {
    final lines = LineMap('ab\ncd');
    expect(rangeText(lines, 0, 2), '1:1–1:3');
    expect(rangeText(lines, 3, 5), '2:1–2:3');
  });

  group('diagnostics in the gutter', () {
    test('grouped by line, several on one line', () {
      final r = lex('ok\nx = 1 @ 2 # 3\n\ny = "open');
      final byLine = diagnosticsByLine(r.diagnostics);
      expect(byLine.keys, [2, 4]);
      expect(byLine[2]!.map((d) => d.code.code), ['L004', 'L004']);
      expect(byLine[4]!.single.code.code, 'L001');
    });

    test('lineCount counts line breaks like the lexer', () {
      expect(lineCount(''), 1);
      expect(lineCount('a'), 1);
      expect(lineCount('a\n'), 2);
      expect(lineCount('a\r\nb\rc\nd'), 4);
      const src = 'a\r\n\r\nb\r\rc';
      final lastToken = lex(src).tokens.firstWhere((t) => t.text == 'c');
      expect(lineCount(src), lastToken.line);
    });

    test('selection covers the diagnostic, at least one character', () {
      final d = lex('x = "open').diagnostics.single;
      expect(selectionFor(d, 9), (4, 9));
      const zero = Diagnostic(
          code: DiagnosticCode.unexpectedCharacter,
          line: 1,
          column: 1,
          offset: 2,
          length: 0);
      expect(selectionFor(zero, 10), (2, 3));
      expect(selectionFor(zero, 2), (2, 2), reason: 'clamped to the source');
    });
  });

  group('result tabs', () {
    test('Tokens, AST, then Diagnostics, with unique ids', () {
      expect(resultTabs.map((t) => t.id), ['tokens', 'ast', 'diagnostics']);
      expect(resultTabs.map((t) => t.title),
          [UiText.tabTokens, UiText.tabAst, UiText.tabDiagnostics]);
    });

    test('only Diagnostics has a badge, counting lexer and parser problems',
        () {
      final s = Snapshot('Sub A()\nx = 1 @ 2\nIf y Then\nEnd Sub');
      expect(const TokensTab().badge(s), isNull);
      expect(const AstTab().badge(s), isNull);
      expect(s.diagnostics.map((d) => d.code.code), ['L004', 'P006']);
      expect(const DiagnosticsTab().badge(s), 2);
      expect(const DiagnosticsTab().badge(Snapshot('Sub A()\nEnd Sub')), 0);
    });

    test('the snapshot exposes the parsed tree', () {
      final s = Snapshot('Sub A()\nEnd Sub');
      expect(s.unit.members.single.label, 'Sub A');
    });
  });
}
