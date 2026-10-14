import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Parses [source] and expects no diagnostics at all.
ParseResult parseClean(String source) {
  final r = parse(source);
  expect(r.diagnostics, isEmpty, reason: 'source:\n$source');
  return r;
}

/// The statements of `Sub T() … End Sub` wrapped around [body].
List<Stmt> statements(String body, {bool clean = true}) {
  final src = 'Sub T()\n$body\nEnd Sub\n';
  final r = clean ? parseClean(src) : parse(src);
  return (r.unit.members.single as ProcedureDecl).body.statements;
}

Stmt statement(String body) => statements(body).single;

/// The expression [source] as an s-expression (via `x = <source>`).
String sexp(String source) {
  final s = statement('x = $source') as AssignmentStmt;
  return exprToSexp(s.value);
}

List<String> codes(ParseResult r) =>
    r.diagnostics.map((d) => d.code.code).toList();

/// `code@line` for each diagnostic, e.g. `P006@3`.
List<String> codesAndLines(ParseResult r) =>
    r.diagnostics.map((d) => '${d.code.code}@${d.line}').toList();
