import 'keyword.dart';

enum TokenKind {
  identifier,
  keyword,
  integerLiteral,
  doubleLiteral,
  stringLiteral,

  // Operators
  plus, // +
  minus, // -
  star, // *
  slash, // /
  backslash, // \
  caret, // ^
  ampersand, // &
  equal, // =
  notEqual, // <>
  less, // <
  greater, // >
  lessEqual, // <=
  greaterEqual, // >=

  // Punctuation
  leftParen, // (
  rightParen, // )
  comma, // ,
  dot, // .

  /// End of a statement: a line break, or a `:` (reported as L003).
  newline,

  /// `'` or `REM` comment. Only appears in [LexResult.comments].
  comment,

  /// Text the lexer could not make sense of. A diagnostic explains why.
  error,

  eof,
}

/// One token of GuBASIC source.
///
/// [line] and [column] are 1-based. [offset] and [length] are in UTF-16
/// code units (Dart string indices), so
/// `source.substring(offset, offset + length) == text` always holds.
/// A tab counts as one column.
class Token {
  const Token({
    required this.kind,
    required this.text,
    required this.line,
    required this.column,
    required this.offset,
    this.keyword,
    this.value,
  });

  final TokenKind kind;

  /// The source text exactly as written (original spelling preserved).
  final String text;

  final int line;
  final int column;
  final int offset;
  int get length => text.length;
  int get end => offset + length;

  /// The keyword, when [kind] is [TokenKind.keyword].
  final Keyword? keyword;

  /// The decoded value of a literal: [int] for [TokenKind.integerLiteral]
  /// (null if it does not fit in 64 bits), [double] for
  /// [TokenKind.doubleLiteral], and [String] with `""` turned into `"` for
  /// [TokenKind.stringLiteral].
  final Object? value;

  bool isKeyword(Keyword k) => keyword == k;

  @override
  String toString() {
    final shown = kind == TokenKind.keyword ? keyword!.spelling : kind.name;
    return '$shown ${_quote(text)} @$line:$column';
  }

  static String _quote(String s) =>
      "'${s.replaceAll('\r', r'\r').replaceAll('\n', r'\n')}'";
}
