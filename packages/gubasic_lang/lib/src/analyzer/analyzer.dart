import '../ast/ast.dart';
import '../ast/line_map.dart';
import '../components/http_component.dart' show looksLikeSecretHeader;
import '../components/web_socket_component.dart' show isPlainRemoteWebSocket;
import '../diagnostics/diagnostic.dart';
import '../forms/anchor.dart';
import '../forms/component.dart';
import '../forms/form_file.dart';
import '../forms/pictures.dart';
import '../forms/shortcut.dart';
import '../lexer/keyword.dart';
import '../parser/parse_result.dart';
import '../parser/parser.dart' show formStatements;
import 'analysis_result.dart';
import 'builtins.dart';
import 'conversions.dart';
import 'forms.dart';
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
///
/// [pictures] are the project's pictures: text given to a picture property
/// that names none of them is reported (A037). Without them it is not
/// checked.
///
/// [forms] are the project's forms, [form] among them, by lower-case name
/// ([formInterfaces]): the code can then use them by name, `Form2.Show`,
/// and their controls, `Public` variables and procedures (D88).
///
/// [modules] are the project's modules, by lower-case name (D102): their
/// `Public` names can be used anywhere, also with the module's name, and
/// their Structures are the project's types (D131). [moduleName] is the
/// module the code is, when it is one: its own entry in [modules] is
/// then the code itself.
AnalysisResult analyze(
  ParseResult parsed, {
  FormFile? form,
  List<String>? pictures,
  Map<String, FormInterface>? forms,
  Map<String, ModuleInterface>? modules,
  String? moduleName,
}) =>
    _Analyzer(parsed, form, pictures, forms, modules, moduleName).run();

