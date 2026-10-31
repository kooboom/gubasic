import '../ast/ast.dart';
import '../ast/line_map.dart';
import '../diagnostics/diagnostic.dart';
import '../lexer/keyword.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';
import 'parse_result.dart';

/// Visual Basic 6's statements for forms, which GuBASIC writes as methods:
/// `Unload Form2` is `Form2.Close`, `Load Form2` is `Form2.Show` (P024,
/// P025, docs/DESIGN.md D88).
const formStatements = {'unload', 'load'};

/// Lexes and parses GuBASIC [source].
///
/// Never throws. Syntax errors become diagnostics; the parser then resumes
/// at the next statement or block end, so the tree always covers the whole
/// file. See docs/LANGUAGE.md §1.2 for the diagnostic codes.
ParseResult parse(String source) {
  final lexResult = lex(source);
  final parser = _Parser(source, lexResult.tokens);
  final unit = parser.compilationUnit();
  return ParseResult(source, lexResult, unit, parser.diagnostics,
      blockLines: parser.blockLines);
}

/// A block that is still open while its body is parsed.
enum _BlockKind {
  sub('Sub', 'End Sub'),
  function('Function', 'End Function'),
  if_('If', 'End If'),
  for_('For', 'Next'),
  forEach('For Each', 'Next'),
  do_('Do', 'Loop'),
  while_('While', 'Wend'),
  select('Select Case', 'End Select'),
  try_('Try', 'End Try');

  const _BlockKind(this.opener, this.closer);
  final String opener;
  final String closer;
}

class _Frame {
  _Frame(this.kind, this.openerToken);
  final _BlockKind kind;
  final Token openerToken;
}

/// A statement that ends (part of) a block.
enum _Closer {
  endIf('End If', 'If'),
  endSub('End Sub', 'Sub'),
  endFunction('End Function', 'Function'),
  endSelect('End Select', 'Select Case'),
  endTry('End Try', 'Try'),
  endWhile('End While', 'While'),
  endClass('End Class', 'Class'),
  next('Next', 'For'),
  loop('Loop', 'Do'),
  wend('Wend', 'While'),
  else_('Else', 'If'),
  elseIf('ElseIf', 'If'),
  case_('Case', 'Select Case'),
  catch_('Catch', 'Try'),
  finally_('Finally', 'Try'),

  /// `Sub`, `Function`, or either after `Public`/`Private`: a new procedure
  /// ends every open block.
  procedureStart('', '');

  const _Closer(this.text, this.opener);
  final String text;
  final String opener;

  /// Number of tokens the closer itself occupies.
  int get width => text.startsWith('End ') ? 2 : 1;
}

const _endPairs = {
  Keyword.kwIf: _Closer.endIf,
  Keyword.kwSub: _Closer.endSub,
  Keyword.kwFunction: _Closer.endFunction,
  Keyword.kwSelect: _Closer.endSelect,
  Keyword.kwTry: _Closer.endTry,
  Keyword.kwWhile: _Closer.endWhile,
  Keyword.kwClass: _Closer.endClass,
};

const _singleClosers = {
  Keyword.kwNext: _Closer.next,
  Keyword.kwLoop: _Closer.loop,
  Keyword.kwWend: _Closer.wend,
  Keyword.kwElse: _Closer.else_,
  Keyword.kwElseIf: _Closer.elseIf,
  Keyword.kwCase: _Closer.case_,
  Keyword.kwCatch: _Closer.catch_,
  Keyword.kwFinally: _Closer.finally_,
};

bool _accepts(_BlockKind kind, _Closer c) => switch (kind) {
      _BlockKind.sub || _BlockKind.function => c == _Closer.endSub ||
          c == _Closer.endFunction ||
          c == _Closer.procedureStart,
      _BlockKind.if_ =>
        c == _Closer.elseIf || c == _Closer.else_ || c == _Closer.endIf,
      _BlockKind.for_ || _BlockKind.forEach => c == _Closer.next,
      _BlockKind.do_ => c == _Closer.loop || c == _Closer.wend,
      _BlockKind.while_ =>
        c == _Closer.wend || c == _Closer.endWhile || c == _Closer.loop,
      _BlockKind.select => c == _Closer.case_ || c == _Closer.endSelect,
      _BlockKind.try_ =>
        c == _Closer.catch_ || c == _Closer.finally_ || c == _Closer.endTry,
    };

const _binaryTokens = {
  TokenKind.caret: BinaryOp.power,
  TokenKind.star: BinaryOp.multiply,
  TokenKind.slash: BinaryOp.divide,
  TokenKind.backslash: BinaryOp.integerDivide,
  TokenKind.plus: BinaryOp.add,
  TokenKind.minus: BinaryOp.subtract,
  TokenKind.ampersand: BinaryOp.concat,
  TokenKind.equal: BinaryOp.equal,
  TokenKind.notEqual: BinaryOp.notEqual,
  TokenKind.less: BinaryOp.less,
  TokenKind.greater: BinaryOp.greater,
  TokenKind.lessEqual: BinaryOp.lessEqual,
  TokenKind.greaterEqual: BinaryOp.greaterEqual,
};

const _binaryKeywords = {
  Keyword.kwMod: BinaryOp.modulo,
  Keyword.kwIs: BinaryOp.identity,
  Keyword.kwAnd: BinaryOp.and,
  Keyword.kwOr: BinaryOp.or,
  Keyword.kwXor: BinaryOp.xor,
  // Unsupported, read as their GuBASIC equivalents (P017).
  Keyword.kwAndAlso: BinaryOp.and,
  Keyword.kwOrElse: BinaryOp.or,
};

const _relationalTokens = {
  TokenKind.equal: BinaryOp.equal,
  TokenKind.notEqual: BinaryOp.notEqual,
  TokenKind.less: BinaryOp.less,
  TokenKind.greater: BinaryOp.greater,
  TokenKind.lessEqual: BinaryOp.lessEqual,
  TokenKind.greaterEqual: BinaryOp.greaterEqual,
};

/// Keywords that can start an expression.
const _expressionKeywords = {
  Keyword.kwTrue,
  Keyword.kwFalse,
  Keyword.kwNothing,
  Keyword.kwMe,
  Keyword.kwNew,
  Keyword.kwNot,
  Keyword.kwTypeOf,
  Keyword.kwCType,
};

