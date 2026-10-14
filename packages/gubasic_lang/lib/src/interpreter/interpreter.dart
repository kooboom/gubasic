import 'dart:async';
import 'dart:math' as math;

import '../analyzer/analysis_result.dart';
import '../analyzer/builtins.dart';
import '../analyzer/compile.dart';
import '../analyzer/conversions.dart';
import '../analyzer/symbols.dart';
import '../analyzer/types.dart';
import '../ast/ast.dart';
import '../ast/line_map.dart';
import '../diagnostics/diagnostic.dart';
import '../diagnostics/messages_en.dart';
import '../lexer/keyword.dart';
import 'checked_math.dart';
import 'host.dart';
import 'rng.dart';
import 'run_result.dart';
import 'values.dart';

/// How deep procedure calls may nest before R009, on every platform.
/// Chosen by measuring the VM and Chrome (see docs/LANGUAGE.md §9).
const int maxCallDepth = 10000;

/// After this many loop rounds and calls, the interpreter lets the screen
/// update (Host.yieldNow). It does not change what the program computes.
const int _stepsPerYield = 1000;

/// Runs an analyzed program (docs/DESIGN.md §3.1).
///
/// Follows the analyzer exactly: names, conversions, call/item decisions
/// and loop variables come from [CompileResult.analysis]. Every call to a
/// user procedure is awaited; expressions without such calls are evaluated
/// synchronously, which computes the same values faster.
class Interpreter {
  Interpreter(
    this.program,
    this.host, {
    this.messages = englishMessages,
    this.callDepthLimit = maxCallDepth,
  })  : _a = program.analysis,
        _lines = LineMap(program.parseResult.source);

  final CompileResult program;
  final Host host;

  /// The language of `ex.Message` for run-time errors caught by `Try`.
  final Map<DiagnosticCode, String> messages;
  final int callDepthLimit;

  final AnalysisResult _a;
  final LineMap _lines;

  final _fields = <Symbol, Object?>{};
  final _statics = <Symbol, Object?>{};
  final _random = GbRandom();
  _Frame _frame = _Frame(null);
  var _depth = 0;
  var _steps = 0;
  var _stopRequested = false;

  /// Asks a running program to stop at its next yield.
  void stop() => _stopRequested = true;

  /// The procedure a run starts with: `Sub Main()`, or else
  /// `Sub Form_Load()`. Null if there is neither.
  ProcedureDecl? get startProcedure {
    for (final name in ['main', 'form_load']) {
      final symbol = _a.fileScope.symbols[name];
      final p = symbol?.procedure;
      if (p != null && !p.isFunction && p.parameters.isEmpty) return p;
    }
    return null;
  }

  Future<RunResult> run() async {
    if (program.hasErrors) {
      return const RunNotStarted(NotStartedReason.hasErrors);
    }
    final start = startProcedure;
    if (start == null) {
      return const RunNotStarted(NotStartedReason.noStartProcedure);
    }
    try {
      for (final member in program.parseResult.unit.members) {
        if (member is FieldDecl) {
          final symbol = _a.symbols[member.declarator.name];
          if (symbol != null) {
            _fields[symbol] = await _initialValue(member.declarator, symbol);
          }
        }
      }
      await _callUser(start, const [], start);
      return const RunCompleted();
    } on _EndProgram {
      return const RunEnded();
    } on _Stop {
      return const RunStopped();
    } on _Failure catch (f) {
      return RunFailed(_diagnostic(f.code, f.node, f.args));
    } on _Thrown catch (t) {
      return RunFailed(_diagnostic(
          DiagnosticCode.unhandledException, t.node, [t.exception.message]));
    }
  }

  Diagnostic _diagnostic(DiagnosticCode code, Node node, List<String> args) {
    final (line, column) = _lines.locate(node.start);
    return Diagnostic(
      code: code,
      line: line,
      column: column,
      offset: node.start,
      length: node.end - node.start,
      args: args,
    );
  }

  Never _fail(DiagnosticCode code, Node node, [List<String> args = const []]) =>
      throw _Failure(code, node, args);

  /// Counts a loop round or a call; true when it is time to yield. Kept
  /// synchronous so that loops do not create a Future every round.
  bool _tick() => ++_steps % _stepsPerYield == 0;

  Future<void> _yield() async {
    await host.yieldNow();
    if (_stopRequested) throw const _Stop();
  }

  /// Runs [block] synchronously when nothing in it waits.
  FutureOr<_Flow> _body(Block block) =>
      _awaits(block) ? _block(block) : _blockSync(block);

  // -------------------------------------------------------------------------
  // Variables

  Object? _read(Symbol symbol) => switch (symbol.storage) {
        Storage.field => _fields[symbol],
        Storage.staticLocal => _statics[symbol],
        _ => _frame.vars[symbol],
      };

  void _write(Symbol symbol, Object? value) {
    switch (symbol.storage) {
      case Storage.field:
        _fields[symbol] = value;
      case Storage.staticLocal:
        _statics[symbol] = value;
      default:
        _frame.vars[symbol] = value;
    }
  }

