import '../ast/ast.dart';
import '../diagnostics/diagnostic.dart';
import '../lexer/lexer.dart';

/// The output of `parse`.
class ParseResult {
  ParseResult(this.lexResult, this.unit, this.parserDiagnostics);

  final LexResult lexResult;
  final CompilationUnit unit;

  /// Diagnostics from the parser only (P codes), in the order found.
  final List<Diagnostic> parserDiagnostics;

  /// Lexer and parser diagnostics together, in source order. Diagnostics at
  /// the same offset keep lexer-before-parser, then discovery order.
  late final List<Diagnostic> diagnostics = _stableSortByOffset([
    ...lexResult.diagnostics,
    ...parserDiagnostics,
  ]);

  static List<Diagnostic> _stableSortByOffset(List<Diagnostic> list) {
    final indexed = [for (var i = 0; i < list.length; i++) (i, list[i])];
    indexed.sort((a, b) {
      final byOffset = a.$2.offset.compareTo(b.$2.offset);
      return byOffset != 0 ? byOffset : a.$1.compareTo(b.$1);
    });
    return [for (final (_, d) in indexed) d];
  }
}