/// Visual Basic .NET's casts other than `CType`, read as `CType` (P026).
const _otherCasts = {'directcast', 'trycast'};

class _Parser {
  _Parser(String source, this._tokens) : _lines = LineMap(source);

  final List<Token> _tokens;
  final LineMap _lines;
  final diagnostics = <Diagnostic>[];

  int _pos = 0;

  /// End offset of the last consumed token that is not a newline.
  int _lastEnd = 0;

  final _frames = <_Frame>[];

  /// Which lines open, go on with and close each block (for the editor).
  final blockLines = BlockLines();

  int _lineOf(Token t) => _lines.locate(t.offset).$1;

  /// [frame] opens a block on its opener's line.
  void _opened(_Frame frame) {
    if (_singleLineDepth > 0) return;
    blockLines.openers
        .putIfAbsent(_lineOf(frame.openerToken), () => frame.kind.closer);
  }

  /// The line starting at the current token goes on with [frame]'s block
  /// (Else, ElseIf, Case, Catch, Finally).
  void _goesOn(_Frame frame) {
    if (_singleLineDepth > 0) return;
    blockLines.middles[_lineOf(_tok)] = _lineOf(frame.openerToken);
  }

  /// The current line holds a lexer error token: the lexer has already
  /// reported the problem, so the parser stays quiet about this line.
  bool _lineHasLexError = false;

  /// A diagnostic was already reported for the current statement.
  bool _reported = false;

  /// Inside `If … Then <here> Else <here>` on one line.
  int _singleLineDepth = 0;

  /// Parentheses opened (in an expression or a call) and not yet closed.
  int _openParens = 0;

  // -------------------------------------------------------------------------
  // Tokens

  Token get _tok => _tokens[_pos];
  Token _peek(int ahead) =>
      _tokens[(_pos + ahead).clamp(0, _tokens.length - 1)];

  bool _is(TokenKind kind) => _tok.kind == kind;
  bool _isKw(Keyword k, [int ahead = 0]) => _peek(ahead).keyword == k;
  bool get _atEof => _is(TokenKind.eof);

  /// At the end of the current statement: a line break, end of file, or the
  /// `Else` of a single-line `If`.
  bool get _atStatementEnd =>
      _is(TokenKind.newline) ||
      _atEof ||
      (_singleLineDepth > 0 && _isKw(Keyword.kwElse));

  Token _advance() {
    final t = _tok;
    if (t.kind != TokenKind.eof) {
      _pos++;
      if (t.kind != TokenKind.newline) _lastEnd = t.end;
    }
    return t;
  }

  void _skipNewlines() {
    while (_is(TokenKind.newline)) {
      _advance();
    }
  }

  /// Skips the rest of the line, and the line break unless inside a
  /// single-line `If` (whose caller still needs it).
  void _skipLine() {
    while (!_is(TokenKind.newline) && !_atEof) {
      _advance();
    }
    if (_singleLineDepth == 0 && _is(TokenKind.newline)) _advance();
  }

  // -------------------------------------------------------------------------
  // Diagnostics

  /// Starts a new statement line: one diagnostic per statement, none on a
  /// line the lexer already complained about.
  void _beginLine() {
    if (_singleLineDepth > 0) return;
    _reported = false;
    _lineHasLexError = false;
    for (var i = _pos;
        i < _tokens.length && _tokens[i].kind != TokenKind.newline;
        i++) {
      if (_tokens[i].kind == TokenKind.error) {
        _lineHasLexError = true;
        break;
      }
    }
  }

  void _add(DiagnosticCode code, int offset, int length, List<String> args) {
    final (line, column) = _lines.locate(offset);
    diagnostics.add(Diagnostic(
      code: code,
      line: line,
      column: column,
      offset: offset,
      length: length,
      args: args,
    ));
  }

  /// Guidance about Visual Basic features (P013–P022). Each one is its own
  /// finding, not a consequence of an earlier error, so they are not
  /// limited to one per statement.
  static const _independent = {
    DiagnosticCode.unsupportedOnError,
    DiagnosticCode.unsupportedGoTo,
    DiagnosticCode.unsupportedVariant,
    DiagnosticCode.unsupportedClass,
    DiagnosticCode.unsupportedShortCircuit,
    DiagnosticCode.unsupportedWhile,
    DiagnosticCode.unsupportedCall,
    DiagnosticCode.unsupportedSetLet,
    DiagnosticCode.byRefNotAvailable,
    DiagnosticCode.otherCast,
  };

  /// Reports at [start]..[end] unless the line has a lexer error or (for
  /// syntax errors) the statement already has a diagnostic.
  void _error(DiagnosticCode code, int start, int end,
      [List<String> args = const []]) {
    if (_lineHasLexError) return;
    if (!_independent.contains(code)) {
      if (_reported) return;
      _reported = true;
    }
    _add(code, start, end - start, args);
  }

  void _errorAt(Token t, DiagnosticCode code, [List<String> args = const []]) =>
      _error(code, t.offset, t.end, args);

  /// Reports at the current token, or just after the previous one when the
  /// statement ended too early.
  void _errorHere(DiagnosticCode code, [List<String> args = const []]) {
    if (_atStatementEnd) {
      _error(code, _lastEnd, _lastEnd, args);
    } else {
      _errorAt(_tok, code, args);
    }
  }

  void _expectSymbol(TokenKind kind, String symbol) {
    if (_is(kind)) {
      _advance();
    } else {
      _errorHere(DiagnosticCode.expectedSymbol, [symbol]);
    }
  }

  bool _expectKeyword(Keyword k) {
    if (_isKw(k)) {
      _advance();
      return true;
    }
    _errorHere(DiagnosticCode.expectedKeyword, [k.spelling]);
    return false;
  }

  /// Requires the statement to end here; anything left over is reported
  /// and skipped. Consumes the line break.
  void _endOfStatement() {
    if (!_atStatementEnd) {
      _errorAt(_tok, DiagnosticCode.unexpectedToken, [_tok.text]);
      while (!_atStatementEnd) {
        _advance();
      }
    }
    if (_singleLineDepth == 0 && _is(TokenKind.newline)) _advance();
  }

  // -------------------------------------------------------------------------
  // Blocks