  /// The value a declaration gives its variable: the initial value, a new
  /// object (`As New`), a sized array, or the type's default.
  Future<Object?> _initialValue(VariableDeclarator d, Symbol symbol) async {
    final type = symbol.type;
    if (d.initializer != null) return _value(d.initializer!);
    if (d.isArray) {
      if (d.arrayBound == null) return null;
      final bound = await _value(d.arrayBound!);
      return _newArray(type, bound, d);
    }
    if (d.isNew) {
      final args = [
        for (final a in d.newArguments ?? const <Expr>[]) await _value(a)
      ];
      return _construct(type, args);
    }
    return defaultValue(type);
  }

  GbArray _newArray(GbType type, Object? bound, Node at) {
    final element = type is ArrayType ? type.element : GbType.unknown;
    final upper = (bound as GbInt).toSmallInt();
    if (upper == null || upper < -1 || upper > 100000000) {
      _fail(DiagnosticCode.invalidArgument, at, ['Dim']);
    }
    return GbArray(element,
        List<Object?>.generate(upper + 1, (_) => defaultValue(element)));
  }

  Object? _construct(GbType type, List<Object?> args) => switch (type) {
        ListType(:final element) => GbList(element),
        GbType.exception =>
          GbException(args.isEmpty ? '' : args.first as String),
        _ => defaultValue(type),
      };

  // -------------------------------------------------------------------------
  // Procedures

  Future<Object?> _callUser(
      ProcedureDecl p, List<Object?> args, Node at) async {
    // Every call starts in a fresh microtask: deep recursion grows the heap,
    // not the platform's call stack (J3).
    await Future<void>.value();
    if (_depth >= callDepthLimit) {
      _fail(DiagnosticCode.callsTooDeep, at, ['$callDepthLimit']);
    }
    if (_tick()) await _yield();
    final saved = _frame;
    final frame = _Frame(p);
    final symbol = _a.symbols[p.name];
    for (var i = 0; i < p.parameters.length; i++) {
      final param = p.parameters[i];
      final paramSymbol = _a.symbols[param.name];
      if (paramSymbol == null) continue;
      if (i < args.length) {
        frame.vars[paramSymbol] = args[i];
      } else {
        _frame = frame; // defaults are evaluated in the callee
        frame.vars[paramSymbol] = param.defaultValue == null
            ? defaultValue(paramSymbol.type)
            : await _value(param.defaultValue!);
        _frame = saved;
      }
    }
    if (p.isFunction) {
      frame.result =
          defaultValue(symbol?.callable?.returnType ?? GbType.unknown);
    }
    _depth++;
    _frame = frame;
    try {
      await _block(p.body);
      return frame.result;
    } catch (_) {
      // Dart passes an error up a chain of awaiting calls synchronously,
      // which overflows the platform stack after about a thousand calls.
      // One microtask per call keeps the stack flat on the way up too.
      await Future<void>.value();
      rethrow;
    } finally {
      _frame = saved;
      _depth--;
    }
  }

  // -------------------------------------------------------------------------
  // Statements

  /// Whether running [node] may need to wait: it calls a user procedure or
  /// MsgBox / InputBox / DoEvents, or contains a loop (which yields).
  bool _awaits(Node node) => _awaitsCache[node] ??= _computeAwaits(node);
  final _awaitsCache = Map<Node, bool>.identity();

  bool _computeAwaits(Node node) {
    switch (node) {
      case ForStmt() || ForEachStmt() || DoLoopStmt() || TryStmt():
        return true;
      case InvokeExpr():
        if (_a.invokeKinds[node] == InvokeKind.call &&
            _callWaits(node.target)) {
          return true;
        }
      case NameExpr() || MemberExpr():
        if (_a.implicitCalls.contains(node) && _callWaits(node as Expr)) {
          return true;
        }
      default:
    }
    return node.children.any(_awaits);
  }

  bool _callWaits(Expr target) {
    if (target is MemberExpr) return false; // built-in methods never wait
    final symbol = _a.symbols[target];
    if (symbol == null) return false;
    if (symbol.kind == SymbolKind.procedure) return true;
    return const {'MsgBox', 'InputBox', 'DoEvents'}.contains(symbol.name);
  }

  Future<_Flow> _block(Block block) async {
    for (final s in block.statements) {
      final flow = _awaits(s) ? await _statementAsync(s) : _statementSync(s);
      if (flow != _Flow.normal) return flow;
    }
    return _Flow.normal;
  }

  _Flow _blockSync(Block block) {
    for (final s in block.statements) {
      final flow = _statementSync(s);
      if (flow != _Flow.normal) return flow;
    }
    return _Flow.normal;
  }

  /// A statement without waits (no loops, no waiting calls inside).
  _Flow _statementSync(Stmt s) {
    switch (s) {
      case LocalDeclStmt():
        _declareSync(s);
      case AssignmentStmt():
        _assign(s.target, _valueSync(s.value), _indexSync);
      case ExpressionStmt():
        _evalSync(s.expression);
      case IfStmt():
        for (final b in s.branches) {
          if (_valueSync(b.condition) as bool) return _blockSync(b.body);
        }
        if (s.elseBlock != null) return _blockSync(s.elseBlock!);
      case SelectStmt():
        final subject = _valueSync(s.subject);
        for (final c in s.cases) {
          if (c.isElse ||
              c.clauses.any((cl) => _caseMatches(cl, subject, _valueSync))) {
            return _blockSync(c.body);
          }
        }
      case ExitStmt():
        return _exitFlow(s);
      case ReturnStmt():
        if (s.value != null) _frame.result = _valueSync(s.value!);
        return _Flow.exitProcedure;
      case TryStmt():
        throw StateError('Try is always run with _statementAsync');
      case ThrowStmt():
        throw _Thrown(_valueSync(s.value)! as GbException, s);
      case ReDimStmt():
        _reDim(s, _valueSync(s.bound));
      case EndStmt():
        throw const _EndProgram();
      case ErrorStmt():
        break;
      case ForStmt() || ForEachStmt() || DoLoopStmt():
        throw StateError('loops are always run with _statementAsync');
    }
    return _Flow.normal;
  }

