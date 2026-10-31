import '../analyzer/analysis_result.dart';
import '../analyzer/analyzer.dart';
import '../analyzer/builtins.dart';
import '../analyzer/compile.dart';
import '../analyzer/members.dart';
import '../analyzer/symbols.dart';
import '../analyzer/types.dart';
import '../ast/ast.dart';
import '../forms/component.dart';
import '../forms/form_file.dart';
import '../lexer/keyword.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';
import '../parser/parser.dart';

/// What a completion is, for the code editor to show beside it.
enum CompletionKind {
  /// "Did you mean": a name from a diagnostic's replacements (A002, A035,
  /// A036), for the word the caret is on.
  suggestion,
  keyword,
  type,
  variable,
  constant,
  procedure,
  function,
  object,
  control,
  property,
  method,
}

/// One name the code editor offers.
class Completion {
  const Completion(
    this.name,
    this.kind, {
    this.detail = '',
    this.readOnly = false,
  });

  /// What is put into the code: the name alone, no parentheses.
  final String name;
  final CompletionKind kind;

  /// The type of a property or variable (`Integer`), the parameters of a
  /// method or function (`(item As String)`, `(text As String) As
  /// Integer`), the type of a control (`ListBox`); empty for keywords.
  final String detail;

  /// For a property the program can only read (D45).
  final bool readOnly;

  @override
  String toString() => '${kind.name} $name${detail.isEmpty ? '' : ' $detail'}';
}

/// The names that can be written at a place in the code, and the word
/// they replace.
class Completions {
  const Completions({
    required this.start,
    required this.end,
    required this.prefix,
    required this.afterDot,
    required this.items,
  });

  /// The word the caret is on, from [start] to [end]: a completion
  /// replaces it all. `start == end` when the caret is not on a word.
  final int start;
  final int end;

  /// The part of the word before the caret, which [items] are filtered
  /// by.
  final String prefix;

  /// Members of what stands before a `.`.
  final bool afterDot;

  /// Suggestions first, then names starting with [prefix], then names
  /// containing it (from three letters on); each group in alphabetical
  /// order, ignoring case.
  final List<Completion> items;
}

/// The names that can be written at [offset] in [source] (DESIGN.md
/// D50): the members of what stands before a `.`, type names after `As`
/// and `New`, and elsewhere keywords, the names visible there and the
/// built-ins. Null where nothing is completed: in a string or comment, in
/// a number, where a new name is being declared (`Dim x`).
///
/// [program] is the last compilation of the code, which may be some keys
/// older than [source]: names are looked up in it by spelling, never by
/// offset, so a few keys more or less do not matter. When it is [source]'s
/// own compilation, the diagnostics on the word at [offset] that have
/// replacements come first, as [CompletionKind.suggestion]s. Without it,
/// only keywords, the built-ins and the controls of [form] are known.
///
/// Reads only the line [offset] is on, so the cost does not grow with the
/// file.
Completions? completionsAt(
  String source,
  int offset, {
  CompileResult? program,
  FormFile? form,
}) {
  if (offset < 0 || offset > source.length) return null;
  final lineStart = offset == 0 ? 0 : source.lastIndexOf('\n', offset - 1) + 1;
  final before = source.substring(lineStart, offset);
  final lexed = lex(before);
  if (lexed.comments.isNotEmpty) return null;
  final tokens = [
    for (final t in lexed.tokens)
      if (t.kind != TokenKind.newline && t.kind != TokenKind.eof) t,
  ];

  var prefix = '';
  var rest = tokens;
  if (tokens.isNotEmpty && tokens.last.end == before.length) {
    final last = tokens.last;
    switch (last.kind) {
      case TokenKind.identifier || TokenKind.keyword:
        // Names are ASCII (L002): Hangul being typed is never completed.
        if (!last.text.codeUnits.every(_isNamePart)) return null;
        prefix = last.text;
        rest = tokens.sublist(0, tokens.length - 1);
      case TokenKind.integerLiteral ||
            TokenKind.doubleLiteral ||
            TokenKind.stringLiteral ||
            TokenKind.dateLiteral ||
            TokenKind.error:
        return null;
      default:
        break;
    }
  }
  final start = offset - prefix.length;
  var end = offset;
  while (end < source.length && _isNamePart(source.codeUnitAt(end))) {
    end++;
  }

  final analysis = program?.analysis ?? analyze(parse(''), form: form);
  final previous = rest.isEmpty ? null : rest.last;
  final List<Completion> all;
  final afterDot = previous?.kind == TokenKind.dot;
  if (afterDot) {
    final members = _membersBefore(
      rest.sublist(0, rest.length - 1),
      _Names(source, lineStart, program, analysis),
    );
    if (members == null) return null;
    all = members;
  } else if (const {Keyword.kwAs, Keyword.kwNew, Keyword.kwOf}
      .contains(previous?.keyword)) {
    all = _typeNames;
  } else if (const {
    Keyword.kwDim,
    Keyword.kwConst,
    Keyword.kwStatic,
    Keyword.kwSub,
    Keyword.kwFunction,
    Keyword.kwOptional,
    Keyword.kwByVal,
  }.contains(previous?.keyword)) {
    return null; // A new name.
  } else {
    all = [
      ..._keywords,
      ..._Names(source, lineStart, program, analysis).visible(),
    ];
  }

  final suggestions = <Completion>[
    if (program != null && program.parseResult.source == source)
      for (final d in program.diagnostics)
        if (d.replacements.isNotEmpty &&
            d.offset == start &&
            d.offset + d.length == end)
          for (final r in d.replacements)
            Completion(r, CompletionKind.suggestion),
  ];
  return Completions(
    start: start,
    end: end,
    prefix: prefix,
    afterDot: afterDot,
    items: [...suggestions, ..._filter(all, prefix)],
  );
}

