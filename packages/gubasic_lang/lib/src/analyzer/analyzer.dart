import '../ast/ast.dart';
import '../ast/line_map.dart';
import '../diagnostics/diagnostic.dart';
import '../forms/component.dart';
import '../forms/form_file.dart';
import '../lexer/keyword.dart';
import '../parser/parse_result.dart';
import 'analysis_result.dart';
import 'builtins.dart';
import 'conversions.dart';
import 'members.dart';
import 'symbols.dart';
import 'types.dart';

/// Checks names and types of a parsed program (docs/LANGUAGE.md §2–§8).
///
/// [form] is the form the code belongs to: its controls and `Me` can then
/// be used, and event handlers are checked. Without it (the playground),
/// they cannot.
///
/// Never throws. Runs even when the parser found errors: anything it cannot
/// work out gets the unknown type, which is never checked again, so one
/// mistake is reported once.
AnalysisResult analyze(ParseResult parsed, {FormFile? form}) =>
    _Analyzer(parsed, form).run();

/// A procedure being analyzed.
class _ProcedureContext {
  _ProcedureContext(this.decl, this.symbol, this.laterLocals);

  final ProcedureDecl decl;
  final Symbol symbol;

  /// Every local declared anywhere in the procedure, with its offset, to
  /// tell "used before its declaration" from "not declared".
  final Map<String, Identifier> laterLocals;

  final locals = <Symbol>[];

  /// Locals mentioned above their declaration (already reported as A006):
  /// not reported again as unused.
  final mentionedEarly = <String>{};
  final loops = <Keyword>[];
  var hasReturn = false;
  var assignedToName = false;

  bool get isFunction => decl.isFunction;
}

class _Analyzer {
  _Analyzer(this.parsed, this.form)
      : _lines = LineMap(parsed.source),
        _builtins = Scope(ScopeKind.builtins, null) {
    for (final f in builtinFunctions.values) {
      _builtins.declare(Symbol(
          name: f.name,
          kind: SymbolKind.builtinFunction,
          type: f.returnType,
          callable: f));
    }
    for (final name in builtinObjects.values) {
      _builtins.declare(Symbol(
          name: name,
          kind: SymbolKind.builtinObject,
          type: GbType.builtinObject));
    }
    Scope outer = _builtins;
    final form = this.form;
    if (form != null) {
      _controls = outer = Scope(ScopeKind.form, _builtins);
      for (final c in form.controls) {
        _controls!.declare(Symbol(
            name: c.name, kind: SymbolKind.control, type: c.component.type));
      }
    }
    _file = Scope(ScopeKind.file, outer);
    _result =
        AnalysisResult(diagnostics: _diagnostics, fileScope: _file, form: form);
  }

  final ParseResult parsed;
  final FormFile? form;

  /// The form's controls, when there is a form.
  Scope? _controls;
  final LineMap _lines;
  final Scope _builtins;
  late final Scope _file;
  late final AnalysisResult _result;
  final _diagnostics = <Diagnostic>[];

  late Scope _scope;
  _ProcedureContext? _proc;

  // -------------------------------------------------------------------------
  // Diagnostics

  void _report(DiagnosticCode code, int start, int end,
      [List<String> args = const []]) {
    final (line, column) = _lines.locate(start);
    _diagnostics.add(Diagnostic(
      code: code,
      line: line,
      column: column,
      offset: start,
      length: end - start,
      args: args,
    ));
  }

  void _reportAt(Node node, DiagnosticCode code,
          [List<String> args = const []]) =>
      _report(code, node.start, node.end, args);

  int _line(Node node) => _lines.locate(node.start).$1;

  String _text(Node node) => parsed.source.substring(node.start, node.end);

  // -------------------------------------------------------------------------
  // File level

  AnalysisResult run() {
    final unit = parsed.unit;
    _scope = _file;

    // 1. Names declared outside procedures, so that procedures and fields
    //    can be used anywhere in the file.
    for (final member in unit.members) {
      switch (member) {
        case FieldDecl(:final declarator, :final isConst):
          _declareInto(
              _file,
              declarator.name,
              Symbol(
                name: declarator.name.name,
                kind: isConst ? SymbolKind.constant : SymbolKind.variable,
                type: GbType.unknown,
                declaration: declarator.name,
                storage: Storage.field,
              ));
        case ProcedureDecl():
          _declareInto(
              _file,
              member.name,
              Symbol(
                name: member.name.name,
                kind: SymbolKind.procedure,
                type: GbType.unknown,
                declaration: member,
                procedure: member,
              ));
        case InvalidMember():
          break;
      }
    }

    // 2. Procedure signatures.
    for (final member in unit.members.whereType<ProcedureDecl>()) {
      final symbol = _result.symbols[member.name];
      if (symbol == null) continue;
      final parameters = [
        for (final p in member.parameters)
          ParamSpec(p.name.name, _parameterType(p), optional: p.isOptional),
      ];
      GbType returnType = GbType.void_;
      if (member.isFunction) {
        if (member.returnType != null) {
          returnType = _resolveType(member.returnType!);
        } else if (member.name.name.isNotEmpty) {
          _reportAt(member.name, DiagnosticCode.missingTypeAndValue,
              [member.name.name]);
          returnType = GbType.unknown;
        }
      }
      symbol
        ..type = returnType
        ..callable = Callable(member.name.name, parameters, returnType);
    }

    // 2b. Event handlers.
    if (form != null) {
      for (final member in unit.members.whereType<ProcedureDecl>()) {
        if (_result.symbols[member.name]?.procedure == member) {
          _handler(member);
        }
      }
    }

    // 3. Field types and initial values, in order.
    for (final member in unit.members.whereType<FieldDecl>()) {
      final symbol = _result.symbols[member.declarator.name];
      final type = _declarator(member.declarator, isConst: member.isConst);
      symbol?.type = type;
    }

    // 4. Procedure bodies.
    for (final member in unit.members.whereType<ProcedureDecl>()) {
      final symbol = _result.symbols[member.name];
      if (symbol != null && symbol.procedure == member) {
        _procedure(member, symbol);
      }
    }
    return _result;
  }