  Future<_Flow> _statementAsync(Stmt s) async {
    switch (s) {
      case LocalDeclStmt():
        await _declare(s);
      case AssignmentStmt():
        final value = await _value(s.value);
        final index = await _indexAsync(s.target);
        _assign(s.target, value, (_) => index);
      case ExpressionStmt():
        await _eval(s.expression);
      case IfStmt():
        for (final b in s.branches) {
          if (await _value(b.condition) as bool) return _block(b.body);
        }
        if (s.elseBlock != null) return _block(s.elseBlock!);
      case SelectStmt():
        final subject = await _value(s.subject);
        for (final c in s.cases) {
          var matches = c.isElse;
          for (final cl in c.clauses) {
            if (matches) break;
            matches = await _caseMatchesAsync(cl, subject);
          }
          if (matches) return _block(c.body);
        }
      case ForStmt():
        return _for(s);
      case ForEachStmt():
        return _forEach(s);
      case DoLoopStmt():
        return _doLoop(s);
      case TryStmt():
        return _try(s);
      case ReturnStmt():
        if (s.value != null) _frame.result = await _value(s.value!);
        return _Flow.exitProcedure;
      case ThrowStmt():
        throw _Thrown((await _value(s.value))! as GbException, s);
      case ReDimStmt():
        _reDim(s, await _value(s.bound));
      default:
        return _statementSync(s);
    }
    return _Flow.normal;
  }

  _Flow _exitFlow(ExitStmt s) => switch (s.kind) {
        Keyword.kwFor => _Flow.exitFor,
        Keyword.kwDo => _Flow.exitDo,
        _ => _Flow.exitProcedure,
      };

  void _declareSync(LocalDeclStmt s) {
    final symbol = _a.symbols[s.declarator.name];
    if (symbol == null) return;
    if (s.kind == Keyword.kwStatic && _statics.containsKey(symbol)) return;
    final d = s.declarator;
    final Object? value;
    if (d.initializer != null) {
      value = _valueSync(d.initializer!);
    } else if (d.isArray) {
      value = d.arrayBound == null
          ? null
          : _newArray(symbol.type, _valueSync(d.arrayBound!), d);
    } else if (d.isNew) {
      value = _construct(symbol.type,
          [for (final a in d.newArguments ?? const <Expr>[]) _valueSync(a)]);
    } else {
      value = defaultValue(symbol.type);
    }
    _write(symbol, value);
  }

  Future<void> _declare(LocalDeclStmt s) async {
    final symbol = _a.symbols[s.declarator.name];
    if (symbol == null) return;
    if (s.kind == Keyword.kwStatic && _statics.containsKey(symbol)) return;
    _write(symbol, await _initialValue(s.declarator, symbol));
  }

  Future<_Flow> _for(ForStmt s) async {
    final variable = _a.loopVariables[s]!;
    final from = await _value(s.from);
    final to = await _value(s.to);
    final step = s.step == null ? null : await _value(s.step!);
    final isInteger = variable.type == GbType.integer;
    final stepValue = step ?? (isInteger ? GbInt.one : 1.0);
    final ascending = isInteger
        ? !(stepValue as GbInt).isNegative
        : (stepValue as double) >= 0;
    _write(variable, from);
    while (true) {
      final current = _read(variable);
      final cmp = _compareNumbers(current, to);
      if (ascending ? cmp > 0 : cmp < 0) break;
      final run = _body(s.body);
      final flow = run is Future<_Flow> ? await run : run;
      if (flow == _Flow.exitFor) break;
      if (flow != _Flow.normal) return flow;
      if (_tick()) await _yield();
      final now = _read(variable);
      if (isInteger) {
        final next = (now as GbInt) + (stepValue as GbInt);
        if (next == null) _fail(DiagnosticCode.integerOverflow, s.variable);
        _write(variable, next);
      } else {
        _write(variable, (now as double) + (stepValue as double));
      }
    }
    return _Flow.normal;
  }

  Future<_Flow> _forEach(ForEachStmt s) async {
    final variable = _a.loopVariables[s]!;
    final collection = await _value(s.collection);
    final List<Object?> items = switch (collection) {
      GbList l => List.of(l.items), // a snapshot: changes do not disturb
      GbArray a => List.of(a.items),
      null => _fail(DiagnosticCode.nothingReference, s.collection),
      _ => _fail(DiagnosticCode.memberNotFound, s.collection,
          ['For Each', typeNameOf(collection)]),
    };
    for (final item in items) {
      _write(variable, item);
      final run = _body(s.body);
      final flow = run is Future<_Flow> ? await run : run;
      if (flow == _Flow.exitFor) break;
      if (flow != _Flow.normal) return flow;
      if (_tick()) await _yield();
    }
    return _Flow.normal;
  }