bool _isNamePart(int c) =>
    (c >= 0x30 && c <= 0x39) ||
    (c >= 0x41 && c <= 0x5A) ||
    (c >= 0x61 && c <= 0x7A) ||
    c == 0x5F;

/// [items] whose names start with [prefix], then, once three letters are
/// typed, those containing it (`count`: ListCount), ignoring case; each
/// group sorted. Two letters inside a name match too much (`st`: List). A name listed twice (a procedure
/// with the name of a built-in) is shown once.
List<Completion> _filter(List<Completion> items, String prefix) {
  final p = prefix.toLowerCase();
  final first = <Completion>[];
  final then = <Completion>[];
  final seen = <String>{};
  for (final c in items) {
    final name = c.name.toLowerCase();
    if (!seen.add(name)) continue;
    if (name.startsWith(p)) {
      first.add(c);
    } else if (p.length >= 3 && name.contains(p)) {
      then.add(c);
    }
  }
  int byName(Completion a, Completion b) =>
      a.name.toLowerCase().compareTo(b.name.toLowerCase());
  return [...first..sort(byName), ...then..sort(byName)];
}

final List<Completion> _keywords = [
  for (final k in Keyword.values)
    if (k.isSupported) Completion(k.spelling, CompletionKind.keyword),
];

final List<Completion> _typeNames = [
  for (final t in namedTypes.values)
    Completion(t.displayName, CompletionKind.type),
  const Completion('List', CompletionKind.type, detail: 'List(Of T)'),
  for (final c in builtinComponents.values)
    Completion(c.name, CompletionKind.type),
  // The type of any control (D98).
  Completion(controlComponent.name, CompletionKind.type),
];

/// The names visible at a line of the code, from the last compilation.
class _Names {
  _Names(this.source, this.lineStart, this.program, this.analysis);

  final String source;
  final int lineStart;
  final CompileResult? program;
  final AnalysisResult analysis;

  /// The locals of the procedure the line is in, by lower-case name.
  late final Map<String, Symbol> locals = _locals();

  Map<String, Symbol> _locals() {
    final name = _procedureAt();
    final program = this.program;
    if (name == null || program == null) return const {};
    final decl = program.parseResult.unit.members
        .whereType<ProcedureDecl>()
        .where((p) => p.name.name.toLowerCase() == name)
        .firstOrNull;
    if (decl == null) return const {};
    return {
      for (final MapEntry(key: node, value: symbol) in analysis.symbols.entries)
        if (node is Identifier &&
            identical(symbol.declaration, node) &&
            symbol.storage != Storage.field &&
            node.start >= decl.start &&
            node.end <= decl.end)
          symbol.name.toLowerCase(): symbol,
    };
  }

  static final _procedureLine = RegExp(
    r'^[ \t]*(?:(?:public|private)[ \t]+)?(?:sub|function)[ \t]+([a-z][a-z0-9_]*)',
    caseSensitive: false,
  );
  static final _procedureEnd = RegExp(
    r'^[ \t]*end[ \t]+(?:sub|function)\b',
    caseSensitive: false,
  );

  /// The lower-case name of the procedure the line is in, as the code is
  /// now: the nearest `Sub` or `Function` line above, unless an `End
  /// Sub` or `End Function` comes first.
  String? _procedureAt() {
    var end = source.indexOf('\n', lineStart);
    if (end < 0) end = source.length;
    var at = lineStart;
    while (true) {
      final line = source.substring(at, end);
      if (at != lineStart && _procedureEnd.hasMatch(line)) return null;
      final m = _procedureLine.firstMatch(line);
      if (m != null) return m[1]!.toLowerCase();
      if (at == 0) return null;
      end = at - 1;
      at = source.lastIndexOf('\n', end - 1) + 1;
    }
  }

  Symbol? lookup(String name) =>
      locals[name.toLowerCase()] ?? analysis.fileScope.lookup(name);

  /// Every name visible at the line, but event handlers, which the form
  /// calls rather than the code.
  Iterable<Completion> visible() sync* {
    final handlers = {for (final p in analysis.handlers.keys) p.name.name};
    final seen = <String>{};
    for (final s in [...locals.values, ...analysis.fileScope.visible]) {
      if (!seen.add(s.name.toLowerCase())) continue;
      if (s.kind == SymbolKind.ambiguous) continue;
      if (s.kind == SymbolKind.procedure && handlers.contains(s.name)) {
        continue;
      }
      yield _ofSymbol(s);
    }
  }
}