  /// Declares [symbol] in [scope] unless the name is taken (A005).
  bool _declareInto(Scope scope, Identifier name, Symbol symbol) {
    if (name.name.isEmpty) return false;
    final existing = scope.symbols[name.name.toLowerCase()];
    if (existing != null) {
      _reportAt(name, DiagnosticCode.duplicateDeclaration,
          [name.name, '${_line(existing.declaration ?? name)}']);
      return false;
    }
    if (scope == _file && _controls?.symbols[name.name.toLowerCase()] != null) {
      // Declared anyway, so that its uses in the code are checked as the
      // code means them.
      _reportAt(name, DiagnosticCode.nameIsControl, [name.name]);
    }
    scope.declare(symbol);
    _result.symbols[name] = symbol;
    return true;
  }

  /// Records [decl] as an event handler if its name is `Control_Event`
  /// (or `Form_Event`) for an event that exists, and checks that it is
  /// written as the event expects (A032).
  void _handler(ProcedureDecl decl) {
    final name = decl.name.name.toLowerCase();
    final targets = [
      (null as ControlDecl?, 'Form', formComponent),
      for (final c in form!.controls) (c, c.name, c.component),
    ];
    for (final (control, owner, component) in targets) {
      if (!name.startsWith('${owner.toLowerCase()}_')) continue;
      final event = component.events[name.substring(owner.length + 1)];
      if (event == null) continue;
      final callable = _result.symbols[decl.name]!.callable!;
      final ok = !decl.isFunction &&
          callable.parameters.length == event.parameters.length &&
          [
            for (var i = 0; i < event.parameters.length; i++)
              callable.parameters[i].type == event.parameters[i].type &&
                  !callable.parameters[i].optional
          ].every((same) => same);
      if (ok) {
        _result.handlers[decl] = EventHandler(control, event);
      } else {
        _reportAt(decl.name, DiagnosticCode.handlerSignature, [
          decl.name.name,
          '$owner.${event.name}',
          'Sub ${event.handlerSignature(owner)}',
        ]);
      }
      return;
    }
  }

  GbType _parameterType(Parameter p) {
    if (p.type == null) {
      if (p.name.name.isNotEmpty) {
        _reportAt(p.name, DiagnosticCode.missingTypeAndValue, [p.name.name]);
      }
      return GbType.unknown;
    }
    final t = _resolveType(p.type!);
    return p.isArray ? ArrayType(t) : t;
  }

  GbType _resolveType(TypeRef ref) {
    final name = ref.name.name;
    if (name.isEmpty) return GbType.unknown; // reported by the parser
    final lower = name.toLowerCase();
    if (lower == 'variant') return GbType.unknown; // P015
    if (lower == 'list') {
      final element = ref.typeArguments.isEmpty
          ? GbType.object
          : _resolveType(ref.typeArguments.first);
      return ListType(element);
    }
    final named = lookupNamedType(lower);
    if (named != null) return named;
    _reportAt(ref.name, DiagnosticCode.unknownType, [name]);
    return GbType.unknown;
  }

  /// The type of a declared variable; checks its initial value and bound.
  GbType _declarator(VariableDeclarator d, {required bool isConst}) {
    GbType? declared = d.type == null ? null : _resolveType(d.type!);
    if (d.arrayBound != null) _expect(d.arrayBound!, GbType.integer);
    if (d.isArray) {
      if (declared == null) {
        _reportAt(d.name, DiagnosticCode.missingTypeAndValue, [d.name.name]);
        return GbType.unknown;
      }
      declared = ArrayType(declared);
    }
    if (d.isNew && declared != null) {
      _newArguments(declared, d.newArguments ?? const [], d);
    }
    final init = d.initializer;
    if (init == null) {
      if (declared == null && d.name.name.isNotEmpty) {
        _reportAt(d.name, DiagnosticCode.missingTypeAndValue, [d.name.name]);
        return GbType.unknown;
      }
      return declared ?? GbType.unknown;
    }
    if (declared != null) {
      _expect(init, declared);
      return declared;
    }
    final inferred = _value(init);
    if (inferred == GbType.nothing) {
      _reportAt(d.name, DiagnosticCode.missingTypeAndValue, [d.name.name]);
      return GbType.unknown;
    }
    return inferred;
  }

  // -------------------------------------------------------------------------
  // Procedures and statements

