import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Lexes [source] and expects no diagnostics.
LexResult lexClean(String source) {
  final result = lex(source);
  expect(result.diagnostics, isEmpty, reason: 'source: $source');
  return result;
}

/// Token kinds of [source], without the trailing newline and eof.
List<TokenKind> kindsOf(String source) =>
    _trimEnd(lex(source).tokens).map((t) => t.kind).toList();

/// Token texts of [source], without the trailing newline and eof.
List<String> textsOf(String source) =>
    _trimEnd(lex(source).tokens).map((t) => t.text).toList();

List<Token> _trimEnd(List<Token> tokens) {
  var end = tokens.length - 1; // drop eof
  if (end > 0 && tokens[end - 1].kind == TokenKind.newline) end--;
  return tokens.sublist(0, end);
}

List<String> codesOf(LexResult r) =>
    r.diagnostics.map((d) => d.code.code).toList();