  /// The closing statement at the current position, if any.
  _Closer? _closerAt() {
    final t = _tok;
    if (t.kind != TokenKind.keyword) return null;
    final k = t.keyword!;
    if (k == Keyword.kwEnd) return _endPairs[_peek(1).keyword];
    if (k == Keyword.kwSub || k == Keyword.kwFunction) {
      return _Closer.procedureStart;
    }
    if ((k == Keyword.kwPublic || k == Keyword.kwPrivate) &&
        (_isKw(Keyword.kwSub, 1) || _isKw(Keyword.kwFunction, 1))) {
      return _Closer.procedureStart;
    }
    return _singleClosers[k];
  }

  bool _anyFrameAccepts(_Closer c, {bool skipTop = false}) {
    final end = skipTop ? _frames.length - 1 : _frames.length;
    for (var i = 0; i < end; i++) {
      if (_accepts(_frames[i].kind, c)) return true;
    }
    return false;
  }

  /// Parses statements until a closer that some open block accepts (or a
  /// new procedure, or end of file). Unmatched closers are reported and
  /// skipped.
  Block _block(String kind, _Frame frame) {
    _opened(frame);
    _frames.add(frame);
    final statements = <Stmt>[];
    while (true) {
      _skipNewlines();
      if (_atEof) break;
      final closer = _closerAt();
      if (closer != null) {
        if (closer == _Closer.procedureStart || _anyFrameAccepts(closer)) {
          break;
        }
        _beginLine();
        _errorAt(
            _tok, DiagnosticCode.unmatchedCloser, [closer.text, closer.opener]);
        _skipLine();
        continue;
      }
      final before = _pos;
      statements.add(_statement());
      if (_pos == before) _advance();
    }
    _frames.removeLast();
    return statements.isEmpty
        ? Block(kind, statements, _lastEnd, _lastEnd)
        : Block(kind, statements, statements.first.start, statements.last.end);
  }

  /// Reports that [frame] was never closed (always, even on a line that
  /// already has a diagnostic: it is a different problem).
  void _unclosed(_Frame frame) {
    final t = frame.openerToken;
    final (line, _) = _lines.locate(t.offset);
    _add(DiagnosticCode.unclosedBlock, t.offset, t.length,
        [frame.kind.opener, '$line', frame.kind.closer]);
  }

  /// Consumes the closer [c] (one or two tokens) at the start of a line,
  /// which closes [frame]'s block.
  void _consumeCloser(_Closer c, _Frame frame) {
    if (_singleLineDepth == 0) {
      blockLines.closers[_lineOf(_tok)] = _lineOf(frame.openerToken);
    }
    _beginLine();
    for (var i = 0; i < c.width; i++) {
      _advance();
    }
  }

  // -------------------------------------------------------------------------
  // File level

  CompilationUnit compilationUnit() {
    final members = <Member>[];
    while (true) {
      _skipNewlines();
      if (_atEof) break;
      final before = _pos;
      _beginLine();
      final member = _member();
      if (member != null) members.add(member);
      if (_pos == before) _advance();
    }
    return CompilationUnit(members, 0, _tok.end);
  }

  Member? _member() {
    final t = _tok;
    final k = t.keyword;
    if (k == Keyword.kwPublic || k == Keyword.kwPrivate) {
      if (_isKw(Keyword.kwSub, 1) || _isKw(Keyword.kwFunction, 1)) {
        return _procedure();
      }
      _advance();
      if (_isKw(Keyword.kwConst)) {
        _advance();
        return _field(t, k, isConst: true);
      }
      if (_isKw(Keyword.kwDim)) {
        _errorAt(_advance(), DiagnosticCode.unexpectedToken, ['Dim']);
      }
      return _field(t, k, isConst: false);
    }
    switch (k) {
      case Keyword.kwSub || Keyword.kwFunction:
        return _procedure();
      case Keyword.kwDim:
        _advance();
        return _field(t, k, isConst: false);
      case Keyword.kwConst:
        _advance();
        return _field(t, null, isConst: true);
      case Keyword.kwStatic:
        _errorAt(
            _advance(), DiagnosticCode.declarationNotAllowedHere, ['Static']);
        return _field(t, Keyword.kwDim, isConst: false);
      case Keyword.kwClass:
        _skipClass();
        return null;
      default:
    }
    final closer = _closerAt();
    if (closer != null) {
      _errorAt(t, DiagnosticCode.unmatchedCloser, [closer.text, closer.opener]);
      _skipLine();
      return null;
    }
    _errorAt(t, DiagnosticCode.statementOutsideProcedure);
    return InvalidMember(_statementBody());
  }

  FieldDecl _field(Token start, Keyword? modifier, {required bool isConst}) {
    final declarator = _declarator(isConst: isConst);
    _oneVariablePerLine();
    _endOfStatement();
    return FieldDecl(modifier, isConst, declarator, start.offset, _lastEnd);
  }

  void _oneVariablePerLine() {
    if (_is(TokenKind.comma)) {
      _errorAt(_tok, DiagnosticCode.oneVariablePerDeclaration);
      while (!_atStatementEnd) {
        _advance();
      }
    }
  }

  ProcedureDecl _procedure() {
    final start = _tok.offset;
    Keyword? modifier;
    if (_isKw(Keyword.kwPublic) || _isKw(Keyword.kwPrivate)) {
      modifier = _advance().keyword;
    }
    final keywordToken = _advance();
    final isFunction = keywordToken.keyword == Keyword.kwFunction;
    final name = _name();

    final parameters = <Parameter>[];
    if (_is(TokenKind.leftParen)) {
      _advance();
      if (!_is(TokenKind.rightParen)) {
        do {
          parameters.add(_parameter());
        } while (_is(TokenKind.comma) && _advance().kind == TokenKind.comma);
      }
      _expectSymbol(TokenKind.rightParen, ')');
    }

    TypeRef? returnType;
    if (_isKw(Keyword.kwAs)) {
      final asToken = _advance();
      returnType = _typeRef();
      if (!isFunction) {
        _errorAt(asToken, DiagnosticCode.unexpectedToken, ['As']);
      }
    }

    HandlesClause? handles;
    if (_isKw(Keyword.kwHandles)) handles = _handles();
    _endOfStatement();

    final frame =
        _Frame(isFunction ? _BlockKind.function : _BlockKind.sub, keywordToken);
    final body = _block('Body', frame);

    final closer = _closerAt();
    if (closer == _Closer.endSub || closer == _Closer.endFunction) {
      final closerToken = _tok;
      _consumeCloser(closer!, frame);
      final expected = isFunction ? _Closer.endFunction : _Closer.endSub;
      if (closer != expected) {
        _error(DiagnosticCode.expectedKeyword, closerToken.offset, _lastEnd,
            [expected.text]);
      }
      _endOfStatement();
    } else {
      _unclosed(frame);
    }
    return ProcedureDecl(
      modifier: modifier,
      isFunction: isFunction,
      name: name,
      parameters: parameters,
      returnType: returnType,
      handles: handles,
      body: body,
      start: start,
      end: _lastEnd,
    );
  }

