import 'package:gubasic_lang/gubasic_lang.dart';

/// Everything the playground knows about one version of the source.
///
/// Result tabs read only from a snapshot. When a later stage arrives
/// (interpreter), its result is added here and a tab reads it.
class Snapshot {
  Snapshot(this.source) : compileResult = compile(source);

  final String source;
  final CompileResult compileResult;

  ParseResult get parseResult => compileResult.parseResult;
  LexResult get lexResult => parseResult.lexResult;
  CompilationUnit get unit => parseResult.unit;

  /// Lexer, parser and analyzer diagnostics, in source order.
  List<Diagnostic> get diagnostics => compileResult.diagnostics;

  late final LineMap lineMap = LineMap(source);
}
