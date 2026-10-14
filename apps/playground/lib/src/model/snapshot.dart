import 'package:gubasic_lang/gubasic_lang.dart';

/// Everything the playground knows about one version of the source.
///
/// Result tabs read only from a snapshot. When a later stage arrives
/// (analyzer, interpreter), its result is added here and a tab reads it.
class Snapshot {
  Snapshot(this.source) : parseResult = parse(source);

  final String source;
  final ParseResult parseResult;

  LexResult get lexResult => parseResult.lexResult;
  CompilationUnit get unit => parseResult.unit;

  /// Lexer and parser diagnostics, in source order.
  List<Diagnostic> get diagnostics => parseResult.diagnostics;

  late final LineMap lineMap = LineMap(source);
}