Completion _ofSymbol(Symbol s) => switch (s.kind) {
      SymbolKind.variable ||
      SymbolKind.parameter ||
      SymbolKind.loopVariable =>
        Completion(s.name, CompletionKind.variable, detail: _typeName(s.type)),
      SymbolKind.constant =>
        Completion(s.name, CompletionKind.constant, detail: _typeName(s.type)),
      SymbolKind.procedure => Completion(s.name, CompletionKind.procedure,
          detail: s.callable == null ? '' : _signature(s.callable!)),
      SymbolKind.builtinFunction => Completion(s.name, CompletionKind.function,
          detail: _signature(s.callable!)),
      SymbolKind.builtinObject => Completion(s.name, CompletionKind.object),
      SymbolKind.control =>
        Completion(s.name, CompletionKind.control, detail: _typeName(s.type)),
      // A form of the project (D88).
      SymbolKind.form =>
        Completion(s.name, CompletionKind.object, detail: 'Form'),
      // A module of the project (D102); a name two modules make Public
      // is left out.
      SymbolKind.module =>
        Completion(s.name, CompletionKind.object, detail: 'Module'),
      SymbolKind.ambiguous => Completion(s.name, CompletionKind.object),
    };

String _typeName(GbType t) => t == GbType.unknown ? '' : t.displayName;

/// `(item As String)`, `(text As String) As Integer`, `([seed As
/// Integer])`.
String _signature(Callable c) {
  final params = [
    for (final p in c.parameters)
      switch (p) {
        ParamSpec(kind: ArgKind.menu) => '${p.name} As Menu',
        ParamSpec(:final type?) when type != GbType.unknown => p.optional
            ? '[${p.name} As ${type.displayName}]'
            : '${p.name} As '
                '${type.displayName}',
        _ => p.optional ? '[${p.name}]' : p.name,
      },
  ].join(', ');
  return c.isSub || c.returnType == GbType.unknown
      ? '($params)'
      : '($params) As ${c.returnType.displayName}';
}

/// The members of what [tokens] (the line up to a `.`) ends with: `name`,
/// `name(…)`, `Me`, and those joined by dots (`lstCity.Text`). Null when
/// it is something else, or its type is not known.
List<Completion>? _membersBefore(List<Token> tokens, _Names names) {
  // From the end: a chain of names, each maybe followed by (…).
  final chain = <(String, bool)>[]; // (name, called or indexed)
  var i = tokens.length - 1;
  while (true) {
    var invoked = false;
    if (i >= 0 && tokens[i].kind == TokenKind.rightParen) {
      invoked = true;
      var depth = 0;
      for (; i >= 0; i--) {
        if (tokens[i].kind == TokenKind.rightParen) depth++;
        if (tokens[i].kind == TokenKind.leftParen && --depth == 0) break;
      }
      i--;
    }
    if (i < 0) return null;
    final t = tokens[i];
    final isMe = t.keyword == Keyword.kwMe;
    if (t.kind != TokenKind.identifier && !isMe) return null;
    chain.insert(0, (isMe ? 'Me' : t.text, invoked));
    i--;
    if (i < 0 || tokens[i].kind != TokenKind.dot) break;
    i--;
  }

  // The first name.
  final (first, firstInvoked) = chain.first;
  Map<String, MemberSpec>? members;
  GbType? type;
  if (first == 'Me') {
    if (names.analysis.form == null || firstInvoked) return null;
    type = formComponent.type;
  } else {
    final symbol = names.lookup(first);
    if (symbol == null) return null;
    if (symbol.kind == SymbolKind.builtinObject) {
      if (firstInvoked) return null;
      members = builtinObjectMembers(symbol.name);
    } else if (symbol.isCallable) {
      final c = symbol.callable;
      if (c == null || (!firstInvoked && c.requiredCount > 0)) return null;
      type = c.returnType;
    } else {
      type = firstInvoked ? _element(symbol.type) : symbol.type;
    }
  }

  // The members after it.
  for (final (name, invoked) in chain.skip(1)) {
    final all = members ?? (type == null ? null : membersOf(type));
    final spec = all?[name.toLowerCase()];
    if (spec == null) return null;
    members = null;
    type = spec.isMethod || !invoked ? spec.type : _element(spec.type);
  }

  members ??= type == null ? null : membersOf(type);
  if (members == null) return null;
  return [
    for (final m in members.values)
      m.isMethod
          ? Completion(m.name, CompletionKind.method,
              detail: _signature(m.method!))
          : Completion(m.name, CompletionKind.property,
              detail: m.type.displayName, readOnly: m.readOnly),
  ];
}

/// The type of an item of [t], for `name(i).`; null if it has none.
GbType? _element(GbType t) => switch (t) {
      ArrayType(:final element) || ListType(:final element) => element,
      _ => null,
    };
