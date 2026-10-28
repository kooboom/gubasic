import 'package:gubasic_lang/gubasic_lang.dart';

/// A `Sub` or `Function` in the code: its name, where its first line
/// starts, where its body starts (the line after the first), and where its
/// `End Sub` / `End Function` line starts (or the end of the code, when it
/// has none yet).
class Procedure {
  const Procedure(this.name, this.start, this.bodyStart, this.end);

  final String name;
  final int start;
  final int bodyStart;
  final int end;

  /// Whether [offset] is inside the procedure, its first and last lines
  /// included.
  bool contains(int offset) => offset >= start && offset <= end;
}

/// The procedures of [source], in order, read by the lexer: the same
/// tokens the interpreter reads, so comments and strings never count.
List<Procedure> proceduresOf(String source) {
  final tokens = lex(source).tokens;
  final found = <Procedure>[];
  for (var i = 0; i < tokens.length - 1; i++) {
    final kind = tokens[i].keyword;
    if (kind != Keyword.kwSub && kind != Keyword.kwFunction) continue;
    if (i > 0 && tokens[i - 1].keyword == Keyword.kwEnd) continue;
    final name = tokens[i + 1];
    if (name.kind != TokenKind.identifier) continue;
    final start = _lineStart(source, tokens[i].offset);
    final lineEnd = source.indexOf('\n', tokens[i].offset);
    final bodyStart = lineEnd < 0 ? source.length : lineEnd + 1;
    var end = source.length;
    for (var j = i + 2; j < tokens.length - 1; j++) {
      if (tokens[j].keyword == Keyword.kwEnd && tokens[j + 1].keyword == kind) {
        end = _lineStart(source, tokens[j].offset);
        break;
      }
    }
    found.add(Procedure(name.text, start, bodyStart, end));
  }
  return found;
}

/// The procedure named [name] (any case), or null.
Procedure? procedureNamed(String source, String name) {
  final lower = name.toLowerCase();
  for (final p in proceduresOf(source)) {
    if (p.name.toLowerCase() == lower) return p;
  }
  return null;
}

/// The procedure whose `Handles` lists [event] of [control] (`Form` for
/// the form's own, written `Me.Load`), in any case, or null (D98).
String? procedureHandling(String source, String control, String event) {
  final c = control.toLowerCase();
  final e = event.toLowerCase();
  for (final member in parse(source).unit.members) {
    if (member is! ProcedureDecl) continue;
    for (final h in member.handles?.events ?? const <MemberExpr>[]) {
      final target = switch (h.target) {
        MeExpr() => 'form',
        NameExpr(:final name) => name.toLowerCase(),
        _ => null,
      };
      if (target == c && h.name.name.toLowerCase() == e) {
        return member.name.name;
      }
    }
  }
  return null;
}

/// Where the caret goes in [p]: the end of its first body line.
int caretIn(String source, Procedure p) {
  if (p.bodyStart >= p.end) return p.bodyStart;
  final lineEnd = source.indexOf('\n', p.bodyStart);
  return lineEnd < 0 || lineEnd > p.end ? p.end : lineEnd;
}

/// [source] with an empty handler `Sub [signature]` at its end, after an
/// empty line, and where the caret goes: its indented body line.
({String text, int caret}) withHandler(String source, String signature) {
  var text = source;
  if (text.isNotEmpty && !text.endsWith('\n')) text += '\n';
  if (text.trim().isNotEmpty && !text.endsWith('\n\n')) text += '\n';
  final first = 'Sub $signature\n';
  return (
    text: '$text$first    \nEnd Sub\n',
    caret: text.length + first.length + 4,
  );
}

int _lineStart(String text, int offset) =>
    offset == 0 ? 0 : text.lastIndexOf('\n', offset - 1) + 1;

/// A request to the code editor: go to the procedure [name] (the top of
/// the code when empty), and, if there is none and [signature] is given,
/// add the handler `Sub [signature]` first; or, with [line], go to that
/// line (1-based), as a click on an error in the output asks (D40). [id]
/// tells requests apart.
class GoTo {
  const GoTo(this.id, this.name, [this.signature]) : line = null;
  const GoTo.line(this.id, int this.line) : name = '', signature = null;

  final int id;
  final String name;
  final String? signature;
  final int? line;
}

/// Where the caret goes for line [line] (1-based) of [source]: after its
/// indentation, or the end of the code when it has fewer lines.
int caretAtLine(String source, int line) {
  var start = 0;
  for (var i = 1; i < line; i++) {
    final next = source.indexOf('\n', start);
    if (next < 0) return source.length;
    start = next + 1;
  }
  var at = start;
  while (at < source.length && (source[at] == ' ' || source[at] == '\t')) {
    at++;
  }
  return at;
}