  void _procedure(ProcedureDecl decl, Symbol symbol) {
    final context = _ProcedureContext(decl, symbol, _collectLocals(decl.body));
    _proc = context;
    final procedureScope = Scope(ScopeKind.procedure, _file);
    for (final p in decl.parameters) {
      _declareInto(
          procedureScope,
          p.name,
          Symbol(
            name: p.name.name,
            kind: SymbolKind.parameter,
            type:
                symbol.callable!.parameters[decl.parameters.indexOf(p)].type ??
                    GbType.unknown,
            declaration: p.name,
            storage: Storage.local,
          ));
      if (p.defaultValue != null) {
        _scope = procedureScope;
        _expect(
            p.defaultValue!, _result.symbols[p.name]?.type ?? GbType.unknown);
      }
    }
    _scope = procedureScope;
    _block(decl.body);
    _scope = _file;

    for (final local in context.locals) {
      if (!local.used) {
        _reportAt(local.declaration!, DiagnosticCode.unusedLocal, [local.name]);
      }
    }
    if (decl.isFunction &&
        !context.hasReturn &&
        !context.assignedToName &&
        decl.name.name.isNotEmpty) {
      _reportAt(
          decl.name, DiagnosticCode.functionWithoutReturn, [decl.name.name]);
    }
    _proc = null;
  }

  /// Every local declared in [block] and the blocks inside it, first
  /// declaration wins.
  Map<String, Identifier> _collectLocals(Block block) {
    final found = <String, Identifier>{};
    void visit(Node node) {
      if (node is LocalDeclStmt) {
        found.putIfAbsent(node.declarator.name.name.toLowerCase(),
            () => node.declarator.name);
      }
      for (final child in node.children) {
        visit(child);
      }
    }

    visit(block);
    return found;
  }

  void _block(Block block, {Scope? scope}) {
    final saved = _scope;
    _scope = scope ?? Scope(ScopeKind.block, _scope);
    for (final s in block.statements) {
      _statement(s);
    }
    _scope = saved;
  }

  void _statement(Stmt s) {
    switch (s) {
      case LocalDeclStmt():
        _localDeclaration(s);
      case AssignmentStmt():
        _assignment(s);
      case ExpressionStmt():
        _expressionStatement(s.expression);
      case IfStmt():
        for (final branch in s.branches) {
          _condition(branch.condition);
          _block(branch.body);
        }
        if (s.elseBlock != null) _block(s.elseBlock!);
      case SelectStmt():
        _select(s);
      case ForStmt():
        _for(s);
      case ForEachStmt():
        _forEach(s);
      case DoLoopStmt():
        if (s.preCondition != null) _condition(s.preCondition!.condition);
        _proc?.loops.add(Keyword.kwDo);
        _block(s.body);
        _proc?.loops.removeLast();
        if (s.postCondition != null) _condition(s.postCondition!.condition);
      case ExitStmt():
        _exit(s);
      case ReturnStmt():
        _return(s);
      case TryStmt():
        _try(s);
      case ThrowStmt():
        final t = _value(s.value);
        if (t != GbType.exception &&
            t != GbType.object &&
            t != GbType.unknown) {
          _reportAt(s.value, DiagnosticCode.typeMismatch,
              [t.displayName, GbType.exception.displayName]);
        }
      case ReDimStmt():
        _reDim(s);
      case EndStmt() || ErrorStmt():
        break;
    }
  }

  void _localDeclaration(LocalDeclStmt s) {
    final d = s.declarator;
    final type = _declarator(d, isConst: s.kind == Keyword.kwConst);
    if (d.name.name.isEmpty) return;
    final symbol = Symbol(
      name: d.name.name,
      kind:
          s.kind == Keyword.kwConst ? SymbolKind.constant : SymbolKind.variable,
      type: type,
      declaration: d.name,
      storage: s.kind == Keyword.kwStatic ? Storage.staticLocal : Storage.local,
    );
    if (_proc?.mentionedEarly.contains(d.name.name.toLowerCase()) ?? false) {
      symbol.used = true;
    }
    if (_declareLocal(d.name, symbol)) _proc?.locals.add(symbol);
  }

  /// Declares a local in the current block: an error if the procedure
  /// already has that name (H1), a warning if it hides a field.
  bool _declareLocal(Identifier name, Symbol symbol) {
    if (name.name.isEmpty) return false;
    final clash = _scope.lookupInProcedure(name.name);
    if (clash != null) {
      _reportAt(name, DiagnosticCode.duplicateDeclaration,
          [name.name, '${_line(clash.declaration ?? name)}']);
      return false;
    }
    if (_controls?.symbols[name.name.toLowerCase()] != null &&
        _file.symbols[name.name.toLowerCase()] == null) {
      _reportAt(name, DiagnosticCode.localHidesControl, [name.name]);
    }
    final field = _file.symbols[name.name.toLowerCase()];
    if (field != null &&
        (field.kind == SymbolKind.variable ||
            field.kind == SymbolKind.constant)) {
      _reportAt(name, DiagnosticCode.localHidesField,
          [name.name, '${_line(field.declaration!)}']);
    }
    _scope.declare(symbol);
    _result.symbols[name] = symbol;
    return true;
  }

