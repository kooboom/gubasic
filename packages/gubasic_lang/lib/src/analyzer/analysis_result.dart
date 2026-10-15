import '../ast/ast.dart';
import '../diagnostics/diagnostic.dart';
import '../forms/component.dart';
import '../forms/form_file.dart';
import 'members.dart';
import 'symbols.dart';
import 'types.dart';

/// A procedure that runs when an event happens (docs/LANGUAGE.md §8).
class EventHandler {
  const EventHandler(this.control, this.event);

  /// The control, or null for the form's own events (`Form_Load`).
  final ControlDecl? control;
  final EventSpec event;
}

/// Whether `target(arguments)` calls something or picks an item.
enum InvokeKind { call, item }

/// What the analyzer learned about a program. The interpreter (and later
/// the transpiler) reads names, types and conversions from here instead of
/// working them out again, so both follow exactly the same rules.
///
/// All maps use node identity.
class AnalysisResult {
  AnalysisResult({
    required this.diagnostics,
    required this.fileScope,
    this.form,
  });

  /// The form the code belongs to, or null for code without a form (the
  /// playground).
  final FormFile? form;

  /// Analyzer diagnostics only (A codes).
  final List<Diagnostic> diagnostics;

  /// The names declared outside procedures, and the procedures.
  final Scope fileScope;

  /// What each [NameExpr] refers to, and the symbol each declaration
  /// ([Identifier] of a variable, parameter, loop or Catch variable)
  /// introduces.
  final Map<Node, Symbol> symbols = Map.identity();

  /// The type of each analyzed expression.
  final Map<Expr, GbType> types = Map.identity();

  /// Expressions whose value is converted before use, and the type it is
  /// converted to (see conversions.dart).
  final Map<Expr, GbType> conversions = Map.identity();

  final Map<InvokeExpr, InvokeKind> invokeKinds = Map.identity();

  /// Names and members that call a procedure without parentheses
  /// (`DoEvents`, `Form2.Show`, `s.ToUpper`).
  final Set<Expr> implicitCalls = Set.identity();

  /// The member each [MemberExpr] refers to, when it is a known one.
  final Map<MemberExpr, MemberSpec> members = Map.identity();

  /// The variable each loop counts with.
  final Map<Stmt, Symbol> loopVariables = Map.identity();

  /// The procedures that handle events of the form and its controls, when
  /// they are written as the event expects.
  final Map<ProcedureDecl, EventHandler> handlers = Map.identity();

  bool get hasErrors => diagnostics.any((d) => d.isError);
}
