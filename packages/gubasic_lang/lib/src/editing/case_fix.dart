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
      TokenKind.identifier => _contextual(tokens, i) ?? spelled[t.offset],
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

/// The word of a Structure (`Structure Student`, `End Structure`, and
/// Visual Basic 6's `Type`) or of a With list (`New Student With {`),
/// which are names to the lexer and words where they stand.
String? _contextual(List<Token> tokens, int i) {
  final word = tokens[i].text.toLowerCase();
  final next = i + 1 < tokens.length ? tokens[i + 1] : null;
  if (word == 'with') {
    return next?.kind == TokenKind.leftBrace ? 'With' : null;
  }
  if (word != 'structure' && word != 'type') return null;
  final spelling = word == 'type' ? 'Type' : 'Structure';
  final before = i == 0 ? null : tokens[i - 1];
  if (before?.keyword == Keyword.kwEnd) return spelling;
  final lineStart = before == null ||
      before.kind == TokenKind.newline ||
      ((before.keyword == Keyword.kwPublic ||
              before.keyword == Keyword.kwPrivate) &&
          (i < 2 || tokens[i - 2].kind == TokenKind.newline));
  final named = next?.kind == TokenKind.identifier &&
      i + 2 < tokens.length &&
      (tokens[i + 2].kind == TokenKind.newline ||
          tokens[i + 2].kind == TokenKind.eof);
  return lineStart && named ? spelling : null;
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
