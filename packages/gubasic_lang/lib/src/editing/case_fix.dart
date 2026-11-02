import '../analyzer/compile.dart';
import '../lexer/keyword.dart';
import '../lexer/token.dart';

/// One word of the code written in another case than GuBASIC writes it
/// (docs/DESIGN.md D133): at [offset], [text] in place of what is there,
/// as long as it, so that nothing else moves.
typedef CaseFix = ({int offset, String text});

/// The words of [program]'s code between [start] and [end] (offsets) to
/// write as GuBASIC writes them (D133): a keyword as it is spelled, a
/// name as it is declared (a variable, a procedure, a control, a form, a
/// module, a Structure and its fields, and GuBASIC's own types, functions,
/// objects, members and events). Strings and comments are not words; a
/// name that is not declared, and a declaration itself, stay as written.
List<CaseFix> caseFixes(CompileResult program, int start, int end) {
  final analysis = program.analysis;
  final spelled = <int, String>{
    for (final MapEntry(:key, :value) in analysis.symbols.entries)
      key.start: value.name,
    for (final MapEntry(:key, :value) in analysis.members.entries)
      key.name.start: value.name,
    for (final MapEntry(:key, :value) in analysis.spellings.entries)
      key.start: value,
  };
  final tokens = program.parseResult.lexResult.tokens;
  final fixes = <CaseFix>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.offset < start) continue;
    if (t.end > end) break;
    final String? wanted = switch (t.kind) {
      TokenKind.keyword => t.keyword!.spelling,
      TokenKind.identifier => contextualKeyword(tokens, i) ?? spelled[t.offset],
      _ => null,
    };
    if (wanted != null &&
        wanted != t.text &&
        wanted.toLowerCase() == t.text.toLowerCase()) {
      fixes.add((offset: t.offset, text: wanted));
    }
  }
  return fixes;
}

/// How the name at [i] is written where it is a word of the language,
/// or null where it is a name (D132, D134): `Structure` and `Type`
/// opening or closing a Structure, `With` before a With list's brace, and
/// `With` opening or closing a With block, which are names to the lexer.
/// The IDE colours them as keywords by the same rule.
String? contextualKeyword(List<Token> tokens, int i) {
  final word = tokens[i].text.toLowerCase();
  if (word != 'with' && word != 'structure' && word != 'type') return null;
  final spelling = switch (word) {
    'with' => 'With',
    'type' => 'Type',
    _ => 'Structure',
  };
  final next = i + 1 < tokens.length ? tokens[i + 1] : null;
  final before = i == 0 ? null : tokens[i - 1];
  if (before?.keyword == Keyword.kwEnd) return spelling;
  final lineStart = before == null || before.kind == TokenKind.newline;
  if (word == 'with') {
    if (next?.kind == TokenKind.leftBrace) return spelling;
    return lineStart && _withBlockAt(tokens, i) ? spelling : null;
  }
  final modified = (before?.keyword == Keyword.kwPublic ||
          before?.keyword == Keyword.kwPrivate) &&
      (i < 2 || tokens[i - 2].kind == TokenKind.newline);
  final named = next?.kind == TokenKind.identifier &&
      i + 2 < tokens.length &&
      (tokens[i + 2].kind == TokenKind.newline ||
          tokens[i + 2].kind == TokenKind.eof);
  return (lineStart || modified) && named ? spelling : null;
}

/// Whether `With` at [i], at the start of a line, opens a With block
/// (D134): not when a `(` or `.` follows it at once, nor when the line has
/// a `=` outside brackets (`with = 1`), as the parser decides.
bool _withBlockAt(List<Token> tokens, int i) {
  final t = tokens[i];
  final next = i + 1 < tokens.length ? tokens[i + 1] : null;
  if (next != null &&
      next.offset == t.end &&
      (next.kind == TokenKind.leftParen || next.kind == TokenKind.dot)) {
    return false;
  }
  var depth = 0;
  for (var k = i + 1; k < tokens.length; k++) {
    final kind = tokens[k].kind;
    if (kind == TokenKind.newline || kind == TokenKind.eof) break;
    if (kind == TokenKind.leftParen || kind == TokenKind.leftBrace) depth++;
    if (kind == TokenKind.rightParen || kind == TokenKind.rightBrace) depth--;
    if (kind == TokenKind.equal && depth == 0) return false;
  }
  return true;
}

/// [source] with [fixes] made.
String withCaseFixes(String source, List<CaseFix> fixes) {
  final b = StringBuffer();
  var at = 0;
  for (final f in fixes) {
    b
      ..write(source.substring(at, f.offset))
      ..write(f.text);
    at = f.offset + f.text.length;
  }
  b.write(source.substring(at));
  return '$b';
}
