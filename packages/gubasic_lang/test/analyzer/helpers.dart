import 'package:gubasic_lang/gubasic_lang.dart';

/// `code@line` for every diagnostic of [source].
List<String> diagnose(String source) =>
    compile(source).diagnostics.map((d) => '${d.code.code}@${d.line}').toList();

/// Diagnostic codes for [body] placed in `Sub Main() … End Sub` (line 2 on).
List<String> inMain(String body) => diagnose('Sub Main()\n$body\nEnd Sub\n')
    .map((c) => c.split('@').first)
    .toList();

/// The analyzed type of the expression in `x = <expr>`, with x an Object.
String typeOf(String expression, {String declarations = ''}) {
  final r = compile('Sub Main()\n$declarations\nDim x As Object\n'
      'x = $expression\nEnd Sub\n');
  final proc = r.parseResult.unit.members.single as ProcedureDecl;
  final assign = proc.body.statements.last as AssignmentStmt;
  return r.analysis.types[assign.value]?.displayName ?? '(none)';
}