  Parameter _parameter() {
    final modifierStart = _tok.offset;
    var isOptional = false;
    if (_isKw(Keyword.kwOptional)) {
      _advance();
      isOptional = true;
    }
    Keyword? passing;
    if (_isKw(Keyword.kwByVal) || _isKw(Keyword.kwByRef)) {
      final t = _advance();
      passing = t.keyword;
      if (passing == Keyword.kwByRef) {
        _errorAt(t, DiagnosticCode.byRefNotAvailable);
      }
    }
    final name = _name();
    // A missing name sits at the previous token, so start from it.
    final start = isOptional || passing != null ? modifierStart : name.start;
    var isArray = false;
    if (_is(TokenKind.leftParen)) {
      _advance();
      isArray = true;
      _expectSymbol(TokenKind.rightParen, ')');
    }
    TypeRef? type;
    if (_isKw(Keyword.kwAs)) {
      _advance();
      type = _typeRef();
    }
    Expr? defaultValue;
    if (_is(TokenKind.equal)) {
      _advance();
      defaultValue = _expression();
    }
    return Parameter(
      isOptional: isOptional,
      passing: passing,
      name: name,
      isArray: isArray,
      type: type,
      defaultValue: defaultValue,
      start: start,
      end: _lastEnd,
    );
  }

  HandlesClause _handles() {
    final handlesToken = _advance();
    final events = <MemberExpr>[];
    do {
      final Expr target;
      if (_isKw(Keyword.kwMe)) {
        // The form's own events: `Handles Me.Load`.
        final me = _advance();
        target = MeExpr(me.offset, me.end);
      } else {
        final control = _name();
        target = NameExpr(control.name, control.start, control.end);
      }
      _expectSymbol(TokenKind.dot, '.');
      final event = _memberName();
      events.add(MemberExpr(target, event, target.start, _lastEnd));
    } while (_is(TokenKind.comma) && _advance().kind == TokenKind.comma);
    return HandlesClause(events, handlesToken.offset, _lastEnd);
  }

  /// `Class … End Class` is skipped as a whole (P016).
  void _skipClass() {
    _errorAt(_tok, DiagnosticCode.unsupportedClass);
    while (!_atEof) {
      if (_isKw(Keyword.kwEnd) && _isKw(Keyword.kwClass, 1)) {
        _advance();
        _advance();
        _skipLine();
        return;
      }
      _advance();
    }
  }

  // -------------------------------------------------------------------------
  // Declarations

  Identifier _name() {
    if (_is(TokenKind.identifier)) {
      final t = _advance();
      return Identifier(t.text, t.offset, t.end);
    }
    _errorHere(DiagnosticCode.expectedName);
    return Identifier('', _lastEnd, _lastEnd);
  }

  /// A name after `.`: keywords are allowed here (`x.End`, `obj.Next`).
  Identifier _memberName() {
    if (_is(TokenKind.identifier) || _is(TokenKind.keyword)) {
      final t = _advance();
      return Identifier(t.text, t.offset, t.end);
    }
    _errorHere(DiagnosticCode.expectedName);
    return Identifier('', _lastEnd, _lastEnd);
  }

  TypeRef _typeRef() {
    final Identifier name;
    if (_isKw(Keyword.kwVariant)) {
      final t = _advance();
      _errorAt(t, DiagnosticCode.unsupportedVariant);
      name = Identifier(t.text, t.offset, t.end);
    } else if (_is(TokenKind.identifier)) {
      name = _name();
    } else {
      _errorHere(DiagnosticCode.expectedName);
      return TypeRef(
          Identifier('', _lastEnd, _lastEnd), const [], _lastEnd, _lastEnd);
    }
    final arguments = <TypeRef>[];
    if (_is(TokenKind.leftParen) && _isKw(Keyword.kwOf, 1)) {
      _advance();
      _advance();
      do {
        arguments.add(_typeRef());
      } while (_is(TokenKind.comma) && _advance().kind == TokenKind.comma);
      _expectSymbol(TokenKind.rightParen, ')');
    }
    return TypeRef(name, arguments, name.start, _lastEnd);
  }

  VariableDeclarator _declarator({required bool isConst}) {
    final name = _name();
    var isArray = false;
    Expr? bound;
    if (_is(TokenKind.leftParen)) {
      _advance();
      isArray = true;
      if (!_is(TokenKind.rightParen)) bound = _expression();
      _expectSymbol(TokenKind.rightParen, ')');
    }
    TypeRef? type;
    var isNew = false;
    List<Expr>? newArguments;
    if (_isKw(Keyword.kwAs)) {
      _advance();
      if (_isKw(Keyword.kwNew)) {
        _advance();
        isNew = true;
      }
      type = _typeRef();
      if (isNew && _is(TokenKind.leftParen)) newArguments = _arguments();
    }
    Expr? initializer;
    if (_is(TokenKind.equal)) {
      _advance();
      initializer = _expression();
    } else if (isConst) {
      _errorHere(DiagnosticCode.expectedSymbol, ['=']);
    }
    return VariableDeclarator(
      name: name,
      isArray: isArray,
      arrayBound: bound,
      type: type,
      isNew: isNew,
      newArguments: newArguments,
      initializer: initializer,
      start: name.start,
      end: _lastEnd,
    );
  }

  // -------------------------------------------------------------------------
  // Statements

  Stmt _statement() {
    _beginLine();
    return _statementBody();
  }