/// Analyzes [expression] (parsed from [parsed]'s source) in [scope], for
/// the debugger's Immediate window (docs/DESIGN.md D128): the scope is a
/// paused procedure's, the symbols of its frame over its file's scope, so
/// that names mean what they mean there. The result's diagnostics say
/// what is wrong; its maps annotate the expression for the interpreter.
AnalysisResult analyzeExpression(
  ParseResult parsed,
  Expr expression, {
  required Scope scope,
  FormFile? form,
  List<String>? pictures,
  Map<String, FormInterface>? forms,
  Map<String, ModuleInterface>? modules,
}) {
  final analyzer = _Analyzer(parsed, form, pictures, forms, modules, null)
    .._scope = scope;
  analyzer._value(expression);
  return analyzer._result;
}

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
  _Analyzer(this.parsed, this.form, List<String>? pictures, this.forms,
      this.modules, String? moduleName)
      : _lines = LineMap(parsed.source),
        _builtins = Scope(ScopeKind.builtins, null) {
    for (final f in builtinFunctions.values) {
      _builtins.declare(Symbol(
          name: f.name,
          kind: SymbolKind.builtinFunction,
          type: f.returnType,
          callable: f));
    }
    for (final name in builtinConstants.keys) {
      _builtins.declare(
          Symbol(name: name, kind: SymbolKind.constant, type: GbType.string));
    }
    for (final name in allBuiltinObjects) {
      _builtins.declare(Symbol(
          name: name,
          kind: SymbolKind.builtinObject,
          type: GbType.builtinObject));
    }
    Scope outer = _builtins;
    final modules = this.modules ?? const {};
    // The project's Structures (D131): the other modules'.
    for (final m in modules.values) {
      if (m.name.toLowerCase() == moduleName?.toLowerCase()) continue;
      for (final t in m.structures.values) {
        _projectStructures.putIfAbsent(t.name.toLowerCase(), () => (t, m.name));
      }
    }
    if (modules.isNotEmpty) {
      // The modules' Public names (D102); a name two of them have is
      // written with its module's name.
      outer = Scope(ScopeKind.modules, _builtins);
      for (final m in modules.values) {
        for (final s in [...m.variables.values, ...m.procedures.values]) {
          final key = s.name.toLowerCase();
          if (outer.symbols[key] case final other?) {
            _ambiguous.putIfAbsent(key, () => [_moduleOf[other]!]).add(m.name);
            if (other.kind != SymbolKind.ambiguous) {
              outer.declare(Symbol(
                  name: s.name,
                  kind: SymbolKind.ambiguous,
                  type: GbType.unknown));
            }
          } else {
            outer.declare(s);
            _moduleOf[s] = m.name;
          }
        }
      }
    }
    final forms = this.forms;
    if (forms != null || modules.isNotEmpty) {
      outer = Scope(ScopeKind.project, outer);
      for (final f in forms?.values ?? const <FormInterface>[]) {
        outer.declare(Symbol(
            name: f.name,
            kind: SymbolKind.form,
            type: ControlType(formComponent, form: f)));
      }
      for (final m in modules.values) {
        outer.declare(
            Symbol(name: m.name, kind: SymbolKind.module, type: ModuleType(m)));
      }
    }
    final form = this.form;
    if (form != null) {
      _controls = outer = Scope(ScopeKind.form, outer);
      for (final c in form.controls) {
        _controls!.declare(Symbol(
            name: c.name, kind: SymbolKind.control, type: c.component.type));
      }
    }
    _file = Scope(ScopeKind.file, outer);
    _result = AnalysisResult(
      diagnostics: _diagnostics,
      fileScope: _file,
      form: form,
      pictures: pictures == null
          ? null
          : {for (final p in pictures) pictureKey(p): p},
    );
    for (final MapEntry(:key, value: (type, _)) in _projectStructures.entries) {
      _result.projectStructures[key] = type;
    }
  }

  final ParseResult parsed;
  final FormFile? form;

  /// The project's forms, by lower-case name (D88).
  final Map<String, FormInterface>? forms;

  /// The project's modules, by lower-case name (D102).
  final Map<String, ModuleInterface>? modules;

  /// The module each Public name of [modules] is from.
  final _moduleOf = Map<Symbol, String>.identity();

  /// The names two or more modules make Public, and those modules.
  final _ambiguous = <String, List<String>>{};

  /// The file's own Structures, by lower-case name (D131).
  final _structures = <String, StructureType>{};

  /// The other modules' Structures, and the module of each, by lower-case
  /// name (D131).
  final _projectStructures = <String, (StructureType, String)>{};

  /// The For Each variables of Structures whose loop is being analyzed:
  /// a change to one's field stays in the copy (A066).
  final _copies = Map<Symbol, ForEachStmt>.identity();

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
      [List<String> args = const [], List<String> replacements = const []]) {
    final (line, column) = _lines.locate(start);
    _diagnostics.add(Diagnostic(
      code: code,
      line: line,
      column: column,
      offset: start,
      length: end - start,
      args: args,
      replacements: replacements,
    ));
  }

  void _reportAt(Node node, DiagnosticCode code,
          [List<String> args = const [],
          List<String> replacements = const []]) =>
      _report(code, node.start, node.end, args, replacements);

  int _line(Node node) => _lines.locate(node.start).$1;

  String _text(Node node) => parsed.source.substring(node.start, node.end);

  // -------------------------------------------------------------------------
  // File level

  AnalysisResult run() {
    final unit = parsed.unit;
    _scope = _file;

    // 0. Structures (D131), so that every type after can name them.
    _declareStructures(unit);

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
        case InvalidMember() || StructureDecl():
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

    // 2b. Event handlers: by name, or by Handles (D98).
    final handled = <String, ProcedureDecl>{};
    for (final member in unit.members.whereType<ProcedureDecl>()) {
      if (_result.symbols[member.name]?.procedure != member) continue;
      if (member.handles != null) {
        _handles(member, handled);
      } else if (form != null) {
        _handler(member, handled);
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

  /// The file's Structures (D131): their names first, so that they can
  /// name one another, then their fields; and none may contain itself.
  void _declareStructures(CompilationUnit unit) {
    final decls = unit.members.whereType<StructureDecl>().toList();
    final owner = form?.name ?? '';
    for (final d in decls) {
      final name = d.name.name;
      if (name.isEmpty) continue;
      final lower = name.toLowerCase();
      if (_structures.containsKey(lower)) {
        final first =
            decls.firstWhere((o) => o.name.name.toLowerCase() == lower);
        _reportAt(d.name, DiagnosticCode.duplicateDeclaration,
            [name, '${_line(first.name)}']);
        continue;
      }
      if (_typeNameTaken(lower) case final where?) {
        _reportAt(d.name, DiagnosticCode.structureNameTaken, [name, where]);
      }
      if (form != null && d.modifier == Keyword.kwPublic) {
        _reportAt(d.name, DiagnosticCode.structurePublicInForm);
      }
      final type = StructureType(name, owner: owner);
      _structures[lower] = type;
      _result.structures[lower] = type;
      _result.structureTypes[d] = type;
    }
    for (final d in decls) {
      final type = _result.structureTypes[d];
      if (type == null) continue;
      final seen = <String, StructureField>{};
      for (final f in d.fields) {
        final name = f.name.name;
        if (name.isEmpty) continue;
        if (seen[name.toLowerCase()] case final first?) {
          _reportAt(f.name, DiagnosticCode.duplicateDeclaration,
              [name, '${_line(first.name)}']);
          continue;
        }
        seen[name.toLowerCase()] = f;
        GbType t = GbType.unknown;
        if (f.type == null) {
          _reportAt(f.name, DiagnosticCode.missingTypeAndValue, [name]);
        } else {
          t = _resolveType(f.type!);
        }
        int? size;
        if (f.isArray) {
          if (f.arrayBound case final bound?) {
            size = structureArraySize(bound);
            if (size == null) {
              _reportAt(bound, DiagnosticCode.structureArraySize);
            }
          }
          t = ArrayType(t);
        }
        type.fields.add(StructureFieldType(name, t, size: size));
      }
    }
    for (final d in decls) {
      final type = _result.structureTypes[d];
      if (type == null) continue;
      if (_containing(type) case final path?) {
        _reportAt(d.name, DiagnosticCode.structureContainsItself,
            [type.name, path.join('.')]);
      }
    }
  }

  /// Where a type named [lower] already is, for a Structure of that name
  /// (A068): GuBASIC's own, a form, a module or another module's
  /// Structure; null when the name is free.
  String? _typeNameTaken(String lower) {
    if (lookupNamedType(lower) != null ||
        lower == 'list' ||
        componentAliased(lower) != null ||
        allBuiltinObjects.any((o) => o.toLowerCase() == lower)) {
      return 'GuBASIC';
    }
    if (forms?[lower] case final f?) return f.name;
    if (form?.name.toLowerCase() == lower) return form!.name;
    if (modules?[lower] case final m?) return m.name;
    if (_projectStructures[lower] case (_, final module)) return module;
    return null;
  }

  /// The Structure named [lower]: the file's own, or another module's.
  StructureType? _structureNamed(String lower) =>
      _structures[lower] ?? _projectStructures[lower]?.$1;

  /// The fields through which [start] contains itself, or null (A061): a
  /// field that is a Structure, or an array of one with a size, holds its
  /// value; a List or an array without a size holds none at first.
  List<String>? _containing(StructureType start) {
    final path = <String>[];
    final visited = <StructureType>{};
    bool visit(StructureType t) {
      for (final f in t.fields) {
        final inner = switch (f.type) {
          final StructureType s => s,
          ArrayType(element: final StructureType s) when f.size != null => s,
          _ => null,
        };
        if (inner == null) continue;
        path.add(f.name);
        if (inner == start) return true;
        if (visited.add(inner) && visit(inner)) return true;
        path.removeLast();
      }
      return false;
    }

    return visit(start) ? path : null;
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

  /// The event a procedure's name says it handles, `Control_Event` (or
  /// `Form_Event`) for an event that exists, or null.
  (ControlDecl?, String, EventSpec)? _eventNamed(String procedure) {
    final name = procedure.toLowerCase();
    final form = this.form;
    if (form == null) return null;
    final targets = [
      (null as ControlDecl?, 'Form', formComponent),
      for (final c in form.controls) (c, c.name, c.component),
    ];
    for (final (control, owner, component) in targets) {
      if (!name.startsWith('${owner.toLowerCase()}_')) continue;
      final event = component.events[name.substring(owner.length + 1)];
      if (event != null) return (control, owner, event);
    }
    return null;
  }

  /// Reports a procedure named for an event under another version of
  /// BASIC's name, `Timer1_Timer` (A051).
  void _otherEventName(ProcedureDecl decl) {
    final name = decl.name.name.toLowerCase();
    for (final c in form!.controls) {
      if (!name.startsWith('${c.name.toLowerCase()}_')) continue;
      final written = decl.name.name.substring(c.name.length + 1);
      final right = c.component.otherEvents[written.toLowerCase()];
      if (right == null) continue;
      _reportAt(decl.name, DiagnosticCode.eventHasOtherName,
          ['${c.name}.$written', right, '${c.name}_$right']);
      return;
    }
  }

  /// Reports [event], which [component] does not have: under another
  /// version of BASIC's name (A051), or not at all (A040).
  void _unknownEvent(
      Expr target, Identifier event, ComponentSpec component, String typeName) {
    final right = component.otherEvents[event.name.toLowerCase()];
    if (right != null) {
      _reportAt(event, DiagnosticCode.eventHasOtherName, [
        '${_text(target)}.${event.name}',
        right,
        '${_text(target)}.$right',
      ]);
    } else {
      _reportAt(event, DiagnosticCode.unknownEvent,
          [_text(target), typeName, event.name]);
    }
  }

  /// Records [decl] as an event handler if its name is `Control_Event`
  /// (or `Form_Event`) for an event that exists, and checks that it is
  /// written as the event expects (A032).
  void _handler(ProcedureDecl decl, Map<String, ProcedureDecl> handled) {
    final (control, owner, event) =
        _eventNamed(decl.name.name) ?? (null, '', null);
    if (event == null) {
      _otherEventName(decl);
      return;
    }
    final type = control?.component.type ?? _formType;
    if (_handlerFits(
            decl, event, owner, [(type, '$owner.${event.name}', decl.name)],
            byName: true) &&
        _once(handled, owner, event, decl, decl.name)) {
      _result.handlers[decl] = [EventHandler(control, event)];
    }
  }

  /// The type of the form the code belongs to, for `Me` and its events.
  GbType get _formType {
    final own = forms?[form!.name.toLowerCase()];
    return own == null
        ? formComponent.type
        : ControlType(formComponent, form: own);
  }

  /// `Sub X() Handles btnA.Click, Me.Load` (D98): the procedure handles
  /// exactly the events listed, whatever its name.
  void _handles(ProcedureDecl decl, Map<String, ProcedureDecl> handled) {
    final form = this.form;
    final found = <EventHandler>[];
    final senders = <(GbType, String, Node)>[];
    final events = <(EventHandler, String, Node)>[];
    for (final e in decl.handles!.events) {
      final target = e.target;
      if (form == null) {
        // Code without a form has no controls to handle.
        _reportAt(
            target, DiagnosticCode.unknownNameMaybeControl, [_text(target)]);
        continue;
      }
      final ControlDecl? control;
      final String owner;
      if (target is MeExpr) {
        control = null;
        owner = 'Form';
      } else if (target is NameExpr) {
        control = form.control(target.name);
        if (control == null) {
          _lookupName(target);
          continue;
        }
        owner = control.name;
        _result.symbols[target] = _controls!.symbols[owner.toLowerCase()]!
          ..used = true;
      } else {
        continue;
      }
      final component = control?.component ?? formComponent;
      if (e.name.name.isEmpty) continue;
      final event = component.events[e.name.name.toLowerCase()];
      if (event == null) {
        _unknownEvent(target, e.name, component, component.name);
        continue;
      }
      _result.spellings[e.name] = event.name;
      final handler = EventHandler(control, event);
      events.add((handler, owner, e));
      senders.add(
          (control?.component.type ?? _formType, '$owner.${event.name}', e));
    }
    final named = _eventNamed(decl.name.name);
    if (named != null &&
        !events
            .any((e) => e.$1.control == named.$1 && e.$1.event == named.$3)) {
      _reportAt(decl.name, DiagnosticCode.handlerNameMismatch,
          [decl.name.name, '${named.$2}.${named.$3.name}']);
    }
    if (events.isEmpty) return;
    final first = events.first;
    if (!_handlerFits(decl, first.$1.event, first.$2, senders, byName: false)) {
      return;
    }
    for (final (handler, owner, node) in events) {
      if (_once(handled, owner, handler.event, decl, node)) found.add(handler);
    }
    if (found.isNotEmpty) _result.handlers[decl] = found;
  }

  /// Whether [event] of [owner] has no handler yet; reports A041 at [at]
  /// when it has.
  bool _once(Map<String, ProcedureDecl> handled, String owner, EventSpec event,
      ProcedureDecl decl, Node at) {
    final key = '${owner.toLowerCase()}.${event.name.toLowerCase()}';
    final first = handled[key];
    if (first != null && first != decl) {
      _reportAt(at, DiagnosticCode.eventHandledTwice,
          ['$owner.${event.name}', first.name.name]);
      return false;
    }
    handled[key] = decl;
    return true;
  }

  /// Whether [decl] is written as a handler of [event] should be: a Sub
  /// with the event's parameters, or, for an event without any, nothing or
  /// one `sender` that can hold each of [senders] (D98). Reports why not
  /// (A032, A043, A044).
  bool _handlerFits(ProcedureDecl decl, EventSpec event, String owner,
      List<(GbType, String, Node)> senders,
      {required bool byName}) {
    final callable = _result.symbols[decl.name]!.callable!;
    final params = callable.parameters;
    String senderText() {
      final types = {for (final (t, _, _) in senders) t.displayName};
      return 'sender As ${types.length == 1 ? types.single : 'Control'}';
    }

    if (!decl.isFunction && event.parameters.isEmpty && params.length <= 2) {
      final netStyle = params.isNotEmpty &&
          (params.first.type == GbType.object ||
              (params.length == 2 &&
                  decl.parameters[1].type?.name.name.toLowerCase() ==
                      'eventargs'));
      if (netStyle) {
        _reportAt(decl.name, DiagnosticCode.netHandlerSignature,
            [decl.name.name, senderText()]);
        return false;
      }
      if (params.isEmpty) return true;
      final sender = params.length == 1 && !params.first.optional
          ? params.first.type ?? GbType.unknown
          : null;
      // A sender is a control or a form; anything else is not a handler's
      // parameter (A032).
      if (sender != null &&
          (sender is ControlType || sender == GbType.unknown)) {
        return _sendersFit(decl, sender, senders);
      }
    }
    // An event with parameters: a `sender` may come before them, as in
    // Visual Basic .NET (D112).
    if (!decl.isFunction &&
        event.parameters.isNotEmpty &&
        params.length == event.parameters.length + 1 &&
        [
          for (var i = 0; i < event.parameters.length; i++)
            params[i + 1].type == event.parameters[i].type &&
                !params[i + 1].optional
        ].every((same) => same) &&
        !params.first.optional) {
      final sender = params.first.type ?? GbType.unknown;
      if (sender is ControlType || sender == GbType.unknown) {
        return _sendersFit(decl, sender, senders);
      }
      if (sender == GbType.object) {
        // `sender As Object`: the control's own type, as for events
        // without parameters (A044's advice), written in full here.
        final rest = [
          for (final p in event.parameters)
            '${p.name} As ${p.type!.displayName}'
        ].join(', ');
        _reportAt(decl.name, DiagnosticCode.handlerSignature, [
          decl.name.name,
          '$owner.${event.name}',
          'Sub ${decl.name.name}(${senderText()}, $rest)',
        ]);
        return false;
      }
    }
    if (event.parameters.length == 1 &&
        event.parameters.single.type == GbType.keyEventArgs &&
        params.length == 2 &&
        params.every((p) => p.type == GbType.integer)) {
      // Visual Basic 6's (KeyCode As Integer, Shift As Integer) (D101).
      final head = byName ? '${owner}_${event.name}' : decl.name.name;
      _reportAt(decl.name, DiagnosticCode.vb6KeyHandler,
          [decl.name.name, 'Sub $head(e As KeyEventArgs)']);
      return false;
    }
    if (event.parameters.length == 1 &&
        event.parameters.single.type == GbType.mouseEventArgs &&
        params.length == 4) {
      // Visual Basic 6's (Button, Shift, X, Y) (D111).
      final head = byName ? '${owner}_${event.name}' : decl.name.name;
      _reportAt(decl.name, DiagnosticCode.vb6MouseHandler,
          [decl.name.name, 'Sub $head(e As MouseEventArgs)']);
      return false;
    }
    if (byName &&
        event.parameters.isEmpty &&
        params.length == 1 &&
        decl.parameters.single.name.name.toLowerCase() == 'index' &&
        params.single.type == GbType.integer) {
      // A Visual Basic 6 control array's handler (D99).
      _reportAt(decl.name, DiagnosticCode.controlArrayHandler, [
        decl.name.name,
        '$owner.${event.name}',
        senders.first.$1.displayName,
      ]);
      return false;
    }
    final ok = !decl.isFunction &&
        params.length == event.parameters.length &&
        [
          for (var i = 0; i < event.parameters.length; i++)
            params[i].type == event.parameters[i].type && !params[i].optional
        ].every((same) => same);
    if (!ok) {
      final params = [
        for (final p in event.parameters) '${p.name} As ${p.type!.displayName}'
      ].join(', ');
      _reportAt(decl.name, DiagnosticCode.handlerSignature, [
        decl.name.name,
        '$owner.${event.name}',
        'Sub ${byName ? event.handlerSignature(owner) : '${decl.name.name}($params)'}',
      ]);
    }
    return ok;
  }

  /// Whether [sender], a handler's first parameter, can hold each control
  /// of [senders] (D98); reports each one it cannot (A043).
  bool _sendersFit(
      ProcedureDecl decl, GbType sender, List<(GbType, String, Node)> senders) {
    var ok = true;
    for (final (type, name, at) in senders) {
      final check = checkConversion(type, sender);
      final fits = check.isAllowed &&
          (check.conversion == ImplicitConversion.none ||
              check.conversion == ImplicitConversion.unchecked);
      if (!fits) {
        _reportAt(at, DiagnosticCode.senderTypeMismatch, [
          decl.name.name,
          name,
          type.displayName,
          sender.displayName,
        ]);
        ok = false;
      }
    }
    return ok;
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
      _result.spellings[ref.name] = 'List';
      final element = ref.typeArguments.isEmpty
          ? GbType.object
          : _resolveType(ref.typeArguments.first);
      return ListType(element);
    }
    final named = lookupNamedType(lower);
    if (named != null) {
      _result.spellings[ref.name] = named.displayName;
      return named;
    }
    if (_structureNamed(lower) case final t?) {
      _result.spellings[ref.name] = t.name;
      return t;
    }
    if (componentAliased(name) case final c?) {
      // `RadioButton` (Visual Basic .NET) for OptionButton (D104).
      _reportAt(
          ref.name, DiagnosticCode.typeHasOtherName, [name, c.name], [c.name]);
      return c.type;
    }
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
      if (d.initializers case final items?) _initializers(declared, items, d);
    }
    final init = d.initializer;
    if (init is ArrayLiteral && d.arrayBound != null) {
      // `Dim a(2) As Integer = …` a list: the list gives the size (D132).
      _reportAt(
          d.arrayBound!, DiagnosticCode.arrayBoundWithList, [d.name.name]);
    }
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
      case AddHandlerStmt():
        _addHandler(s);
      case WithStmt():
        _with(s);
      case EndStmt() || ErrorStmt():
        break;
    }
  }

  /// The With blocks being analyzed, innermost last, with their values'
  /// types (D134).
  final _withs = <(WithStmt, GbType)>[];

  /// `With lblResult … End With` (D134): a value, whose members `.Name`
  /// inside are.
  void _with(WithStmt s) {
    final type = _value(s.target);
    if (type == GbType.builtinObject) {
      _reportAt(s.target, DiagnosticCode.withNotValue, [_text(s.target)]);
    }
    _withs.add((s, type == GbType.builtinObject ? GbType.unknown : type));
    _block(s.body);
    _withs.removeLast();
  }

  /// `AddHandler btn.Click, AddressOf Digit_Click` (D98): the control's
  /// event exists, and the procedure is a Sub of this code written as its
  /// handler.
  void _addHandler(AddHandlerStmt s) {
    final type = _value(s.event.target);
    final procedure = s.procedure;
    final symbol =
        procedure.name.isEmpty ? null : _scope.lookup(procedure.name);
    if (procedure.name.isNotEmpty) {
      if (symbol == null) {
        _reportAt(procedure, DiagnosticCode.unknownName, [procedure.name]);
      } else {
        symbol.used = true;
        _result.symbols[procedure] = symbol;
        if (symbol.kind != SymbolKind.procedure) {
          _reportAt(procedure, DiagnosticCode.notAProcedure, [procedure.name]);
        }
      }
    }
    if (type is! ControlType) {
      if (type != GbType.unknown) {
        _reportAt(s.event.target, DiagnosticCode.typeMismatch,
            [type.displayName, controlComponent.name]);
      }
      return;
    }
    final name = s.event.name.name;
    if (name.isEmpty) return;
    final event = type.component.events[name.toLowerCase()];
    if (event == null) {
      _unknownEvent(
          s.event.target, s.event.name, type.component, type.displayName);
      return;
    }
    _result.spellings[s.event.name] = event.name;
    final decl = symbol?.procedure;
    if (decl == null || symbol!.kind != SymbolKind.procedure) return;
    _handlerFits(decl, event, _text(s.event.target),
        [(type, '${_text(s.event.target)}.${event.name}', procedure)],
        byName: false);
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
        } else if (spec != null &&
            (spec.readOnly || _nameIsFixed(target, spec))) {
          _reportAt(target, DiagnosticCode.readOnlyProperty, [_text(target)]);
          targetType = GbType.unknown;
        } else {
          targetType = t;
          _pictureName(target, s.value);
          _anchorValue(target, s.value);
          _structureTarget(target);
          _listFits(_result.types[target.target], target.name.name, s.value);
        }
      case InvokeExpr():
        final t = _invoke(target, valueNeeded: true);
        final callee = target.target;
        if (_result.invokeKinds[target] == InvokeKind.call &&
            callee is MemberExpr &&
            _result.members[callee]?.settable == true) {
          // `t.Cell(0, 1) = "90"` (D114).
          _result.settableCalls.add(target);
          targetType = t;
          _secretHeader(target, callee, s.value);
        } else if (_result.invokeKinds[target] == InvokeKind.call) {
          _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
          targetType = GbType.unknown;
        } else if (t == GbType.json && _result.types[callee] == GbType.json) {
          // `j("age") = 13` (D125): any JSON value goes in.
          _argument(s.value, _value(s.value),
              const ParamSpec.of('value', ArgKind.jsonValue));
          return;
        } else {
          targetType = t;
          _structureTarget(target);
        }
      case ErrorExpr():
        targetType = GbType.unknown;
      default:
        _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
        targetType = GbType.unknown;
    }
    _expect(s.value, targetType);
  }

  /// A field of a Structure changed (`s.Score = 1`, `s.Marks(1) = 1`,
  /// `ReDim s.Marks(9)`; D131): the value it is in must be kept somewhere
  /// (A065), and a For Each variable's change stays in its copy (A066).
  void _structureTarget(Expr target) {
    MemberExpr? field;
    if (target is MemberExpr) {
      field = target;
    } else if (target is InvokeExpr &&
        _result.invokeKinds[target] == InvokeKind.item &&
        target.target is MemberExpr) {
      field = target.target as MemberExpr;
    }
    if (field == null || _result.types[field.target] is! StructureType) return;
    // The value that holds the Structure, outside its Structures and the
    // With blocks it is reached through (D134).
    var holder = field.target;
    while (true) {
      if (holder is MemberExpr &&
          _result.types[holder.target] is StructureType) {
        holder = holder.target;
      } else if (holder is WithValueExpr &&
          _result.withTargets[holder] != null) {
        holder = _result.withTargets[holder]!.target;
      } else {
        break;
      }
    }
    if (!_isPlace(holder)) {
      _reportAt(target, DiagnosticCode.structureCopyNotKept, [field.name.name]);
      return;
    }
    if (holder is NameExpr) {
      final loop = _copies[_result.symbols[holder]];
      if (loop != null) {
        _reportAt(target, DiagnosticCode.forEachCopy,
            [holder.name, _text(loop.collection), field.name.name]);
      }
    }
  }

  /// Whether [e] is somewhere a value is kept: a variable, an item of an
  /// array or a List, a form's or a module's variable; not a function's
  /// result.
  bool _isPlace(Expr e) => switch (e) {
        NameExpr() => _result.symbols[e]?.isVariable ?? false,
        InvokeExpr() => _result.invokeKinds[e] == InvokeKind.item,
        MemberExpr() => _result.types[e.target] is StructureType
            ? _isPlace(e.target)
            : !(_result.members[e]?.isMethod ?? true),
        _ => false,
      };

  /// Whether [target] is the Name of a form, or of a control drawn on the
  /// form, which can only be read: only a control made with New gets a
  /// Name, before it is added (D98).
  bool _nameIsFixed(MemberExpr target, MemberSpec spec) {
    if (spec.name != 'Name') return false;
    final receiver = target.target;
    final type = _result.types[receiver];
    return receiver is MeExpr ||
        (type is ControlType && type.component == formComponent) ||
        (receiver is NameExpr &&
            _result.symbols[receiver]?.kind == SymbolKind.control);
  }

  /// Warns when text that names no picture of the project is given to a
  /// picture property (A037): the program would stop there (R013).
  void _pictureName(MemberExpr target, Expr value) {
    final pictures = _result.pictures;
    final type = _result.types[target.target];
    if (pictures == null || value is! StringLiteral || type is! ControlType) {
      return;
    }
    final property = type.component.properties[target.name.name.toLowerCase()];
    if (property == null || !property.picture || value.value.isEmpty) return;
    if (!pictures.containsKey(pictureKey(value.value))) {
      _reportAt(value, DiagnosticCode.unknownPictureInCode, [value.value]);
    }
  }

  /// Warns when text with a word that is not an edge is given to an
  /// anchor property (A038): the program would stop there (R014).
  void _anchorValue(MemberExpr target, Expr value) {
    final type = _result.types[target.target];
    if (value is! StringLiteral || type is! ControlType) return;
    final property = type.component.properties[target.name.name.toLowerCase()];
    if (property != null &&
        property.shortcut &&
        normalShortcut(value.value) == null) {
      // A Shortcut likewise (A057, R024, D106).
      _reportAt(value, DiagnosticCode.badShortcutInCode, [value.value]);
    }
    if (property == null || !property.anchor) return;
    if (normalAnchor(value.value) == null) {
      _reportAt(value, DiagnosticCode.badAnchorInCode, [value.value]);
    }
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
      case ControlsType():
        element = controlComponent.type;
      case GbType.json:
        // The items of a JSON array (D125); an object is R040.
        element = GbType.json;
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
    // Each item of Structures comes as a copy (D131).
    final copy = variable != null && element is StructureType;
    if (copy) _copies[variable] = s;
    _proc?.loops.add(Keyword.kwFor);
    _block(s.body);
    _proc?.loops.removeLast();
    if (copy) _copies.remove(variable);
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
    final target = s.target;
    if (target is NameExpr) {
      final symbol = _scope.lookup(target.name);
      if (symbol == null) {
        if (target.name.isNotEmpty) {
          _reportAt(target, DiagnosticCode.unknownName, [target.name]);
        }
      } else {
        symbol.used = true;
        _result.symbols[target] = symbol;
        _result.types[target] = symbol.type;
        if (symbol.type is! ArrayType && symbol.type != GbType.unknown) {
          _reportAt(
              target, DiagnosticCode.notIndexable, [symbol.type.displayName]);
        }
      }
    } else if (target is MemberExpr) {
      // An array field of a Structure (D131).
      final t = _member(target, asCall: false, valueNeeded: true);
      _result.types[target] = t;
      if (_result.types[target.target] is! StructureType) {
        if (t != GbType.unknown) {
          _reportAt(target, DiagnosticCode.notAssignable, [_text(target)]);
        }
      } else if (t is! ArrayType && t != GbType.unknown) {
        _reportAt(target, DiagnosticCode.notIndexable, [t.displayName]);
      } else {
        _structureTarget(target);
      }
    }
    _expect(s.bound, GbType.integer);
  }

  // -------------------------------------------------------------------------
  // Expressions

  /// Analyzes [e] where a value is needed and checks that it can be stored
  /// as [target], recording any automatic conversion.
  void _expect(Expr e, GbType target) {
    if (e is ArrayLiteral && target is ArrayType) {
      // A list of items takes the array type it goes to (D132).
      _result.types[e] = _arrayLiteral(e, target);
      return;
    }
    _convert(e, _value(e), target);
  }

  /// `{90, 80, 70}` (D132): each item goes into [target]'s element type;
  /// without a target, the type is the items' own, Double for Integers
  /// with Doubles, and A073 when it cannot be told.
  GbType _arrayLiteral(ArrayLiteral e, ArrayType? target) {
    if (target != null) {
      for (final item in e.elements) {
        _expect(item, target.element);
      }
      return target;
    }
    final types = [for (final item in e.elements) _value(item)];
    if (types.contains(GbType.unknown)) return GbType.unknown;
    final GbType element;
    if (types.isNotEmpty && types.every((t) => t == types.first)) {
      element = types.first;
    } else if (types.isNotEmpty && types.every((t) => t.isNumeric)) {
      element = GbType.double_;
      for (var i = 0; i < types.length; i++) {
        if (types[i] == GbType.integer) {
          _result.conversions[e.elements[i]] = GbType.double_;
        }
      }
    } else {
      element = GbType.unknown;
    }
    if (element == GbType.unknown ||
        element == GbType.nothing ||
        element == GbType.void_) {
      _reportAt(e, DiagnosticCode.arrayLiteralType);
      return GbType.unknown;
    }
    return ArrayType(element);
  }

  /// A list of items given to an array field with a size (D132): it has
  /// as many items as the field (A072).
  void _listFits(GbType? holder, String field, Expr value) {
    if (value is! ArrayLiteral || holder is! StructureType) return;
    final f = holder.field(field.toLowerCase());
    final size = f?.size;
    if (f == null || size == null) return;
    if (value.elements.length != size + 1) {
      _reportAt(value, DiagnosticCode.arraySizeMismatch,
          [f.name, '${size + 1}', '${value.elements.length}']);
    }
  }

  /// A With list (D132): each item a field, or a settable property, of
  /// [type], given once, with a value of its type.
  void _initializers(GbType type, List<FieldInitializer> items, Node at) {
    final allowed = type is StructureType ||
        (isControlType(type) &&
            (type as ControlType).component != controlComponent) ||
        type == GbType.pdfDocument;
    if (!allowed) {
      if (type != GbType.unknown) {
        _reportAt(at, DiagnosticCode.withNotAllowed, [type.displayName]);
      }
      for (final i in items) {
        _value(i.value);
      }
      return;
    }
    final members = membersOf(type) ?? const {};
    final given = <String>{};
    for (final i in items) {
      final name = i.name.name;
      final spec = members[name.toLowerCase()];
      if (name.isEmpty) {
        _value(i.value);
        continue;
      }
      if (spec == null) {
        final suggestion =
            closestName(name, [for (final m in members.values) m.name]);
        if (suggestion != null) {
          _reportAt(i.name, DiagnosticCode.unknownMemberDidYouMean,
              [type.displayName, name, suggestion], [suggestion]);
        } else {
          _reportAt(
              i.name, DiagnosticCode.unknownMember, [type.displayName, name]);
        }
        _value(i.value);
        continue;
      }
      _result.spellings[i.name] = spec.name;
      if (!given.add(name.toLowerCase())) {
        _reportAt(i.name, DiagnosticCode.withTwice, [spec.name]);
      }
      if (spec.isMethod) {
        _reportAt(i.name, DiagnosticCode.notAssignable, ['.$name']);
        _value(i.value);
        continue;
      }
      if (spec.readOnly) {
        _reportAt(i.name, DiagnosticCode.readOnlyProperty, ['.$name']);
        _value(i.value);
        continue;
      }
      _expect(i.value, spec.type);
      _listFits(type, name, i.value);
    }
  }

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
      DateLiteral() => GbType.date,
      BooleanLiteral() => GbType.boolean,
      NothingLiteral() => GbType.nothing,
      MeExpr() => _me(e),
      NameExpr() => _name(e, valueNeeded: valueNeeded),
      MemberExpr() => _member(e, asCall: false, valueNeeded: valueNeeded),
      InvokeExpr() => _invoke(e, valueNeeded: valueNeeded),
      NewExpr() => _new(e),
      ArrayLiteral() => _arrayLiteral(e, null),
      WithValueExpr() => _withValue(e),
      UnaryExpr() => _unary(e),
      BinaryExpr() => _binary(e),
      ParenExpr() => _value(e.inner),
      TypeOfExpr() => _typeOf(e),
      CastExpr() => _cast(e),
      ErrorExpr() => GbType.unknown,
    };
    _result.types[e] = type;
    return type;
  }

  /// The value of the innermost With block (D134).
  GbType _withValue(WithValueExpr e) {
    if (_withs.isEmpty) return GbType.unknown; // the parser reported it
    final (block, type) = _withs.last;
    _result.withTargets[e] = block;
    return type;
  }

  /// `TypeOf c Is TextBox` (D98).
  GbType _typeOf(TypeOfExpr e) {
    _controlOperand(e.operand);
    final target = _controlTarget(e, e.type);
    if (target != null) _result.castTypes[e] = target;
    return GbType.boolean;
  }

  /// `CType(c, TextBox)` (D98).
  GbType _cast(CastExpr e) {
    _controlOperand(e.operand);
    final target = _controlTarget(e, e.type);
    if (target == null) return GbType.unknown;
    _result.castTypes[e] = target;
    return target;
  }

  /// The operand of CType or TypeOf: a control, or what may hold one.
  void _controlOperand(Expr operand) {
    final t = _value(operand);
    if (t == GbType.unknown ||
        t == GbType.object ||
        t == GbType.nothing ||
        isControlType(t)) {
      return;
    }
    _reportAt(operand, DiagnosticCode.typeMismatch,
        [t.displayName, controlComponent.name]);
  }

  /// The control type CType or TypeOf names, or null after reporting A045.
  ControlType? _controlTarget(Expr e, TypeRef ref) {
    final t = _resolveType(ref);
    if (t == GbType.unknown) return null;
    if (isControlType(t)) return t as ControlType;
    _reportAt(ref, DiagnosticCode.castNeedsControlType, [t.displayName]);
    return null;
  }

  GbType _me(MeExpr e) {
    final form = this.form;
    if (form != null) {
      final own = forms?[form.name.toLowerCase()];
      return own == null
          ? formComponent.type
          : ControlType(formComponent, form: own);
    }
    _reportAt(e, DiagnosticCode.unknownNameMaybeControl, ['Me']);
    return GbType.unknown;
  }

  /// Resolves a name, reporting it if it is not declared. Marks it used.
  Symbol? _lookupName(NameExpr e, {bool beforeDot = false}) {
    final symbol = _scope.lookup(e.name);
    if (symbol?.kind == SymbolKind.ambiguous) {
      // A Public name of two modules (D102).
      final modules = _ambiguous[e.name.toLowerCase()]!;
      _reportAt(e, DiagnosticCode.ambiguousName, [
        e.name,
        modules.join(', '),
        '${modules.first}.${symbol!.name}',
      ]);
      return null;
    }
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
    if (form != null && !beforeDot) {
      // `Hide`, `PopupMenu(mnuEdit)`: a form's method needs `Me.` (D110).
      if (formComponent.methods[e.name.toLowerCase()] case final m?) {
        _reportAt(
            e, DiagnosticCode.formMethodWithoutMe, [m.name], ['Me.${m.name}']);
        return;
      }
    }
    final suggestion =
        closestName(e.name, _scope.visible.map((s) => s.name).toSet());
    if (suggestion != null) {
      _reportAt(e, DiagnosticCode.unknownNameDidYouMean, [e.name, suggestion],
          [suggestion]);
    } else {
      _reportAt(e, DiagnosticCode.unknownName, [e.name]);
    }
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
      _unknownMember(e, members);
      return GbType.unknown;
    }
    _result.members[e] = spec;
    if (spec.isMethod && !asCall) {
      return _implicitCall(e, spec.method!, valueNeeded: valueNeeded);
    }
    return spec.type;
  }

  /// Reports a member [members] does not have: under another name GuBASIC
  /// spells differently (A036), close to one it has (A035), or not at all
  /// (A019).
  void _unknownMember(MemberExpr e, Map<String, MemberSpec> members) {
    final type = _result.types[e.target];
    final name = e.name.name;
    final target = e.target;
    // A built-in object of the component channel (Http, D125) has other
    // names too, from its component.yaml.
    final component = type is ControlType
        ? type.component
        : target is NameExpr &&
                _result.symbols[target]?.kind == SymbolKind.builtinObject
            ? objectComponents[target.name.toLowerCase()]
            : null;
    final args = [
      component?.object == true ? component!.name : type?.displayName ?? '?',
      name,
    ];
    final others = component?.otherNames[name.toLowerCase()];
    final suggestion =
        closestName(name, [for (final m in members.values) m.name]);
    if (others != null) {
      _reportAt(e.name, DiagnosticCode.memberHasOtherName,
          [...args, others.join(', ')], others);
    } else if (suggestion != null) {
      _reportAt(e.name, DiagnosticCode.unknownMemberDidYouMean,
          [...args, suggestion], [suggestion]);
    } else {
      _reportAt(e.name, DiagnosticCode.unknownMember, args);
    }
  }

  GbType _invoke(InvokeExpr e, {required bool valueNeeded}) {
    final target = e.target;
    Callable? callable;
    GbType? indexed;

    if (target is NameExpr) {
      if (_scope.lookup(target.name) == null &&
          formStatements.contains(target.name.toLowerCase())) {
        // `Unload Form2`: the parser said what to write (P024, P025).
        _analyzeArguments(e.arguments);
        return GbType.void_;
      }
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
      case ControlsType():
        element = controlComponent.type;
        _result.invokeKinds[e] = InvokeKind.item;
      case GbType.json:
        // `j("name")`, `j(0)` (D125): a member or an item, itself a Json.
        _result.invokeKinds[e] = InvokeKind.item;
        if (e.arguments.length != 1) {
          _reportAt(e, DiagnosticCode.wrongArgumentCount,
              [_text(target), '1', '${e.arguments.length}']);
          _analyzeArguments(e.arguments);
        } else {
          _argument(e.arguments.single, _value(e.arguments.single),
              const ParamSpec.of('member', ArgKind.numericOrString));
        }
        return GbType.json;
      case GbType.object || GbType.unknown || null:
        // Not known: decided at run time, and nothing more to report.
        _analyzeArguments(e.arguments);
        return GbType.unknown;
      case ControlType() when isControlType(indexed):
        // `Command1(0)`: a Visual Basic 6 control array (D99).
        _reportAt(target, DiagnosticCode.controlArrayItem, [_text(target)]);
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
    if (c.isVariadic) return '$required+';
    return required == all ? '$all' : '$required–$all';
  }

  /// Checks a call's arguments and gives the result type.
  GbType _call(InvokeExpr e, Callable callable) {
    final args = e.arguments;
    final target = e.target;
    final receiver = target is MemberExpr ? _result.types[target.target] : null;
    if (args.isNotEmpty &&
        target is MemberExpr &&
        callable.name == 'Show' &&
        receiver is ControlType &&
        receiver.component == formComponent) {
      // `Form2.Show vbModal` (Visual Basic 6): a dialog is ShowDialog.
      _reportAt(e, DiagnosticCode.showWithArgument, [_text(target.target)],
          ['${_text(target.target)}.ShowDialog']);
      return GbType.void_;
    }
    final types = [
      for (var i = 0; i < args.length; i++)
        _argumentType(args[i], callable.parameters, i),
    ];
    if (args.length < callable.requiredCount ||
        !callable.isVariadic && args.length > callable.parameters.length) {
      _reportAt(e, DiagnosticCode.wrongArgumentCount,
          [callable.name, _expectedCount(callable), '${args.length}']);
      return callable.returnType;
    }
    final last = callable.parameters.length - 1;
    for (var i = 0; i < args.length; i++) {
      _argument(args[i], types[i], callable.parameters[i < last ? i : last]);
    }
    if (receiver is ListType &&
        receiver.element is StructureType &&
        const {'Contains', 'IndexOf', 'Remove'}.contains(callable.name)) {
      // Each compares Structures (D131).
      _reportAt(e, DiagnosticCode.structureCompared, [callable.name]);
    }
    if (target is MemberExpr &&
        callable.name == 'Connect' &&
        args.length == 1 &&
        args.single is StringLiteral &&
        _result.types[target.target] is ControlType &&
        (_result.types[target.target] as ControlType).component.name ==
            'WebSocket') {
      // `ws://` beyond this computer and its network (D136).
      final url = (args.single as StringLiteral).value;
      if (isPlainRemoteWebSocket(url)) {
        _reportAt(args.single, DiagnosticCode.plainWebSocket, [url]);
      }
    }
    if (target is MemberExpr && args.isNotEmpty && _joinsValue(args.first)) {
      final object = _result.symbols[target.target];
      if (object?.kind == SymbolKind.builtinObject &&
          object!.name == 'Database') {
        // SQL put together with & (D126): a ? and the value after the SQL
        // cannot be broken by a quote in the value.
        _reportAt(args.first, DiagnosticCode.sqlJoined, [callable.name]);
      }
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

  /// The type of argument [i], [arg]: a list of items takes the array
  /// type of its parameter (D132).
  GbType _argumentType(Expr arg, List<ParamSpec> params, int i) {
    final param = params.isEmpty
        ? null
        : params[i < params.length ? i : params.length - 1];
    final type = param?.kind == ArgKind.typed ? param!.type : null;
    if (arg is ArrayLiteral && type is ArrayType) {
      return _result.types[arg] = _arrayLiteral(arg, type);
    }
    return _value(arg);
  }

  /// `Http.Header("Authorization") = token` (D135): a header set there goes
  /// with every request to every server the program calls, so a name that
  /// looks like a secret's is A076. Only a name written out can be told;
  /// `""`, which takes the header away, sends nothing.
  void _secretHeader(InvokeExpr call, MemberExpr callee, Expr value) {
    final object = _result.symbols[callee.target];
    if (object?.kind != SymbolKind.builtinObject ||
        object!.name != 'Http' ||
        callee.name.name.toLowerCase() != 'header' ||
        call.arguments.length != 1) {
      return;
    }
    final name = call.arguments.single;
    if (name is! StringLiteral ||
        value is StringLiteral && value.value.isEmpty) {
      return;
    }
    if (looksLikeSecretHeader(name.value)) {
      _reportAt(name, DiagnosticCode.secretHeader, [name.value]);
    }
  }

  /// Whether [e] joins something that is not written out with `&`:
  /// `"… WHERE name = '" & name & "'"`.
  bool _joinsValue(Expr e) =>
      e is BinaryExpr &&
      e.operator == BinaryOp.concat &&
      [e.left, e.right].any((side) =>
          side is! StringLiteral && (side is! BinaryExpr || _joinsValue(side)));

  void _argument(Expr arg, GbType type, ParamSpec param) {
    if (type == GbType.unknown || type == GbType.object) return;
    if (type is StructureType &&
        const {
          ArgKind.anyValue,
          ArgKind.numeric,
          ArgKind.numericOrString,
          ArgKind.convertible,
          ArgKind.jsonValue,
          ArgKind.sqlValue,
        }.contains(param.kind)) {
      // `Debug.Print(s)`, `CStr(s)` (D131).
      _reportAt(arg, DiagnosticCode.structureNotText);
      return;
    }
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
        // A Json value's number or text, too: CInt(j("age")) (D125).
        ok = type.isNumeric || type == GbType.string || type == GbType.json;
      case ArgKind.convertible:
        ok = type.isNumeric ||
            type == GbType.string ||
            type == GbType.boolean ||
            type == GbType.json;
      case ArgKind.jsonValue:
        ok = type.isNumeric ||
            type == GbType.string ||
            type == GbType.boolean ||
            type == GbType.json ||
            type == GbType.nothing;
      case ArgKind.sqlValue:
        ok = type.isNumeric ||
            type == GbType.string ||
            type == GbType.boolean ||
            type == GbType.date ||
            type == GbType.nothing;
      case ArgKind.array:
        ok = type is ArrayType;
      case ArgKind.menu:
        ok = type is ControlType && type.component.menu;
      case ArgKind.tableOrGrid:
        ok = type == GbType.table ||
            (type is ControlType && type.component.name == 'Grid');
    }
    if (!ok && type != GbType.void_) {
      final expected = switch (param.kind) {
        ArgKind.numeric || ArgKind.numericOrString => GbType.double_,
        ArgKind.array => const ArrayType(GbType.object),
        ArgKind.menu => menuComponent.type,
        ArgKind.tableOrGrid => GbType.table,
        ArgKind.jsonValue => GbType.json,
        _ => GbType.string,
      };
      _reportAt(arg, DiagnosticCode.typeMismatch,
          [type.displayName, expected.displayName]);
    }
  }

  GbType _new(NewExpr e) {
    final type = _resolveType(e.type);
    _newArguments(type, e.arguments ?? const [], e);
    if (e.initializers case final items?) _initializers(type, items, e);
    return type;
  }

  void _newArguments(GbType type, List<Expr> args, Node at) {
    if (type is ControlType) {
      // A control made at run time (D98); forms are used by their names,
      // and Control is the type of any control; a Timer is put on the form
      // in the designer (D100).
      if (!type.component.visual) {
        _reportAt(at, DiagnosticCode.placedInDesigner, [type.displayName]);
      } else if (!isControlType(type) || type.component == controlComponent) {
        _reportAt(at, DiagnosticCode.newForm, [type.displayName]);
      } else if (args.isNotEmpty) {
        _reportAt(at, DiagnosticCode.wrongArgumentCount,
            [type.displayName, '0', '${args.length}']);
      }
      _analyzeArguments(args);
      return;
    }
    final params = switch (type) {
      ListType() || StructureType() => const <ParamSpec>[],
      GbType.table || GbType.pdfDocument || GbType.json => const <ParamSpec>[],
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
          if (t is StructureType) {
            _reportAt(side, DiagnosticCode.structureNotText);
          } else if (t.isValueType || t == GbType.object) {
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
    if (l is StructureType || r is StructureType) {
      _reportAt(at, DiagnosticCode.structureCompared, [op.symbol]);
      return;
    }
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

/// The name among [candidates] closest to [name], if it is close enough to
/// be a typo: for "did you mean" (A002, A035). Ties go to the first in
/// sorted order.
String? closestName(String name, Iterable<String> candidates) {
  // One- and two-letter names are too short for a useful guess (y → x).
  if (name.length < 3) return null;
  final lower = name.toLowerCase();
  // One edit for names up to 6 letters, two for longer ones: looser
  // limits suggest unrelated names (total → Today).
  final limit = name.length <= 6 ? 1 : 2;
  String? best;
  var bestDistance = limit + 1;
  for (final candidate in candidates) {
    // Names whose lengths differ by more than the limit cannot be close.
    if ((candidate.length - name.length).abs() > limit) continue;
    final d = _editDistance(lower, candidate.toLowerCase());
    if (d < bestDistance ||
        d == bestDistance && best != null && candidate.compareTo(best) < 0) {
      bestDistance = d;
      best = candidate;
    }
  }
  return best;
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