  Future<_Flow> _doLoop(DoLoopStmt s) async {
    FutureOr<bool> keepGoing(LoopCondition? c) {
      if (c == null) return true;
      bool decide(Object? v) => c.isUntil ? !(v as bool) : v as bool;
      final value = _value(c.condition);
      return value is Future<Object?> ? value.then(decide) : decide(value);
    }

    while (true) {
      final pre = keepGoing(s.preCondition);
      if (!(pre is Future<bool> ? await pre : pre)) break;
      final run = _body(s.body);
      final flow = run is Future<_Flow> ? await run : run;
      if (flow == _Flow.exitDo) break;
      if (flow != _Flow.normal) return flow;
      if (_tick()) await _yield();
      final post = keepGoing(s.postCondition);
      if (!(post is Future<bool> ? await post : post)) break;
    }
    return _Flow.normal;
  }

  Future<_Flow> _try(TryStmt s) async {
    try {
      return await _block(s.body);
    } on _Thrown catch (t) {
      if (s.catches.isEmpty) rethrow;
      return _catch(s, t.exception);
    } on _Failure catch (f) {
      if (s.catches.isEmpty) rethrow;
      // A run-time error caught by Try: its message, in the language of
      // the run (I3).
      final d = _diagnostic(f.code, f.node, f.args);
      return _catch(s, GbException(d.formatMessage(messages)));
    } finally {
      if (s.finallyBlock != null) {
        // A Finally block cannot leave the procedure early.
        await _block(s.finallyBlock!);
      }
    }
  }

  Future<_Flow> _catch(TryStmt s, GbException exception) async {
    final c = s.catches.first;
    if (c.name != null) {
      final symbol = _a.symbols[c.name!];
      if (symbol != null) _write(symbol, exception);
    }
    return _block(c.body);
  }

  void _reDim(ReDimStmt s, Object? bound) {
    final symbol = _a.symbols[s.name]!;
    final old = _read(symbol);
    final fresh = _newArray(symbol.type, bound, s);
    if (s.preserve && old is GbArray) {
      for (var i = 0; i < fresh.items.length && i < old.items.length; i++) {
        fresh.items[i] = old.items[i];
      }
    }
    _write(symbol, fresh);
  }

  bool _caseMatches(
      CaseClause clause, Object? subject, Object? Function(Expr) eval) {
    return switch (clause) {
      ValueClause(:final value) => valuesEqual(subject, eval(value)),
      RangeClause(:final low, :final high) =>
        _compare(subject, eval(low), clause) >= 0 &&
            _compare(subject, eval(high), clause) <= 0,
      RelationalClause(:final operator, :final value) =>
        _relation(operator, subject, eval(value), clause),
    };
  }

  Future<bool> _caseMatchesAsync(CaseClause clause, Object? subject) async =>
      switch (clause) {
        ValueClause(:final value) => valuesEqual(subject, await _value(value)),
        RangeClause(:final low, :final high) =>
          _compare(subject, await _value(low), clause) >= 0 &&
              _compare(subject, await _value(high), clause) <= 0,
        RelationalClause(:final operator, :final value) =>
          _relation(operator, subject, await _value(value), clause),
      };

  // -------------------------------------------------------------------------
  // Assignment

  /// The item number of an item target (`a(i) = …`), evaluated before the
  /// assignment; null for other targets.
  Object? _indexSync(Expr target) =>
      target is InvokeExpr && target.arguments.isNotEmpty
          ? _valueSync(target.arguments.first)
          : null;

  Future<Object?> _indexAsync(Expr target) async =>
      target is InvokeExpr && target.arguments.isNotEmpty
          ? await _value(target.arguments.first)
          : null;

  void _assign(Expr target, Object? value, Object? Function(Expr) index) {
    switch (target) {
      case NameExpr():
        _write(_a.symbols[target]!, value);
      case InvokeExpr():
        final container = _evalSync(target.target);
        _setItem(container, index(target), value, target);
      case MemberExpr():
        final receiver = _evalSync(target.target);
        _fail(
            receiver == null
                ? DiagnosticCode.nothingReference
                : DiagnosticCode.memberNotFound,
            target,
            [target.name.name, typeNameOf(receiver)]);
      default:
        throw StateError('not assignable: $target');
    }
  }

  // -------------------------------------------------------------------------
  // Expressions

  /// [e]'s value after the automatic conversion the analyzer recorded.
  FutureOr<Object?> _value(Expr e) {
    final raw = _eval(e);
    return raw is Future<Object?>
        ? raw.then((v) => _convert(e, v))
        : _convert(e, raw);
  }

  Object? _valueSync(Expr e) => _convert(e, _evalSync(e));

  Object? _convert(Expr e, Object? value) {
    final target = _a.conversions[e];
    if (target == null) return value;
    if (target == GbType.double_ && isGbInt(value)) {
      return (value as GbInt).toDouble();
    }
    if (target == GbType.string && value is! String) return formatValue(value);
    return value;
  }

  FutureOr<Object?> _eval(Expr e) => _awaits(e) ? _evalAsync(e) : _evalSync(e);