  void _assignment(AssignmentStmt s) {
    final target = s.target;
    final GbType targetType;
    switch (target) {
      case NameExpr():
        final symbol = _lookupName(target);
        if (symbol == null) {
          targetType = GbType.unknown;
        } else if (symbol.isVariable) {
          targetType = symbol.type;
        } else if (symbol.kind == SymbolKind.procedure &&
            symbol == _proc?.symbol &&
            _proc!.isFunction) {
          // VB6: FunctionName = value.
          _proc!.assignedToName = true;
          _reportAt(target, DiagnosticCode.assignToFunctionName, [target.name]);
          _value(s.value);
          return;
        } else {
          _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
          targetType = GbType.unknown;
        }
      case MemberExpr():
        final t = _member(target, asCall: false, valueNeeded: true);
        final spec = _result.members[target];
        if (spec != null && spec.isMethod) {
          _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
          targetType = GbType.unknown;
        } else if (spec != null && spec.readOnly) {
          _reportAt(target, DiagnosticCode.readOnlyProperty, [_text(target)]);
          targetType = GbType.unknown;
        } else {
          targetType = t;
        }
      case InvokeExpr():
        final t = _invoke(target, valueNeeded: true);
        if (_result.invokeKinds[target] == InvokeKind.call) {
          _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
          targetType = GbType.unknown;
        } else {
          targetType = t;
        }
      case ErrorExpr():
        targetType = GbType.unknown;
      default:
        _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
        targetType = GbType.unknown;
    }
    _expect(s.value, targetType);
  }

  void _expressionStatement(Expr e) {
    switch (e) {
      case InvokeExpr():
        _invoke(e, valueNeeded: false);
        if (_result.invokeKinds[e] == InvokeKind.item) {
          _reportAt(e, DiagnosticCode.notCallable, [_text(e.target)]);
        }
      case NameExpr():
        final symbol = _lookupName(e);
        if (symbol == null) return;
        if (symbol.isCallable) {
          _implicitCall(e, symbol.callable!, valueNeeded: false);
        } else if (symbol.kind != SymbolKind.builtinObject) {
          _reportAt(e, DiagnosticCode.notCallable, [e.name]);
        }
      case MemberExpr():
        _member(e, asCall: false, valueNeeded: false);
        final spec = _result.members[e];
        if (spec != null && !spec.isMethod) {
          _reportAt(e, DiagnosticCode.notCallable, [_text(e)]);
        }
      case ErrorExpr():
        break;
      default:
        _value(e);
        _reportAt(e, DiagnosticCode.notCallable, [_text(e)]);
    }
  }

  void _condition(Expr e) {
    final t = _value(e);
    if (t != GbType.boolean && t != GbType.unknown) {
      _reportAt(e, DiagnosticCode.conditionNotBoolean, [t.displayName]);
    }
  }

  void _select(SelectStmt s) {
    final subject = _value(s.subject);
    for (final c in s.cases) {
      for (final clause in c.clauses) {
        switch (clause) {
          case ValueClause(:final value):
            _compare(BinaryOp.equal, subject, _value(value), value);
          case RangeClause(:final low, :final high):
            _compare(BinaryOp.lessEqual, subject, _value(low), low);
            _compare(BinaryOp.lessEqual, subject, _value(high), high);
          case RelationalClause(:final operator, :final value):
            _compare(operator, subject, _value(value), value);
        }
      }
      _block(c.body);
    }
  }

  void _for(ForStmt s) {
    final from = _value(s.from);
    final to = _value(s.to);
    final step = s.step == null ? null : _value(s.step!);
    final loopScope = Scope(ScopeKind.block, _scope);
    final saved = _scope;
    _scope = loopScope;

    Symbol? variable;
    if (s.variableType != null) {
      variable = _newLoopVariable(s.variable, _resolveType(s.variableType!));
    } else {
      variable = _existingLoopVariable(s.variable);
      if (variable == null && s.variable.name.isNotEmpty) {
        final bounds = [from, to, if (step != null) step];
        final type = bounds.contains(GbType.double_)
            ? GbType.double_
            : bounds.every((t) => t == GbType.integer || t == GbType.unknown)
                ? GbType.integer
                : GbType.unknown;
        variable = _newLoopVariable(s.variable, type, automatic: true);
      }
    }
    final varType = variable?.type ?? GbType.unknown;
    if (variable != null) _result.loopVariables[s] = variable;
    if (varType != GbType.unknown && !varType.isNumeric) {
      _reportAt(s.variable, DiagnosticCode.typeMismatch,
          [varType.displayName, GbType.integer.displayName]);
    } else {
      _convert(s.from, from, varType);
      _convert(s.to, to, varType);
      if (s.step != null) _convert(s.step!, step!, varType);
    }

    _proc?.loops.add(Keyword.kwFor);
    _block(s.body);
    _proc?.loops.removeLast();
    _scope = saved;
  }

