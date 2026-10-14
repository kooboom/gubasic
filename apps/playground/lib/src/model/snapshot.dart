import 'package:gubasic_lang/gubasic_lang.dart';

/// Everything the playground knows about one version of the source.
///
/// Result tabs read only from a snapshot. When the parser arrives, its
/// result is added here and the AST tab reads it.
class Snapshot {
  Snapshot(this.source) : lexResult = lex(source);

  final String source;
  final LexResult lexResult;

  /// All diagnostics, in source order.
  List<Diagnostic> get diagnostics => lexResult.diagnostics;
}
