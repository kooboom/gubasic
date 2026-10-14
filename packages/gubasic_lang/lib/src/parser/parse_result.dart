import '../ast/ast.dart';
import '../diagnostics/diagnostic.dart';
import '../lexer/lexer.dart';

/// The output of `parse`.
class ParseResult {
  ParseResult(this.source, this.lexResult, this.unit, this.parserDiagnostics);

  final String source;
  final LexResult lexResult;
  final CompilationUnit unit;

  /// Diagnostics from the parser only (P codes), in the order found.
  final List<Diagnostic> parserDiagnostics;

  /// Whether any lexer or parser diagnostic is an error. Warnings alone do
  /// not count.
  bool get hasErrors => diagnostics.any((d) => d.isError);

  /// Lexer and parser diagnostics together, in source order.
  late final List<Diagnostic> diagnostics =
      sortDiagnostics([...lexResult.diagnostics, ...parserDiagnostics]);
}