  void _forEach(ForEachStmt s) {
    final collection = _value(s.collection);
    final GbType element;
    switch (collection) {
      case ListType(element: final e) || ArrayType(element: final e):
        element = e;
      case GbType.object:
        element = GbType.object;
      case GbType.unknown:
        element = GbType.unknown;
      default:
        _reportAt(s.collection, DiagnosticCode.cannotLoopOver,
            [collection.displayName]);
        element = GbType.unknown;
    }
    final saved = _scope;
    _scope = Scope(ScopeKind.block, _scope);
    Symbol? variable;
    if (s.variableType != null) {
      variable = _newLoopVariable(s.variable, _resolveType(s.variableType!));
    } else {
      variable = _existingLoopVariable(s.variable) ??
          (s.variable.name.isEmpty
              ? null
              : _newLoopVariable(s.variable, element, automatic: true));
    }
    if (variable != null) {
      _result.loopVariables[s] = variable;
      final check = checkConversion(element, variable.type);
      if (!check.isAllowed) {
        _reportAt(s.collection, check.error!,
            [element.displayName, variable.type.displayName]);
      }
    }
    _proc?.loops.add(Keyword.kwFor);
    _block(s.body);
    _proc?.loops.removeLast();
    _scope = saved;
  }

  /// A loop variable that is already declared, or null.
  Symbol? _existingLoopVariable(Identifier name) {
    if (name.name.isEmpty) return null;
    final symbol = _scope.lookup(name.name);
    if (symbol == null) return null;
    symbol.used = true;
    _result.symbols[name] = symbol;
    if (!symbol.isVariable) {
      _reportAt(name, DiagnosticCode.notAssignable, [name.name]);
    }
    return symbol;
  }

  /// `For i As Integer` or an undeclared `For i`: a variable that exists
  /// only inside the loop.
  Symbol? _newLoopVariable(Identifier name, GbType type,
      {bool automatic = false}) {
    if (name.name.isEmpty) return null;
    final symbol = Symbol(
      name: name.name,
      kind: automatic ? SymbolKind.loopVariable : SymbolKind.variable,
      type: type,
      declaration: name,
      storage: Storage.local,
    )..used = true;
    _declareLocal(name, symbol);
    return symbol;
  }

  void _exit(ExitStmt s) {
    final ok = switch (s.kind) {
      Keyword.kwFor || Keyword.kwDo => _proc?.loops.contains(s.kind) ?? false,
      Keyword.kwSub => _proc != null && !_proc!.isFunction,
      Keyword.kwFunction => _proc != null && _proc!.isFunction,
      _ => true,
    };
    if (!ok) {
      _reportAt(
          s, DiagnosticCode.exitOutsideBlock, ['Exit ${s.kind.spelling}']);
    }
  }

  void _return(ReturnStmt s) {
    final proc = _proc;
    if (proc == null) return;
    proc.hasReturn = true;
    if (!proc.isFunction) {
      if (s.value != null) {
        _value(s.value!);
        _reportAt(s, DiagnosticCode.returnValueInSub);
      }
      return;
    }
    if (s.value == null) {
      _reportAt(s, DiagnosticCode.returnWithoutValue);
      return;
    }
    _expect(s.value!, proc.symbol.callable?.returnType ?? GbType.unknown);
  }

  void _try(TryStmt s) {
    _block(s.body);
    for (final c in s.catches) {
      final scope = Scope(ScopeKind.block, _scope);
      if (c.name != null && c.name!.name.isNotEmpty) {
        GbType type = GbType.exception;
        if (c.type != null) {
          type = _resolveType(c.type!);
          if (type != GbType.exception && type != GbType.unknown) {
            _reportAt(c.type!, DiagnosticCode.typeMismatch,
                [type.displayName, GbType.exception.displayName]);
          }
        }
        final saved = _scope;
        _scope = scope;
        _declareLocal(
            c.name!,
            Symbol(
              name: c.name!.name,
              kind: SymbolKind.variable,
              type: type,
              declaration: c.name,
              storage: Storage.local,
            )..used = true);
        _scope = saved;
      }
      _block(c.body, scope: Scope(ScopeKind.block, scope));
    }
    if (s.finallyBlock != null) _block(s.finallyBlock!);
  }

  void _reDim(ReDimStmt s) {
    final symbol = _scope.lookup(s.name.name);
    if (symbol == null) {
      if (s.name.name.isNotEmpty) {
        _reportAt(s.name, DiagnosticCode.unknownName, [s.name.name]);
      }
    } else {
      symbol.used = true;
      _result.symbols[s.name] = symbol;
      if (symbol.type is! ArrayType && symbol.type != GbType.unknown) {
        _reportAt(
            s.name, DiagnosticCode.notIndexable, [symbol.type.displayName]);
      }
    }
    _expect(s.bound, GbType.integer);
  }

  // -------------------------------------------------------------------------
  // Expressions

  /// Analyzes [e] where a value is needed and checks that it can be stored
  /// as [target], recording any automatic conversion.
  void _expect(Expr e, GbType target) => _convert(e, _value(e), target);

  void _convert(Expr e, GbType from, GbType target) {
    final check = checkConversion(from, target);
    if (check.isAllowed) {
      final c = check.conversion!;
      if (c != ImplicitConversion.none && c != ImplicitConversion.unchecked) {
        _result.conversions[e] = target;
      }
      return;
    }
    if (from == GbType.void_) return; // already reported as A017
    _reportAt(e, check.error!, [from.displayName, target.displayName]);
  }

  GbType _value(Expr e) => _expr(e, valueNeeded: true);

