import 'package:gubasic_lang/gubasic_lang.dart';

import 'i18n.dart';

/// One row of the Tokens tab.
class TokenRow {
  const TokenRow({
    required this.line,
    required this.column,
    required this.kind,
    required this.text,
    required this.value,
    this.tag,
    this.isComment = false,
    this.isError = false,
  });

  final int line;
  final int column;
  final String kind;
  final String text;
  final String value;
  final UiText? tag;
  final bool isComment;
  final bool isError;

  String get position => '$line:$column';
}

/// Rows for the Tokens tab: tokens and comments merged in source order.
List<TokenRow> tokenRows(LexResult result) {
  final rows = <TokenRow>[];
  var c = 0;
  for (final token in result.tokens) {
    while (c < result.comments.length &&
        result.comments[c].offset < token.offset) {
      rows.add(_row(result.comments[c++]));
    }
    rows.add(_row(token));
  }
  while (c < result.comments.length) {
    rows.add(_row(result.comments[c++]));
  }
  return rows;
}

TokenRow _row(Token t) => TokenRow(
      line: t.line,
      column: t.column,
      kind: t.kind == TokenKind.keyword ? 'keyword' : t.kind.name,
      text: displayText(t.text),
      value: _value(t),
      tag: switch (t.keyword?.support) {
        KeywordSupport.unsupported => UiText.tagUnsupported,
        KeywordSupport.plannedStage2 => UiText.tagStage2,
        _ => null,
      },
      isComment: t.kind == TokenKind.comment,
      isError: t.kind == TokenKind.error,
    );

String _value(Token t) => switch (t.kind) {
      TokenKind.keyword => t.keyword!.spelling,
      TokenKind.stringLiteral => '"${t.value}"',
      TokenKind.integerLiteral ||
      TokenKind.doubleLiteral =>
        '${t.value ?? '—'}',
      _ => '',
    };

/// Makes invisible characters visible: line breaks become `↵`, tabs `→`,
/// and the zero-length newline before end of file `∅`.
String displayText(String text) {
  if (text.isEmpty) return '∅';
  return text
      .replaceAll('\r\n', '↵')
      .replaceAll('\r', '↵')
      .replaceAll('\n', '↵')
      .replaceAll('\t', '→');
}

/// `line:col–line:col` for a source range, shown next to AST nodes.
String rangeText(LineMap lines, int start, int end) {
  final (sl, sc) = lines.locate(start);
  final (el, ec) = lines.locate(end);
  return '$sl:$sc–$el:$ec';
}

/// Diagnostics grouped by line, for the editor gutter.
Map<int, List<Diagnostic>> diagnosticsByLine(List<Diagnostic> diagnostics) {
  final map = <int, List<Diagnostic>>{};
  for (final d in diagnostics) {
    (map[d.line] ??= []).add(d);
  }
  return map;
}

/// Number of lines in [source], counting line breaks the way the lexer
/// does (`\r\n`, `\r` and `\n`). An empty source has one line.
int lineCount(String source) {
  var lines = 1;
  for (var i = 0; i < source.length; i++) {
    final c = source.codeUnitAt(i);
    if (c == 0x0A) {
      lines++;
    } else if (c == 0x0D) {
      lines++;
      if (i + 1 < source.length && source.codeUnitAt(i + 1) == 0x0A) i++;
    }
  }
  return lines;
}

/// The range to select when jumping to [d]: at least one character, so
/// the caret is visible even for a zero-length diagnostic.
(int, int) selectionFor(Diagnostic d, int sourceLength) {
  final start = d.offset.clamp(0, sourceLength);
  final end =
      (d.offset + (d.length == 0 ? 1 : d.length)).clamp(start, sourceLength);
  return (start, end);
}
