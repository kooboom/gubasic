import '../ast/ast.dart';
import '../diagnostics/diagnostic.dart';
import '../lexer/lexer.dart';

/// The output of `parse`.
class ParseResult {
  ParseResult(this.source, this.lexResult, this.unit, this.parserDiagnostics,
      {BlockLines? blockLines})
      : blockLines = blockLines ?? BlockLines();

  final String source;
  final LexResult lexResult;
  final CompilationUnit unit;

  /// Diagnostics from the parser only (P codes), in the order found.
  final List<Diagnostic> parserDiagnostics;

  /// Which lines open, go on with and close each block, as the parser
  /// paired them: for the editor's indentation and block completion.
  final BlockLines blockLines;

  /// Whether any lexer or parser diagnostic is an error. Warnings alone do
  /// not count.
  bool get hasErrors => diagnostics.any((d) => d.isError);

  /// Lexer and parser diagnostics together, in source order.
  late final List<Diagnostic> diagnostics =
      sortDiagnostics([...lexResult.diagnostics, ...parserDiagnostics]);
}

/// The lines of a program's blocks as the parser paired them, by line
/// number (from 1). A single-line If has none.
class BlockLines {
  /// The line of each block's opener (`If x Then`, `For`, `Sub`) and the
  /// closing line it takes (`End If`, `Next`, `End Sub`).
  final openers = <int, String>{};

  /// Each line that goes on with a block (`Else`, `ElseIf`, `Case`,
  /// `Catch`, `Finally`) and the line of that block's opener.
  final middles = <int, int>{};

  /// Each line that closes a block (`End If`, `Next`, `Loop`) and the line
  /// of that block's opener.
  final closers = <int, int>{};
}