  GbType _expr(Expr e, {required bool valueNeeded}) {
    final type = switch (e) {
      IntegerLiteral() => GbType.integer,
      DoubleLiteral() => GbType.double_,
      StringLiteral() => GbType.string,
      BooleanLiteral() => GbType.boolean,
      NothingLiteral() => GbType.nothing,
      MeExpr() => _me(e),
      NameExpr() => _name(e, valueNeeded: valueNeeded),
      MemberExpr() => _member(e, asCall: false, valueNeeded: valueNeeded),
      InvokeExpr() => _invoke(e, valueNeeded: valueNeeded),
      NewExpr() => _new(e),
      UnaryExpr() => _unary(e),
      BinaryExpr() => _binary(e),
      ParenExpr() => _value(e.inner),
      ErrorExpr() => GbType.unknown,
    };
    _result.types[e] = type;
    return type;
  }

  GbType _me(MeExpr e) {
    if (form != null) return formComponent.type;
    _reportAt(e, DiagnosticCode.unknownNameMaybeControl, ['Me']);
    return GbType.unknown;
  }

  /// Resolves a name, reporting it if it is not declared. Marks it used.
  Symbol? _lookupName(NameExpr e, {bool beforeDot = false}) {
    final symbol = _scope.lookup(e.name);
    if (symbol != null) {
      symbol.used = true;
      _result.symbols[e] = symbol;
      return symbol;
    }
    _unknownName(e, beforeDot: beforeDot);
    return null;
  }

  void _unknownName(NameExpr e, {required bool beforeDot}) {
    final later = _proc?.laterLocals[e.name.toLowerCase()];
    if (later != null && later.start > e.start) {
      _proc!.mentionedEarly.add(e.name.toLowerCase());
      _reportAt(
          e, DiagnosticCode.usedBeforeDeclaration, [e.name, '${_line(later)}']);
      return;
    }
    if (beforeDot && form == null) {
      _reportAt(e, DiagnosticCode.unknownNameMaybeControl, [e.name]);
      return;
    }
    final suggestion = _suggest(e.name);
    if (suggestion != null) {
      _reportAt(e, DiagnosticCode.unknownNameDidYouMean, [e.name, suggestion]);
    } else {
      _reportAt(e, DiagnosticCode.unknownName, [e.name]);
    }
  }

  /// The closest visible name, if it is close enough to be a typo.
  String? _suggest(String name) {
    // One- and two-letter names are too short for a useful guess (y → x).
    if (name.length < 3) return null;
    final lower = name.toLowerCase();
    // One edit for names up to 6 letters, two for longer ones: looser
    // limits suggest unrelated names (total → Today).
    final limit = name.length <= 6 ? 1 : 2;
    String? best;
    var bestDistance = limit + 1;
    final candidates = _scope.visible.map((s) => s.name).toSet().toList()
      ..sort();
    for (final candidate in candidates) {
      final d = _editDistance(lower, candidate.toLowerCase());
      if (d < bestDistance) {
        bestDistance = d;
        best = candidate;
      }
    }
    return best;
  }

  GbType _name(NameExpr e, {required bool valueNeeded}) {
    final symbol = _lookupName(e);
    if (symbol == null) return GbType.unknown;
    if (symbol.isCallable) {
      return _implicitCall(e, symbol.callable!, valueNeeded: valueNeeded);
    }
    return symbol.type;
  }

  /// A procedure or method named without parentheses: a call, if it needs
  /// no arguments.
  GbType _implicitCall(Expr e, Callable callable, {required bool valueNeeded}) {
    if (callable.requiredCount > 0) {
      _reportAt(e, DiagnosticCode.wrongArgumentCount,
          [callable.name, _expectedCount(callable), '0']);
      return GbType.unknown;
    }
    _result.implicitCalls.add(e);
    if (callable.isSub && valueNeeded) {
      _reportAt(e, DiagnosticCode.subHasNoValue, [callable.name]);
      return GbType.void_;
    }
    return callable.returnType;
  }

  GbType _member(MemberExpr e,
      {required bool asCall, required bool valueNeeded}) {
    final Map<String, MemberSpec>? members;
    final target = e.target;
    if (target is NameExpr) {
      final symbol = _lookupName(target, beforeDot: true);
      _result.types[target] = symbol?.type ?? GbType.unknown;
      if (symbol == null) return GbType.unknown;
      members = symbol.kind == SymbolKind.builtinObject
          ? builtinObjectMembers(symbol.name)
          : membersOf(symbol.isCallable
              ? _name(target, valueNeeded: true)
              : symbol.type);
    } else {
      members = membersOf(_value(target));
    }
    if (members == null || e.name.name.isEmpty) return GbType.unknown;
    final spec = members[e.name.name.toLowerCase()];
    if (spec == null) {
      _reportAt(e.name, DiagnosticCode.unknownMember,
          [_result.types[target]?.displayName ?? '?', e.name.name]);
      return GbType.unknown;
    }
    _result.members[e] = spec;
    if (spec.isMethod && !asCall) {
      return _implicitCall(e, spec.method!, valueNeeded: valueNeeded);
    }
    return spec.type;
  }