  Stmt _statementBody() {
    final t = _tok;
    if (t.kind != TokenKind.keyword) return _callOrAssignment();
    switch (t.keyword!) {
      case Keyword.kwDim || Keyword.kwStatic || Keyword.kwConst:
        return _localDeclaration();
      case Keyword.kwPublic || Keyword.kwPrivate:
        _errorAt(t, DiagnosticCode.declarationNotAllowedHere, [t.text]);
        return _localDeclaration();
      case Keyword.kwIf:
        return _if();
      case Keyword.kwSelect:
        return _select();
      case Keyword.kwFor:
        return _for();
      case Keyword.kwDo:
        return _do();
      case Keyword.kwWhile:
        return _while();
      case Keyword.kwTry:
        return _try();
      case Keyword.kwExit:
        return _exit();
      case Keyword.kwReturn:
        _advance();
        final value = _atStatementEnd ? null : _expression();
        _endOfStatement();
        return ReturnStmt(value, t.offset, _lastEnd);
      case Keyword.kwThrow:
        _advance();
        final value = _expression();
        _endOfStatement();
        return ThrowStmt(value, t.offset, _lastEnd);
      case Keyword.kwReDim:
        return _reDim();
      case Keyword.kwAddHandler:
        return _addHandler();
      case Keyword.kwEnd:
        _advance();
        _endOfStatement();
        return EndStmt(t.offset, t.end);
      case Keyword.kwSet || Keyword.kwLet:
        _errorAt(_advance(), DiagnosticCode.unsupportedSetLet, [t.text]);
        return _callOrAssignment(start: t.offset);
      case Keyword.kwCall:
        _errorAt(_advance(), DiagnosticCode.unsupportedCall);
        return _callOrAssignment(start: t.offset);
      case Keyword.kwOn:
        _errorAt(t, DiagnosticCode.unsupportedOnError);
        _skipLine();
        return ErrorStmt(t.offset, _lastEnd);
      case Keyword.kwGoTo || Keyword.kwGoSub:
        _errorAt(t, DiagnosticCode.unsupportedGoTo, [t.text]);
        _skipLine();
        return ErrorStmt(t.offset, _lastEnd);
      case Keyword.kwClass:
        _skipClass();
        return ErrorStmt(t.offset, _lastEnd);
      default:
        if (_expressionKeywords.contains(t.keyword)) return _callOrAssignment();
        _errorAt(t, DiagnosticCode.unexpectedToken, [t.text]);
        _skipLine();
        return ErrorStmt(t.offset, _lastEnd);
    }
  }

  /// `AddHandler btn.Click, AddressOf Digit_Click`.
  Stmt _addHandler() {
    final start = _advance().offset;
    final event = _postfix();
    _expectSymbol(TokenKind.comma, ',');
    _expectKeyword(Keyword.kwAddressOf);
    final procedure = _name();
    _endOfStatement();
    if (event is! MemberExpr) {
      if (event is! ErrorExpr) {
        _error(DiagnosticCode.expectedSymbol, event.end, event.end, ['.']);
      }
      return ErrorStmt(start, _lastEnd);
    }
    return AddHandlerStmt(event, procedure, start, _lastEnd);
  }

  LocalDeclStmt _localDeclaration() {
    final start = _tok.offset;
    var kind = _advance().keyword!;
    if (kind == Keyword.kwPublic || kind == Keyword.kwPrivate) {
      if (_isKw(Keyword.kwConst) || _isKw(Keyword.kwDim)) {
        kind = _advance().keyword!;
      } else {
        kind = Keyword.kwDim;
      }
    }
    final declarator = _declarator(isConst: kind == Keyword.kwConst);
    _oneVariablePerLine();
    _endOfStatement();
    return LocalDeclStmt(kind, declarator, start, _lastEnd);
  }

  /// `target = value`, or a call used as a statement.
  Stmt _callOrAssignment({int? start}) {
    final from = start ?? _tok.offset;
    if (!_startsExpression(_tok) ||
        _is(TokenKind.minus) ||
        _is(TokenKind.plus) ||
        _isKw(Keyword.kwNot)) {
      _errorAt(_tok, DiagnosticCode.unexpectedToken, [_tok.text]);
      _skipLine();
      return ErrorStmt(from, _lastEnd);
    }
    var target = _postfix();
    if (_is(TokenKind.equal)) {
      _advance();
      final value = _expression();
      _endOfStatement();
      return AssignmentStmt(target, value, from, _lastEnd);
    }
    // VB6 style `MsgBox "Hi"`: read the arguments anyway (P011).
    if ((target is NameExpr || target is MemberExpr) &&
        !_atStatementEnd &&
        !_is(TokenKind.minus) &&
        !_is(TokenKind.plus) &&
        _startsExpression(_tok)) {
      final statement = target is NameExpr ? target.name.toLowerCase() : null;
      if (statement == 'open') {
        // VB6's `Open path For Input As #1`: File's functions (P030,
        // D113). The rest of the line is VB6's, not GuBASIC's.
        _error(DiagnosticCode.openStatement, target.start, target.end);
        _skipLine();
        return ErrorStmt(from, _lastEnd);
      }
      if (statement != null && formStatements.contains(statement)) {
        // VB6's `Unload Form2`: a method in GuBASIC (P024, P025); with
        // `(index)`, a control array's element (P027, P028).
        final element = _tok.kind == TokenKind.identifier &&
            _peek(1).kind == TokenKind.leftParen;
        _errorAt(
            _tok,
            switch ((statement == 'unload', element)) {
              (true, false) => DiagnosticCode.unloadStatement,
              (false, false) => DiagnosticCode.loadStatement,
              (true, true) => DiagnosticCode.unloadControl,
              (false, true) => DiagnosticCode.loadControl,
            },
            [_tok.text]);
      } else if (statement == 'popupmenu') {
        // VB6's `PopupMenu mnuEdit`: `Me.PopupMenu(mnuEdit)` (P029, D110).
        _errorAt(_tok, DiagnosticCode.popupMenuStatement, [_tok.text]);
      } else if (target is! MemberExpr ||
          target.name.name.toLowerCase() != 'show') {
        // `Form2.Show vbModal` is reported by the analyzer (A039).
        _errorAt(_tok, DiagnosticCode.callWithoutParentheses);
      }
      final arguments = <Expr>[_expression()];
      while (_is(TokenKind.comma)) {
        _advance();
        arguments.add(_expression());
      }
      if (statement == 'popupmenu' && target is NameExpr) {
        // Read as what it should be, so that only P029 says so.
        target = MemberExpr(
            MeExpr(target.start, target.start),
            Identifier(target.name, target.start, target.end),
            target.start,
            target.end);
      }
      target = InvokeExpr(target, arguments, target.start, _lastEnd);
    }
    _endOfStatement();
    return ExpressionStmt(target, from, _lastEnd);
  }