  Object? _evalSync(Expr e) {
    switch (e) {
      case IntegerLiteral():
        return GbInt.parse(e.text);
      case DoubleLiteral():
        return e.value;
      case StringLiteral():
        return e.value;
      case BooleanLiteral():
        return e.value;
      case NothingLiteral():
        return null;
      case NameExpr():
        final symbol = _a.symbols[e]!;
        if (_a.implicitCalls.contains(e)) {
          return _callBuiltinSync(symbol.callable!, const [], e);
        }
        return _read(symbol);
      case MemberExpr():
        return _member(e, _memberReceiverSync(e), const []);
      case InvokeExpr():
        final args = [for (final a in e.arguments) _valueSync(a)];
        return _invoke(e, args, _memberReceiverSync);
      case NewExpr():
        return _construct(_a.types[e] ?? GbType.unknown,
            [for (final a in e.arguments ?? const <Expr>[]) _valueSync(a)]);
      case UnaryExpr():
        return _unary(e, _valueSync(e.operand));
      case BinaryExpr():
        final op = e.operator;
        final left = _valueSync(e.left);
        if (op == BinaryOp.and && left == false) return false;
        if (op == BinaryOp.or && left == true) return true;
        return _binary(e, left, _valueSync(e.right));
      case ParenExpr():
        return _valueSync(e.inner);
      case MeExpr() || ErrorExpr():
        throw StateError('not runnable: $e'); // analyzer reported it
    }
  }

  Future<Object?> _evalAsync(Expr e) async {
    switch (e) {
      case NameExpr():
        final symbol = _a.symbols[e]!;
        return _callNamed(symbol, const [], e);
      case MemberExpr():
        final receiver = await _memberReceiverAsync(e);
        return _member(e, receiver, const []);
      case InvokeExpr():
        final args = [for (final a in e.arguments) await _value(a)];
        final target = e.target;
        if (_a.invokeKinds[e] == InvokeKind.call && target is NameExpr) {
          return _callNamed(_a.symbols[target]!, args, e);
        }
        final receiver =
            target is MemberExpr ? await _memberReceiverAsync(target) : null;
        return _invoke(e, args, (_) => receiver,
            container: target is MemberExpr ? null : await _value(target));
      case NewExpr():
        return _construct(_a.types[e] ?? GbType.unknown,
            [for (final a in e.arguments ?? const <Expr>[]) await _value(a)]);
      case UnaryExpr():
        return _unary(e, await _value(e.operand));
      case BinaryExpr():
        final op = e.operator;
        final left = await _value(e.left);
        if (op == BinaryOp.and && left == false) return false;
        if (op == BinaryOp.or && left == true) return true;
        return _binary(e, left, await _value(e.right));
      case ParenExpr():
        return _value(e.inner);
      default:
        return _evalSync(e);
    }
  }

  /// Calls a user procedure or built-in function by its symbol.
  Future<Object?> _callNamed(Symbol symbol, List<Object?> args, Node at) {
    if (symbol.kind == SymbolKind.procedure) {
      return _callUser(symbol.procedure!, args, at);
    }
    return Future.value(_callBuiltin(symbol.callable!, args, at));
  }

  Object? _memberReceiverSync(Expr target) {
    final t = target is MemberExpr ? target.target : target;
    if (t is NameExpr && _a.symbols[t]?.kind == SymbolKind.builtinObject) {
      return _BuiltinObject(_a.symbols[t]!.name);
    }
    return _valueSync(t);
  }

  Future<Object?> _memberReceiverAsync(Expr target) async {
    final t = target is MemberExpr ? target.target : target;
    if (t is NameExpr && _a.symbols[t]?.kind == SymbolKind.builtinObject) {
      return _BuiltinObject(_a.symbols[t]!.name);
    }
    return _value(t);
  }

  /// `target(args)`: a call or an item.
  Object? _invoke(
      InvokeExpr e, List<Object?> args, Object? Function(Expr) receiverOf,
      {Object? container}) {
    final target = e.target;
    final kind = _a.invokeKinds[e];
    if (kind == InvokeKind.call) {
      if (target is NameExpr) {
        return _callBuiltinSync(_a.symbols[target]!.callable!, args, e);
      }
      if (target is MemberExpr) {
        return _member(target, receiverOf(target), args, at: e);
      }
    }
    // An item, decided by the analyzer or (through Object) at run time.
    final c = container ??
        (target is MemberExpr
            ? _member(target, receiverOf(target), const [])
            : _evalSync(target));
    return _getItem(c, args.isEmpty ? null : args.first, e);
  }

  int _itemIndex(List<Object?> items, Object? index, Node at) {
    final i = (index as GbInt).toSmallInt();
    if (i == null || i < 0 || i >= items.length) {
      _fail(DiagnosticCode.indexOutOfRange, at,
          [index.format(), '${items.length}']);
    }
    return i;
  }

  Object? _getItem(Object? container, Object? index, Node at) =>
      switch (container) {
        GbList l => l.items[_itemIndex(l.items, index, at)],
        GbArray a => a.items[_itemIndex(a.items, index, at)],
        null => _fail(DiagnosticCode.nothingReference, at),
        _ => _fail(DiagnosticCode.memberNotFound, at,
            ['(item)', typeNameOf(container)]),
      };

  void _setItem(Object? container, Object? index, Object? value, Node at) {
    switch (container) {
      case GbList l:
        l.items[_itemIndex(l.items, index, at)] = value;
      case GbArray a:
        a.items[_itemIndex(a.items, index, at)] = value;
      case null:
        _fail(DiagnosticCode.nothingReference, at);
      default:
        _fail(DiagnosticCode.memberNotFound, at,
            ['(item)', typeNameOf(container)]);
    }
  }