  GbType _invoke(InvokeExpr e, {required bool valueNeeded}) {
    final target = e.target;
    Callable? callable;
    GbType? indexed;

    if (target is NameExpr) {
      final symbol = _lookupName(target);
      if (symbol == null) {
        _analyzeArguments(e.arguments);
        return GbType.unknown;
      }
      if (symbol.isCallable) {
        callable = symbol.callable;
      } else if (symbol.kind == SymbolKind.builtinObject) {
        _reportAt(target, DiagnosticCode.notCallable, [target.name]);
        _analyzeArguments(e.arguments);
        return GbType.unknown;
      } else {
        indexed = symbol.type;
      }
      _result.types[target] = symbol.type;
    } else if (target is MemberExpr) {
      final t = _member(target, asCall: true, valueNeeded: true);
      final spec = _result.members[target];
      if (spec != null && spec.isMethod) {
        callable = spec.method;
      } else {
        indexed = t;
      }
      _result.types[target] = t;
    } else {
      indexed = _value(target);
    }

    if (callable != null) {
      _result.invokeKinds[e] = InvokeKind.call;
      final type = _call(e, callable);
      if (callable.isSub && valueNeeded) {
        _reportAt(e, DiagnosticCode.subHasNoValue, [callable.name]);
        return GbType.void_;
      }
      return type;
    }

    final GbType element;
    switch (indexed) {
      case ListType(element: final el) || ArrayType(element: final el):
        element = el;
        _result.invokeKinds[e] = InvokeKind.item;
      case GbType.object || GbType.unknown || null:
        // Not known: decided at run time, and nothing more to report.
        _analyzeArguments(e.arguments);
        return GbType.unknown;
      default:
        _reportAt(target, DiagnosticCode.notIndexable, [indexed.displayName]);
        _analyzeArguments(e.arguments);
        return GbType.unknown;
    }
    if (e.arguments.length != 1) {
      _reportAt(e, DiagnosticCode.wrongArgumentCount,
          [_text(target), '1', '${e.arguments.length}']);
      _analyzeArguments(e.arguments);
      return element;
    }
    _expect(e.arguments.single, GbType.integer);
    return element;
  }

  void _analyzeArguments(List<Expr> arguments) {
    for (final a in arguments) {
      _value(a);
    }
  }

  String _expectedCount(Callable c) {
    final all = c.parameters.length;
    final required = c.requiredCount;
    return required == all ? '$all' : '$required–$all';
  }

  /// Checks a call's arguments and gives the result type.
  GbType _call(InvokeExpr e, Callable callable) {
    final args = e.arguments;
    final types = [for (final a in args) _value(a)];
    if (args.length < callable.requiredCount ||
        args.length > callable.parameters.length) {
      _reportAt(e, DiagnosticCode.wrongArgumentCount,
          [callable.name, _expectedCount(callable), '${args.length}']);
      return callable.returnType;
    }
    for (var i = 0; i < args.length; i++) {
      _argument(args[i], types[i], callable.parameters[i]);
    }
    return switch (callable.returnKind) {
      ReturnKind.fixed => callable.returnType,
      ReturnKind.sameAsFirstArgument =>
        types.first.isNumeric ? types.first : GbType.unknown,
      ReturnKind.widerOfArguments => types.contains(GbType.double_)
          ? GbType.double_
          : types.every((t) => t == GbType.integer)
              ? GbType.integer
              : GbType.unknown,
    };
  }

  void _argument(Expr arg, GbType type, ParamSpec param) {
    if (type == GbType.unknown || type == GbType.object) return;
    bool ok;
    switch (param.kind) {
      case ArgKind.typed:
        _convert(arg, type, param.type!);
        return;
      case ArgKind.anyValue:
        ok = type != GbType.void_;
      case ArgKind.numeric:
        ok = type.isNumeric;
      case ArgKind.numericOrString:
        ok = type.isNumeric || type == GbType.string;
      case ArgKind.convertible:
        ok = type.isNumeric || type == GbType.string || type == GbType.boolean;
      case ArgKind.array:
        ok = type is ArrayType;
    }
    if (!ok && type != GbType.void_) {
      final expected = switch (param.kind) {
        ArgKind.numeric || ArgKind.numericOrString => GbType.double_,
        ArgKind.array => const ArrayType(GbType.object),
        _ => GbType.string,
      };
      _reportAt(arg, DiagnosticCode.typeMismatch,
          [type.displayName, expected.displayName]);
    }
  }

  GbType _new(NewExpr e) {
    final type = _resolveType(e.type);
    _newArguments(type, e.arguments ?? const [], e);
    return type;
  }

  void _newArguments(GbType type, List<Expr> args, Node at) {
    if (type is ControlType) {
      // Stage 2 (docs/ROADMAP.md): controls created at run time.
      _reportAt(at, DiagnosticCode.newControlNotAvailable, [type.displayName]);
      _analyzeArguments(args);
      return;
    }
    final params = switch (type) {
      ListType() => const <ParamSpec>[],
      GbType.exception => const [
          ParamSpec('message', GbType.string, optional: true)
        ],
      _ => null,
    };
    if (params == null) {
      _analyzeArguments(args);
      return;
    }
    final callable = Callable(type.displayName, params, type);
    if (args.length > params.length) {
      _reportAt(at, DiagnosticCode.wrongArgumentCount,
          [callable.name, _expectedCount(callable), '${args.length}']);
      _analyzeArguments(args);
      return;
    }
    for (var i = 0; i < args.length; i++) {
      _argument(args[i], _value(args[i]), params[i]);
    }
  }

