import '../diagnostics/diagnostic.dart';
import '../forms/form_file.dart';
import '../parser/parse_result.dart';
import '../parser/parser.dart';
import 'analysis_result.dart';
import 'analyzer.dart';
import 'forms.dart';

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

/// Lexes, parses and analyzes [source]; [form] is the form the code
/// belongs to, if any, [pictures] the project's pictures, [forms] the
/// project's forms and [modules] its modules (see [analyze]).
CompileResult compile(
  String source, {
  FormFile? form,
  List<String>? pictures,
  Map<String, FormInterface>? forms,
  Map<String, ModuleInterface>? modules,
}) {
  final parsed = parse(source);
  return CompileResult(
      parsed,
      analyze(parsed,
          form: form, pictures: pictures, forms: forms, modules: modules));
}
