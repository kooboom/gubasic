import '../ast/ast.dart';
import 'builtins.dart';
import 'types.dart';

enum SymbolKind {
  variable,
  constant,
  parameter,

  /// A `For` / `For Each` variable declared automatically by the loop.
  loopVariable,
  procedure,
  builtinFunction,
  builtinObject,

  /// A control on the form (`btnSave`). Its type is a [ControlType].
  control,
}

/// Where a variable lives.
enum Storage {
  /// Declared outside any procedure: the form's (or module's) variables.
  field,

  /// `Dim` inside a procedure, a parameter or a loop variable: one per call.
  local,

  /// `Static` inside a procedure: kept between calls.
  staticLocal,
}

/// Something a name can refer to.
class Symbol {
  Symbol({
    required this.name,
    required this.kind,
    required this.type,
    this.declaration,
    this.storage,
    this.procedure,
    this.callable,
  });

  /// As declared (spelling preserved).
  final String name;
  final SymbolKind kind;
  GbType type;

  /// The declaring node: an [Identifier] for variables, the
  /// [ProcedureDecl] for procedures; null for built-ins and controls.
  final Node? declaration;
  final Storage? storage;

  /// For [SymbolKind.procedure].
  final ProcedureDecl? procedure;

  /// The signature of a procedure or built-in function.
  Callable? callable;

  /// Mentioned anywhere besides its declaration.
  bool used = false;

  int get declarationOffset => declaration?.start ?? -1;

  bool get isVariable =>
      kind == SymbolKind.variable ||
      kind == SymbolKind.parameter ||
      kind == SymbolKind.loopVariable;

  bool get isCallable =>
      kind == SymbolKind.procedure || kind == SymbolKind.builtinFunction;

  @override
  String toString() => '${kind.name} $name: ${type.displayName}';
}

/// From the outside in: built-ins, the form's controls (only when the code
/// belongs to a form), the file's own names, a procedure, a block.
enum ScopeKind { builtins, form, file, procedure, block }

class Scope {
  Scope(this.kind, this.parent);

  final ScopeKind kind;
  final Scope? parent;
  final Map<String, Symbol> symbols = {};

  Symbol? lookup(String name) {
    final key = name.toLowerCase();
    for (Scope? s = this; s != null; s = s.parent) {
      final found = s.symbols[key];
      if (found != null) return found;
    }
    return null;
  }

  /// Looks only in this scope and its parents up to (and including) the
  /// nearest procedure scope: the names a new local would collide with.
  Symbol? lookupInProcedure(String name) {
    final key = name.toLowerCase();
    for (Scope? s = this; s != null; s = s.parent) {
      final found = s.symbols[key];
      if (found != null) return found;
      if (s.kind == ScopeKind.procedure) return null;
    }
    return null;
  }

  void declare(Symbol symbol) => symbols[symbol.name.toLowerCase()] = symbol;

  /// Every name visible from here (for "did you mean" suggestions).
  Iterable<Symbol> get visible sync* {
    for (Scope? s = this; s != null; s = s.parent) {
      yield* s.symbols.values;
    }
  }
}