  Stmt _if() {
    final ifToken = _advance();
    final condition = _expression();
    _expectKeyword(Keyword.kwThen);

    // Inside a single-line If, a nested If is single-line too.
    if (_singleLineDepth > 0 || !_atStatementEnd) {
      return _singleLineIf(ifToken, condition);
    }
    _endOfStatement();

    final frame = _Frame(_BlockKind.if_, ifToken);
    final branches = <IfBranch>[];
    Block? elseBlock;
    var branchStart = ifToken.offset;
    var branchCondition = condition;
    while (true) {
      final body = _block('Then', frame);
      branches.add(IfBranch(branchCondition, body, branchStart, _lastEnd));
      final closer = _closerAt();
      if (closer == _Closer.elseIf) {
        _goesOn(frame);
        _beginLine();
        branchStart = _advance().offset;
        branchCondition = _expression();
        _expectKeyword(Keyword.kwThen);
        _endOfStatement();
        continue;
      }
      if (closer == _Closer.else_) {
        _goesOn(frame);
        _beginLine();
        _advance();
        _endOfStatement();
        elseBlock = _block('Else', frame);
      }
      if (_closerAt() == _Closer.endIf) {
        _consumeCloser(_Closer.endIf, frame);
        _endOfStatement();
      } else {
        _unclosed(frame);
      }
      break;
    }
    return IfStmt(branches, elseBlock, false, ifToken.offset, _lastEnd);
  }

  IfStmt _singleLineIf(Token ifToken, Expr condition) {
    _singleLineDepth++;
    final thenStmt = _singleLineStatement();
    final thenBlock = Block('Then', [thenStmt], thenStmt.start, thenStmt.end);
    Block? elseBlock;
    if (_isKw(Keyword.kwElse)) {
      _advance();
      final elseStmt = _singleLineStatement();
      elseBlock = Block('Else', [elseStmt], elseStmt.start, elseStmt.end);
    }
    _singleLineDepth--;
    _endOfStatement();
    return IfStmt(
      [IfBranch(condition, thenBlock, ifToken.offset, thenBlock.end)],
      elseBlock,
      true,
      ifToken.offset,
      _lastEnd,
    );
  }

  /// One statement inside a single-line `If`. Block statements cannot be
  /// written there.
  Stmt _singleLineStatement() {
    final t = _tok;
    const blocks = {
      Keyword.kwFor,
      Keyword.kwDo,
      Keyword.kwSelect,
      Keyword.kwTry,
      Keyword.kwWhile,
    };
    if (_atStatementEnd) {
      // `If x Then` with nothing after it on a single line.
      _errorHere(DiagnosticCode.expectedExpression);
      return ErrorStmt(_lastEnd, _lastEnd);
    }
    if (blocks.contains(t.keyword)) {
      _errorAt(t, DiagnosticCode.unexpectedToken, [t.text]);
      _skipLine();
      return ErrorStmt(t.offset, _lastEnd);
    }
    return _statementBody();
  }

  SelectStmt _select() {
    final selectToken = _advance();
    _expectKeyword(Keyword.kwCase);
    final subject = _expression();
    _endOfStatement();

    final frame = _Frame(_BlockKind.select, selectToken);
    _opened(frame);
    _frames.add(frame);
    final cases = <CaseBlock>[];
    var closed = false;
    while (true) {
      _skipNewlines();
      if (_atEof) break;
      final closer = _closerAt();
      if (closer == _Closer.case_) {
        _frames.removeLast();
        cases.add(_caseBlock(frame));
        _frames.add(frame);
        continue;
      }
      if (closer == _Closer.endSelect) {
        _consumeCloser(closer!, frame);
        _endOfStatement();
        closed = true;
        break;
      }
      if (closer != null) {
        if (closer == _Closer.procedureStart ||
            _anyFrameAccepts(closer, skipTop: true)) {
          break;
        }
        _beginLine();
        _errorAt(
            _tok, DiagnosticCode.unmatchedCloser, [closer.text, closer.opener]);
        _skipLine();
        continue;
      }
      // A statement before the first Case.
      _beginLine();
      _errorAt(_tok, DiagnosticCode.expectedKeyword, ['Case']);
      _skipLine();
    }
    _frames.removeLast();
    if (!closed) _unclosed(frame);
    return SelectStmt(subject, cases, selectToken.offset, _lastEnd);
  }

  CaseBlock _caseBlock(_Frame frame) {
    _goesOn(frame);
    _beginLine();
    final caseToken = _advance();
    final clauses = <CaseClause>[];
    var isElse = false;
    if (_isKw(Keyword.kwElse)) {
      _advance();
      isElse = true;
    } else {
      do {
        clauses.add(_caseClause());
      } while (_is(TokenKind.comma) && _advance().kind == TokenKind.comma);
    }
    _endOfStatement();
    final body = _block('Body', frame);
    return CaseBlock(clauses, isElse, body, caseToken.offset, _lastEnd);
  }

  CaseClause _caseClause() {
    if (_isKw(Keyword.kwIs)) {
      final start = _tok.offset;
      _advance();
      final op = _relationalTokens[_tok.kind];
      if (op == null) {
        _errorHere(DiagnosticCode.expectedExpression);
        return RelationalClause(
            BinaryOp.equal, ErrorExpr(_lastEnd, _lastEnd), start, _lastEnd);
      }
      _advance();
      final value = _expression();
      return RelationalClause(op, value, start, _lastEnd);
    }
    final value = _expression();
    if (_isKw(Keyword.kwTo)) {
      _advance();
      final high = _expression();
      return RangeClause(value, high, value.start, _lastEnd);
    }
    return ValueClause(value, value.start, _lastEnd);
  }

  Stmt _for() {
    final forToken = _advance();
    if (_isKw(Keyword.kwEach)) {
      _advance();
      final variable = _name();
      final type = _optionalAsType();
      _expectKeyword(Keyword.kwIn);
      final collection = _expression();
      _endOfStatement();
      final frame = _Frame(_BlockKind.forEach, forToken);
      final body = _block('Body', frame);
      final nextName = _next(frame, variable);
      return ForEachStmt(
        variable: variable,
        variableType: type,
        collection: collection,
        body: body,
        nextName: nextName,
        start: forToken.offset,
        end: _lastEnd,
      );
    }
    final variable = _name();
    final type = _optionalAsType();
    _expectSymbol(TokenKind.equal, '=');
    final from = _expression();
    _expectKeyword(Keyword.kwTo);
    final to = _expression();
    Expr? step;
    if (_isKw(Keyword.kwStep)) {
      _advance();
      step = _expression();
    }
    _endOfStatement();
    final frame = _Frame(_BlockKind.for_, forToken);
    final body = _block('Body', frame);
    final nextName = _next(frame, variable);
    return ForStmt(
      variable: variable,
      variableType: type,
      from: from,
      to: to,
      step: step,
      body: body,
      nextName: nextName,
      start: forToken.offset,
      end: _lastEnd,
    );
  }