  Object? _unary(UnaryExpr e, Object? v) {
    switch (e.operator) {
      case UnaryOp.not:
        return !(v as bool);
      case UnaryOp.plus:
        return v;
      case UnaryOp.negate:
        if (isGbInt(v)) {
          return (v as GbInt).negate() ??
              _fail(DiagnosticCode.integerOverflow, e);
        }
        return -(v as double);
    }
  }

  Object? _binary(BinaryExpr e, Object? l, Object? r) {
    switch (e.operator) {
      case BinaryOp.and:
        return (l as bool) && (r as bool);
      case BinaryOp.or:
        return (l as bool) || (r as bool);
      case BinaryOp.xor:
        return (l as bool) != (r as bool);
      case BinaryOp.concat:
        return formatValue(l) + formatValue(r);
      case BinaryOp.identity:
        return identical(l, r) || (l == null && r == null);
      case BinaryOp.equal ||
            BinaryOp.notEqual ||
            BinaryOp.less ||
            BinaryOp.greater ||
            BinaryOp.lessEqual ||
            BinaryOp.greaterEqual:
        return _relation(e.operator, l, r, e);
      default:
    }
    if (l is String && r is String) return l + r; // + on two Strings
    if (isGbInt(l) && isGbInt(r)) return _integerOp(e, l as GbInt, r as GbInt);
    final a = toDoubleValue(l), b = toDoubleValue(r);
    switch (e.operator) {
      case BinaryOp.add:
        return a + b;
      case BinaryOp.subtract:
        return a - b;
      case BinaryOp.multiply:
        return a * b;
      case BinaryOp.divide:
        if (b == 0) _fail(DiagnosticCode.divisionByZero, e);
        return a / b;
      case BinaryOp.power:
        return math.pow(a, b).toDouble();
      case BinaryOp.modulo:
        if (b == 0) _fail(DiagnosticCode.divisionByZero, e);
        return a.remainder(b);
      default:
        throw StateError('operator ${e.operator} on $l, $r');
    }
  }

  Object? _integerOp(BinaryExpr e, GbInt a, GbInt b) {
    final GbInt? result;
    switch (e.operator) {
      case BinaryOp.add:
        result = a + b;
      case BinaryOp.subtract:
        result = a - b;
      case BinaryOp.multiply:
        result = a * b;
      case BinaryOp.integerDivide:
        if (b.isZero) _fail(DiagnosticCode.divisionByZero, e);
        result = a.quotient(b);
      case BinaryOp.modulo:
        if (b.isZero) _fail(DiagnosticCode.divisionByZero, e);
        result = a.remainder(b);
      default:
        throw StateError('integer operator ${e.operator}');
    }
    return result ?? _fail(DiagnosticCode.integerOverflow, e);
  }

  bool _relation(BinaryOp op, Object? l, Object? r, Node at) {
    if (op == BinaryOp.equal) return valuesEqual(l, r);
    if (op == BinaryOp.notEqual) return !valuesEqual(l, r);
    final c = _compare(l, r, at);
    return switch (op) {
      BinaryOp.less => c < 0,
      BinaryOp.greater => c > 0,
      BinaryOp.lessEqual => c <= 0,
      BinaryOp.greaterEqual => c >= 0,
      _ => throw StateError('$op'),
    };
  }

  int _compare(Object? l, Object? r, Node at) {
    if (l is String && r is String) return l.compareTo(r);
    if (l is DateTime && r is DateTime) return l.compareTo(r);
    return _compareNumbers(l, r);
  }

  int _compareNumbers(Object? l, Object? r) {
    if (isGbInt(l) && isGbInt(r)) return (l as GbInt).compareTo(r as GbInt);
    return toDoubleValue(l).compareTo(toDoubleValue(r));
  }

  // -------------------------------------------------------------------------
  // Members of built-in types and objects

  Object? _member(MemberExpr e, Object? receiver, List<Object?> args,
      {Node? at}) {
    final name = e.name.name.toLowerCase();
    final node = at ?? e;
    switch (receiver) {
      case _BuiltinObject(name: 'Debug'):
        host.debugPrint(formatValue(args.first));
        return null;
      case _BuiltinObject(name: 'Integer'):
        return name == 'maxvalue' ? GbInt.maxValue : GbInt.minValue;
      case null:
        _fail(DiagnosticCode.nothingReference, node);
      case GbList l:
        return _listMember(l, name, args, node, e);
      case GbArray a when name == 'length':
        return GbInt.of(a.items.length);
      case String s:
        return _stringMember(s, name, args, node, e);
      case GbException ex when name == 'message':
        return ex.message;
      default:
    }
    _fail(DiagnosticCode.memberNotFound, node,
        [e.name.name, typeNameOf(receiver)]);
  }