  GbType _unary(UnaryExpr e) {
    final t = _value(e.operand);
    if (t == GbType.unknown) return GbType.unknown;
    final ok = e.operator == UnaryOp.not ? t == GbType.boolean : t.isNumeric;
    if (!ok) {
      _reportAt(e, DiagnosticCode.unaryOperatorNotApplicable,
          [e.operator.symbol, t.displayName]);
      return GbType.unknown;
    }
    return t;
  }

  GbType _binary(BinaryExpr e) {
    final l = _value(e.left);
    final r = _value(e.right);
    final op = e.operator;

    switch (op) {
      case BinaryOp.concat:
        for (final (side, t) in [(e.left, l), (e.right, r)]) {
          if (t.isValueType || t == GbType.object) {
            if (t != GbType.string && t != GbType.object) {
              _result.conversions[side] = GbType.string;
            }
          } else if (t != GbType.unknown && t != GbType.void_) {
            _notApplicable(e, l, r);
          }
        }
        return GbType.string;
      case BinaryOp.equal ||
            BinaryOp.notEqual ||
            BinaryOp.less ||
            BinaryOp.greater ||
            BinaryOp.lessEqual ||
            BinaryOp.greaterEqual ||
            BinaryOp.identity:
        _compare(op, l, r, e);
        return GbType.boolean;
      case BinaryOp.and || BinaryOp.or || BinaryOp.xor:
        if (_eitherUnknown(l, r)) return GbType.boolean;
        if (l != GbType.boolean || r != GbType.boolean) _notApplicable(e, l, r);
        return GbType.boolean;
      default:
        break;
    }

    // Arithmetic.
    if (_eitherUnknown(l, r)) return GbType.unknown;
    if (op == BinaryOp.add && l == GbType.string && r == GbType.string) {
      return GbType.string;
    }
    if (op == BinaryOp.add &&
        ((l == GbType.string && r.isNumeric) ||
            (r == GbType.string && l.isNumeric))) {
      _reportAt(e, DiagnosticCode.stringPlusNumber);
      return GbType.unknown;
    }
    if (!l.isNumeric || !r.isNumeric) {
      _notApplicable(e, l, r);
      return GbType.unknown;
    }
    final bothInteger = l == GbType.integer && r == GbType.integer;
    switch (op) {
      case BinaryOp.divide || BinaryOp.power:
        _widen(e, l, r, toDouble: true);
        return GbType.double_;
      case BinaryOp.integerDivide:
        if (!bothInteger) {
          // H5: \ works on whole numbers only.
          _reportAt(l == GbType.double_ ? e.left : e.right,
              DiagnosticCode.doubleToInteger);
          return GbType.unknown;
        }
        return GbType.integer;
      default:
        _widen(e, l, r, toDouble: !bothInteger);
        return bothInteger ? GbType.integer : GbType.double_;
    }
  }

  /// Records Integer operands that are turned into Double.
  void _widen(BinaryExpr e, GbType l, GbType r, {required bool toDouble}) {
    if (!toDouble) return;
    if (l == GbType.integer) _result.conversions[e.left] = GbType.double_;
    if (r == GbType.integer) _result.conversions[e.right] = GbType.double_;
  }

  bool _eitherUnknown(GbType l, GbType r) =>
      l == GbType.unknown ||
      r == GbType.unknown ||
      l == GbType.void_ ||
      r == GbType.void_;

  void _notApplicable(BinaryExpr e, GbType l, GbType r) => _reportAt(
      e,
      DiagnosticCode.binaryOperatorNotApplicable,
      [e.operator.symbol, l.displayName, r.displayName]);

  /// Whether [l] and [r] can be compared with [op]; reports at [at].
  void _compare(BinaryOp op, GbType l, GbType r, Node at) {
    if (_eitherUnknown(l, r)) return;
    final bool ok;
    if (op == BinaryOp.identity) {
      bool isObject(GbType t) => t.isReferenceType || t == GbType.nothing;
      ok = isObject(l) && isObject(r);
    } else if (l.isNumeric && r.isNumeric) {
      ok = true;
      if (l != r && at is BinaryExpr) _widen(at, l, r, toDouble: true);
    } else if (l == r && (l == GbType.string || l == GbType.date)) {
      ok = true;
    } else if (l == r && l == GbType.boolean) {
      ok = op == BinaryOp.equal || op == BinaryOp.notEqual;
    } else {
      ok = false;
    }
    if (!ok) {
      _reportAt(at, DiagnosticCode.binaryOperatorNotApplicable,
          [op.symbol, l.displayName, r.displayName]);
    }
  }
}

/// Levenshtein distance.
int _editDistance(String a, String b) {
  if (a == b) return 0;
  var previous = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final current = List<int>.filled(b.length + 1, 0)..[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final cost = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      current[j] = [
        previous[j] + 1,
        current[j - 1] + 1,
        previous[j - 1] + cost,
      ].reduce((x, y) => x < y ? x : y);
    }
    previous = current;
  }
  return previous[b.length];
}