  TypeRef? _optionalAsType() {
    if (!_isKw(Keyword.kwAs)) return null;
    _advance();
    return _typeRef();
  }

  /// `Next [name]` closing [frame]; reports P010 if the name differs.
  Identifier? _next(_Frame frame, Identifier variable) {
    if (_closerAt() != _Closer.next) {
      _unclosed(frame);
      return null;
    }
    _consumeCloser(_Closer.next, frame);
    Identifier? name;
    if (_is(TokenKind.identifier)) {
      final t = _advance();
      name = Identifier(t.text, t.offset, t.end);
      if (variable.name.isNotEmpty &&
          t.text.toLowerCase() != variable.name.toLowerCase()) {
        _errorAt(
            t, DiagnosticCode.nextVariableMismatch, [t.text, variable.name]);
      }
    }
    _endOfStatement();
    return name;
  }

  LoopCondition? _loopCondition() {
    if (!_isKw(Keyword.kwWhile) && !_isKw(Keyword.kwUntil)) return null;
    final t = _advance();
    final condition = _expression();
    return LoopCondition(
        t.keyword == Keyword.kwUntil, condition, t.offset, _lastEnd);
  }

  DoLoopStmt _do() {
    final doToken = _advance();
    final pre = _loopCondition();
    _endOfStatement();
    final frame = _Frame(_BlockKind.do_, doToken);
    final body = _block('Body', frame);
    LoopCondition? post;
    final closer = _closerAt();
    if (closer == _Closer.loop) {
      _consumeCloser(closer!, frame);
      final conditionToken = _tok;
      post = _loopCondition();
      if (pre != null && post != null) {
        _errorAt(conditionToken, DiagnosticCode.unexpectedToken,
            [conditionToken.text]);
      }
      _endOfStatement();
    } else if (closer == _Closer.wend) {
      _beginLine();
      _errorAt(_advance(), DiagnosticCode.unsupportedWhile);
      _endOfStatement();
    } else {
      _unclosed(frame);
    }
    return DoLoopStmt(pre, post, body, doToken.offset, _lastEnd);
  }

  /// `While c … Wend` (VB6) or `While c … End While` (VB.NET): reported as
  /// P018 and read as `Do While c … Loop`.
  DoLoopStmt _while() {
    final whileToken = _advance();
    _errorAt(whileToken, DiagnosticCode.unsupportedWhile);
    final condition = _expression();
    final pre = LoopCondition(false, condition, whileToken.offset, _lastEnd);
    _endOfStatement();
    final frame = _Frame(_BlockKind.while_, whileToken);
    final body = _block('Body', frame);
    final closer = _closerAt();
    if (closer == _Closer.wend ||
        closer == _Closer.endWhile ||
        closer == _Closer.loop) {
      _consumeCloser(closer!, frame);
      _endOfStatement();
    } else {
      _unclosed(frame);
    }
    return DoLoopStmt(pre, null, body, whileToken.offset, _lastEnd);
  }

  TryStmt _try() {
    final tryToken = _advance();
    _endOfStatement();
    final frame = _Frame(_BlockKind.try_, tryToken);
    final body = _block('Body', frame);
    final catches = <CatchClause>[];
    Block? finallyBlock;
    while (true) {
      final closer = _closerAt();
      if (finallyBlock != null &&
          (closer == _Closer.catch_ || closer == _Closer.finally_)) {
        // Nothing may follow Finally: report, and keep reading its lines
        // as part of the Finally block.
        _beginLine();
        _errorAt(_tok, DiagnosticCode.unexpectedToken, [closer!.text]);
        _skipLine();
        final more = _block('Finally', frame);
        finallyBlock = Block(
            'Finally',
            [...finallyBlock.statements, ...more.statements],
            finallyBlock.start,
            _lastEnd);
        continue;
      }
      if (closer == _Closer.catch_) {
        _goesOn(frame);
        _beginLine();
        final catchToken = _advance();
        Identifier? name;
        TypeRef? type;
        if (_is(TokenKind.identifier)) {
          name = _name();
          type = _optionalAsType();
        }
        _endOfStatement();
        final catchBody = _block('Body', frame);
        catches.add(
            CatchClause(name, type, catchBody, catchToken.offset, _lastEnd));
        continue;
      }
      if (closer == _Closer.finally_) {
        _goesOn(frame);
        _beginLine();
        _advance();
        _endOfStatement();
        finallyBlock = _block('Finally', frame);
        continue;
      }
      if (closer == _Closer.endTry) {
        _consumeCloser(closer!, frame);
        _endOfStatement();
      } else {
        _unclosed(frame);
      }
      break;
    }
    return TryStmt(body, catches, finallyBlock, tryToken.offset, _lastEnd);
  }

  ExitStmt _exit() {
    final exitToken = _advance();
    var kind = Keyword.kwSub;
    const kinds = {
      Keyword.kwFor,
      Keyword.kwDo,
      Keyword.kwSub,
      Keyword.kwFunction,
    };
    if (kinds.contains(_tok.keyword)) {
      kind = _advance().keyword!;
    } else {
      _errorHere(DiagnosticCode.expectedKeyword, ['For / Do / Sub / Function']);
    }
    _endOfStatement();
    return ExitStmt(kind, exitToken.offset, _lastEnd);
  }

  ReDimStmt _reDim() {
    final reDimToken = _advance();
    var preserve = false;
    if (_isKw(Keyword.kwPreserve)) {
      _advance();
      preserve = true;
    }
    final name = _name();
    _expectSymbol(TokenKind.leftParen, '(');
    final bound = _expression();
    _expectSymbol(TokenKind.rightParen, ')');
    _endOfStatement();
    return ReDimStmt(preserve, name, bound, reDimToken.offset, _lastEnd);
  }

