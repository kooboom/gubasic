import '../diagnostics/diagnostic.dart';
import '../parser/parse_result.dart';
import '../parser/parser.dart';
import 'analysis_result.dart';
import 'analyzer.dart';

/// Lexing, parsing and analysis of one source file.
class CompileResult {
  CompileResult(this.parseResult, this.analysis);

  final ParseResult parseResult;
  final AnalysisResult analysis;

  /// Lexer, parser and analyzer diagnostics, in source order.
  late final List<Diagnostic> diagnostics = sortDiagnostics([
    ...parseResult.lexResult.diagnostics,
    ...parseResult.parserDiagnostics,
    ...analysis.diagnostics,
  ]);

  /// Whether any diagnostic is an error. Warnings alone do not count: a
  /// program with only warnings can run (D23).
  bool get hasErrors => diagnostics.any((d) => d.isError);
}

/// Lexes, parses and analyzes [source].
CompileResult compile(String source) {
  final parsed = parse(source);
  return CompileResult(parsed, analyze(parsed));
}