  Object? _listMember(
      GbList l, String name, List<Object?> args, Node at, MemberExpr e) {
    final items = l.items;
    switch (name) {
      case 'count':
        return GbInt.of(items.length);
      case 'add':
        items.add(args[0]);
        return null;
      case 'insert':
        final i = (args[0] as GbInt).toSmallInt();
        if (i == null || i < 0 || i > items.length) {
          _fail(DiagnosticCode.indexOutOfRange, at,
              [(args[0] as GbInt).format(), '${items.length}']);
        }
        items.insert(i, args[1]);
        return null;
      case 'remove':
        final i = items.indexWhere((x) => valuesEqual(x, args[0]));
        if (i < 0) return false;
        items.removeAt(i);
        return true;
      case 'removeat':
        items.removeAt(_itemIndex(items, args[0], at));
        return null;
      case 'clear':
        items.clear();
        return null;
      case 'contains':
        return items.any((x) => valuesEqual(x, args[0]));
      case 'indexof':
        return GbInt.of(items.indexWhere((x) => valuesEqual(x, args[0])));
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, typeNameOf(l)]);
  }

  Object? _stringMember(
      String s, String name, List<Object?> args, Node at, MemberExpr e) {
    String text(int i) => args[i] as String;
    switch (name) {
      case 'length':
        return GbInt.of(s.length);
      case 'substring':
        final start = (args[0] as GbInt).toSmallInt();
        if (start == null || start < 0 || start > s.length) {
          _fail(DiagnosticCode.indexOutOfRange, at,
              [(args[0] as GbInt).format(), '${s.length}']);
        }
        if (args.length < 2) return s.substring(start);
        final length = (args[1] as GbInt).toSmallInt();
        if (length == null || length < 0 || start + length > s.length) {
          _fail(DiagnosticCode.invalidArgument, at, ['Substring']);
        }
        return s.substring(start, start + length);
      case 'indexof':
        return GbInt.of(s.indexOf(text(0)));
      case 'contains':
        return s.contains(text(0));
      case 'startswith':
        return s.startsWith(text(0));
      case 'endswith':
        return s.endsWith(text(0));
      case 'replace':
        return text(0).isEmpty ? s : s.replaceAll(text(0), text(1));
      case 'toupper':
        return s.toUpperCase();
      case 'tolower':
        return s.toLowerCase();
      case 'trim':
        return s.trim();
      case 'split':
        return GbArray(GbType.string, s.split(text(0)));
    }
    _fail(DiagnosticCode.memberNotFound, at, [e.name.name, 'String']);
  }

  // -------------------------------------------------------------------------
  // Built-in functions (docs/LANGUAGE.md §10)

  /// A built-in that does not wait (all but MsgBox, InputBox, DoEvents).
  Object? _callBuiltinSync(Callable f, List<Object?> args, Node at) {
    final result = _callBuiltin(f, args, at);
    if (result is Future) {
      throw StateError('${f.name} waits; it must be called with await');
    }
    return result;
  }

  FutureOr<Object?> _callBuiltin(Callable f, List<Object?> args, Node at) {
    String s(int i) => args[i] as String;
    GbInt n(int i) => args[i] as GbInt;
    int small(int i, String fn) {
      final v = n(i).toSmallInt();
      if (v == null) _fail(DiagnosticCode.invalidArgument, at, [fn]);
      return v;
    }

    switch (f.name) {
      // Text (positions count from 1)
      case 'Len':
        return GbInt.of(s(0).length);
      case 'Left':
        final count = small(1, 'Left');
        if (count < 0) _fail(DiagnosticCode.invalidArgument, at, ['Left']);
        return s(0).substring(0, math.min(count, s(0).length));
      case 'Right':
        final count = small(1, 'Right');
        if (count < 0) _fail(DiagnosticCode.invalidArgument, at, ['Right']);
        final text = s(0);
        return text.substring(text.length - math.min(count, text.length));
      case 'Mid':
        final text = s(0);
        final start = small(1, 'Mid');
        if (start < 1) _fail(DiagnosticCode.invalidArgument, at, ['Mid']);
        final from = math.min(start - 1, text.length);
        if (args.length < 3) return text.substring(from);
        final length = small(2, 'Mid');
        if (length < 0) _fail(DiagnosticCode.invalidArgument, at, ['Mid']);
        return text.substring(from, math.min(from + length, text.length));
      case 'InStr':
        return GbInt.of(s(0).indexOf(s(1)) + 1);
      case 'UCase':
        return s(0).toUpperCase();
      case 'LCase':
        return s(0).toLowerCase();
      case 'Trim':
        return s(0).trim();
      case 'Replace':
        return s(1).isEmpty ? s(0) : s(0).replaceAll(s(1), s(2));
      case 'Split':
        return GbArray(GbType.string, s(0).split(s(1)));
      case 'Join':
        final items = args[0];
        if (items == null) _fail(DiagnosticCode.nothingReference, at);
        return (items as GbArray).items.map(formatValue).join(s(1));

      // Conversion
      case 'CInt':
        return _toInteger(args[0], at);
      case 'CDbl':
        return _toDouble(args[0], at);
      case 'CStr' || 'Str':
        return formatValue(args[0]);
      case 'CBool':
        return _toBoolean(args[0], at);
      case 'Val':
        return _val(s(0));

      // Math
      case 'Abs':
        final v = args[0];
        if (isGbInt(v)) {
          return (v as GbInt).abs() ??
              _fail(DiagnosticCode.integerOverflow, at);
        }
        return (v as double).abs();
      case 'Int':
        return _wholeToInteger((args[0] as double).floorToDouble(), at);
      case 'Round':
        final digits = args.length > 1 ? small(1, 'Round') : 0;
        return roundToDigits(args[0] as double, digits) ??
            _fail(DiagnosticCode.invalidArgument, at, ['Round']);
      case 'Sqr':
        final v = args[0] as double;
        if (v < 0) _fail(DiagnosticCode.invalidArgument, at, ['Sqr']);
        return math.sqrt(v);
      case 'Rnd':
        return _random.next();
      case 'Randomize':
        _random.seed(args.isEmpty ? timeSeed() : n(0));
        return null;
      case 'Min' || 'Max':
        final a = args[0], b = args[1];
        final aFirst = f.name == 'Min'
            ? _compareNumbers(a, b) <= 0
            : _compareNumbers(a, b) >= 0;
        final pick = aFirst ? a : b;
        // Mixed Integer and Double give a Double (as the analyzer typed it).
        return isGbInt(a) && isGbInt(b) ? pick : toDoubleValue(pick);

      // Arrays
      case 'UBound':
        final a = args[0];
        if (a == null) _fail(DiagnosticCode.nothingReference, at);
        return GbInt.of((a as GbArray).items.length - 1);

      // Date and time
      case 'Now':
        return DateTime.now();
      case 'Today':
        final now = DateTime.now();
        return DateTime(now.year, now.month, now.day);
      case 'Year':
        return GbInt.of((args[0] as DateTime).year);
      case 'Month':
        return GbInt.of((args[0] as DateTime).month);
      case 'Day':
        return GbInt.of((args[0] as DateTime).day);
      case 'Hour':
        return GbInt.of((args[0] as DateTime).hour);
      case 'Minute':
        return GbInt.of((args[0] as DateTime).minute);
      case 'Second':
        return GbInt.of((args[0] as DateTime).second);

      // Dialogs and program
      case 'MsgBox':
        return host.msgBox(s(0), args.length > 1 ? s(1) : '');
      case 'InputBox':
        return host.inputBox(
            s(0), args.length > 1 ? s(1) : '', args.length > 2 ? s(2) : '');
      case 'DoEvents':
        return host.yieldNow().then((_) {
          if (_stopRequested) throw const _Stop();
          return null;
        });
    }
    // SaveSetting / GetSetting are refused by the analyzer (A029).
    throw StateError('built-in ${f.name} is not available');
  }

  GbInt _toInteger(Object? v, Node at) {
    if (isGbInt(v)) return v as GbInt;
    if (isGbDouble(v)) return _roundDouble(toDoubleValue(v), at);
    if (v is String) {
      final text = v.trim();
      if (RegExp(r'^[+-]?\d+$').hasMatch(text)) {
        return GbInt.parse(text) ?? _fail(DiagnosticCode.integerOverflow, at);
      }
      final d = double.tryParse(text);
      if (d == null || !d.isFinite) {
        _fail(DiagnosticCode.conversionFailed, at, [v, 'Integer']);
      }
      return _roundDouble(d, at);
    }
    _fail(DiagnosticCode.conversionFailed, at, [formatValue(v), 'Integer']);
  }

  /// CInt: half away from zero (2.5 → 3, -2.5 → -3).
  GbInt _roundDouble(double d, Node at) =>
      _wholeToInteger(d.roundToDouble(), at);

  /// A whole-number Double as an Integer, exactly, or R001.
  GbInt _wholeToInteger(double whole, Node at) {
    if (!whole.isFinite ||
        whole >= 9223372036854775808.0 ||
        whole < -9223372036854775808.0) {
      _fail(DiagnosticCode.integerOverflow, at);
    }
    return GbInt.fromWholeDouble(whole);
  }

  double _toDouble(Object? v, Node at) {
    if (isGbInt(v) || isGbDouble(v)) return toDoubleValue(v);
    if (v is String) {
      final d = double.tryParse(v.trim());
      if (d == null) _fail(DiagnosticCode.conversionFailed, at, [v, 'Double']);
      return d;
    }
    _fail(DiagnosticCode.conversionFailed, at, [formatValue(v), 'Double']);
  }

  bool _toBoolean(Object? v, Node at) {
    if (v is bool) return v;
    if (isGbInt(v)) return !(v as GbInt).isZero;
    if (isGbDouble(v)) return toDoubleValue(v) != 0;
    if (v is String) {
      switch (v.trim().toLowerCase()) {
        case 'true':
          return true;
        case 'false':
          return false;
      }
    }
    _fail(DiagnosticCode.conversionFailed, at, [formatValue(v), 'Boolean']);
  }

  /// `Val`: the number at the start of the text, or 0.
  double _val(String text) {
    final m =
        RegExp(r'^\s*([+-]?(\d+\.?\d*|\.\d+)([eE][+-]?\d+)?)').firstMatch(text);
    return m == null ? 0.0 : double.parse(m[1]!);
  }
}

enum _Flow { normal, exitFor, exitDo, exitProcedure }

class _Frame {
  _Frame(this.procedure);

  final ProcedureDecl? procedure;
  final Map<Symbol, Object?> vars = Map.identity();
  Object? result;
}

class _BuiltinObject {
  const _BuiltinObject(this.name);
  final String name;
}

class _Failure implements Exception {
  _Failure(this.code, this.node, this.args);
  final DiagnosticCode code;
  final Node node;
  final List<String> args;
}

class _Thrown implements Exception {
  _Thrown(this.exception, this.node);
  final GbException exception;
  final Node node;
}

class _EndProgram implements Exception {
  const _EndProgram();
}

class _Stop implements Exception {
  const _Stop();
}

/// Runs [source] (compile + interpret) with [host].
Future<RunResult> runProgram(String source, Host host,
        {Map<DiagnosticCode, String> messages = englishMessages}) =>
    Interpreter(compile(source), host, messages: messages).run();