  // -------------------------------------------------------------------------
  // Expressions

  bool _startsExpression(Token t) => switch (t.kind) {
        TokenKind.identifier ||
        TokenKind.integerLiteral ||
        TokenKind.doubleLiteral ||
        TokenKind.stringLiteral ||
        TokenKind.dateLiteral ||
        TokenKind.leftParen ||
        TokenKind.minus ||
        TokenKind.plus ||
        TokenKind.error =>
          true,
        TokenKind.keyword => _expressionKeywords.contains(t.keyword),
        _ => false,
      };

  /// Precedence climbing over [BinaryOp.precedence]; every operator is
  /// left-associative.
  Expr _expression([int minPrecedence = 0]) {
    var left = _prefix();
    while (true) {
      final t = _tok;
      final op = t.kind == TokenKind.keyword
          ? _binaryKeywords[t.keyword]
          : _binaryTokens[t.kind];
      if (op == null || op.precedence < minPrecedence) break;
      _advance();
      if (t.keyword == Keyword.kwAndAlso || t.keyword == Keyword.kwOrElse) {
        _errorAt(
            t, DiagnosticCode.unsupportedShortCircuit, [t.text, op.symbol]);
      }
      final right = _expression(op.precedence + 1);
      left = BinaryExpr(op, left, right, left.start, _lastEnd);
    }
    return left;
  }

  Expr _prefix() {
    final t = _tok;
    if (t.kind == TokenKind.minus || t.kind == TokenKind.plus) {
      _advance();
      // Binds looser than ^: -2 ^ 2 is -(2 ^ 2).
      final operand = _expression(BinaryOp.unaryMinusPrecedence + 1);
      return UnaryExpr(
          t.kind == TokenKind.minus ? UnaryOp.negate : UnaryOp.plus,
          operand,
          t.offset,
          _lastEnd);
    }
    if (t.keyword == Keyword.kwNot) {
      _advance();
      // Binds looser than comparisons: Not a = b is Not (a = b).
      final operand = _expression(BinaryOp.notPrecedence + 1);
      return UnaryExpr(UnaryOp.not, operand, t.offset, _lastEnd);
    }
    return _postfix();
  }

  Expr _postfix() {
    var e = _primary();
    while (true) {
      if (_is(TokenKind.dot)) {
        _advance();
        final name = _memberName();
        e = MemberExpr(e, name, e.start, _lastEnd);
      } else if (_is(TokenKind.leftParen)) {
        final arguments = _arguments();
        e = InvokeExpr(e, arguments, e.start, _lastEnd);
      } else {
        return e;
      }
    }
  }

  List<Expr> _arguments() {
    _advance(); // (
    final arguments = <Expr>[];
    _openParens++;
    if (!_is(TokenKind.rightParen)) {
      do {
        arguments.add(_expression());
      } while (_is(TokenKind.comma) && _advance().kind == TokenKind.comma);
    }
    _openParens--;
    _expectSymbol(TokenKind.rightParen, ')');
    return arguments;
  }

  /// `CType(value, Type)`, and the casts read as it (P026).
  Expr _cast() {
    final t = _advance();
    if (!_is(TokenKind.leftParen)) {
      _errorHere(DiagnosticCode.expectedSymbol, ['(']);
      return ErrorExpr(t.offset, _lastEnd);
    }
    _advance();
    _openParens++;
    final operand = _expression();
    _expectSymbol(TokenKind.comma, ',');
    final type = _typeRef();
    _openParens--;
    _expectSymbol(TokenKind.rightParen, ')');
    return CastExpr(operand, type, t.offset, _lastEnd);
  }

  Expr _primary() {
    final t = _tok;
    switch (t.kind) {
      case TokenKind.integerLiteral:
        _advance();
        return IntegerLiteral(t.text, t.value as int?, t.offset, t.end);
      case TokenKind.doubleLiteral:
        _advance();
        // L008 leaves no value; the program cannot run anyway.
        return DoubleLiteral(
            t.text, (t.value as double?) ?? double.infinity, t.offset, t.end);
      case TokenKind.stringLiteral:
        _advance();
        return StringLiteral(t.value! as String, t.offset, t.end);
      case TokenKind.dateLiteral:
        _advance();
        return DateLiteral(t.value! as DateTime, t.offset, t.end);
      case TokenKind.identifier:
        if (_otherCasts.contains(t.text.toLowerCase()) &&
            _peek(1).kind == TokenKind.leftParen) {
          // `DirectCast(c, TextBox)`: GuBASIC writes CType (P026).
          _errorAt(t, DiagnosticCode.otherCast, [t.text]);
          return _cast();
        }
        _advance();
        return NameExpr(t.text, t.offset, t.end);
      case TokenKind.leftParen:
        _advance();
        _openParens++;
        final inner = _expression();
        _openParens--;
        _expectSymbol(TokenKind.rightParen, ')');
        return ParenExpr(inner, t.offset, _lastEnd);
      case TokenKind.error:
        // Already reported by the lexer.
        _advance();
        return ErrorExpr(t.offset, t.end);
      case TokenKind.keyword:
        switch (t.keyword) {
          case Keyword.kwTrue || Keyword.kwFalse:
            _advance();
            return BooleanLiteral(t.keyword == Keyword.kwTrue, t.offset, t.end);
          case Keyword.kwNothing:
            _advance();
            return NothingLiteral(t.offset, t.end);
          case Keyword.kwMe:
            _advance();
            return MeExpr(t.offset, t.end);
          case Keyword.kwNew:
            _advance();
            final type = _typeRef();
            final arguments = _is(TokenKind.leftParen) ? _arguments() : null;
            return NewExpr(type, arguments, t.offset, _lastEnd);
          case Keyword.kwTypeOf:
            _advance();
            final operand = _postfix();
            _expectKeyword(Keyword.kwIs);
            final type = _typeRef();
            return TypeOfExpr(operand, type, t.offset, _lastEnd);
          case Keyword.kwCType:
            return _cast();
          default:
        }
      default:
    }
    // The line ended inside an open parenthesis: both the value and ")"
    // are missing. One diagnostic says both (P023), instead of P001 now and
    // P003 after the first one is fixed.
    _errorHere(_openParens > 0 && _atStatementEnd
        ? DiagnosticCode.expectedValueAndParen
        : DiagnosticCode.expectedExpression);
    return ErrorExpr(_lastEnd, _lastEnd);
  }
}
