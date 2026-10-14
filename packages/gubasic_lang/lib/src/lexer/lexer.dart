import '../diagnostics/diagnostic.dart';
import 'keyword.dart';
import 'token.dart';

/// The output of [lex].
class LexResult {
  const LexResult(this.tokens, this.comments, this.diagnostics);

  /// Tokens for the parser. Never contains comments; always ends with
  /// [TokenKind.eof], preceded by a [TokenKind.newline] when the source has
  /// any tokens.
  final List<Token> tokens;

  /// Comment tokens, in source order (for syntax highlighting).
  final List<Token> comments;

  final List<Diagnostic> diagnostics;

  bool get hasErrors => diagnostics.isNotEmpty;
}

/// Turns GuBASIC source into tokens.
///
/// Never throws: problems become [TokenKind.error] tokens (or ordinary
/// tokens) plus [Diagnostic]s, and lexing continues to the end.
LexResult lex(String source) => _Lexer(source).run();

// Character codes.
const _tab = 0x09;
const _lf = 0x0A;
const _cr = 0x0D;
const _space = 0x20;
const _quote = 0x22; // "
const _ampersand = 0x26; // &
const _apostrophe = 0x27; // '
const _leftParen = 0x28;
const _rightParen = 0x29;
const _star = 0x2A;
const _plus = 0x2B;
const _comma = 0x2C;
const _minus = 0x2D;
const _dot = 0x2E;
const _slash = 0x2F;
const _digit0 = 0x30;
const _digit9 = 0x39;
const _colon = 0x3A;
const _less = 0x3C;
const _equal = 0x3D;
const _greater = 0x3E;
const _backslash = 0x5C;
const _caret = 0x5E;
const _underscore = 0x5F;
const _bom = 0xFEFF;

bool _isDigit(int c) => c >= _digit0 && c <= _digit9;
bool _isAsciiLetter(int c) =>
    (c >= 0x41 && c <= 0x5A) || (c >= 0x61 && c <= 0x7A);
bool _isNonAscii(int c) => c >= 0x80;
bool _isLineBreak(int c) => c == _lf || c == _cr;

/// A character that can continue a word. Non-ASCII characters are taken
/// into the word so that `점수` or `name이름` becomes one identifier with one
/// L002 diagnostic, rather than a run of errors.
bool _isWordPart(int c) =>
    _isAsciiLetter(c) || _isDigit(c) || c == _underscore || _isNonAscii(c);

const _singleCharTokens = {
  _plus: TokenKind.plus,
  _minus: TokenKind.minus,
  _star: TokenKind.star,
  _slash: TokenKind.slash,
  _backslash: TokenKind.backslash,
  _caret: TokenKind.caret,
  _ampersand: TokenKind.ampersand,
  _equal: TokenKind.equal,
  _leftParen: TokenKind.leftParen,
  _rightParen: TokenKind.rightParen,
  _comma: TokenKind.comma,
  _dot: TokenKind.dot,
};

class _Lexer {
  _Lexer(this._src);

  final String _src;
  int _pos = 0;
  int _line = 1;
  int _lineStart = 0;

  final _tokens = <Token>[];
  final _comments = <Token>[];
  final _diagnostics = <Diagnostic>[];

  bool get _atEnd => _pos >= _src.length;
  int _peek([int ahead = 0]) {
    final i = _pos + ahead;
    return i < _src.length ? _src.codeUnitAt(i) : -1;
  }

  LexResult run() {
    if (_peek() == _bom) {
      _pos = 1;
      _lineStart = 1;
    }
    while (!_atEnd) {
      _scanOne();
    }
    if (_tokens.isNotEmpty && _tokens.last.kind != TokenKind.newline) {
      _emit(TokenKind.newline, _pos);
    }
    _emit(TokenKind.eof, _pos);
    return LexResult(_tokens, _comments, _diagnostics);
  }

  void _scanOne() {
    final start = _pos;
    final c = _peek();

    if (c == _space || c == _tab) {
      _pos++;
    } else if (_isLineBreak(c)) {
      _lineBreak();
    } else if (c == _apostrophe) {
      _comment(start);
    } else if (_isAsciiLetter(c) || _isNonAscii(c)) {
      _word(start);
    } else if (_isDigit(c)) {
      _number(start);
    } else if (c == _quote) {
      _string(start);
    } else if (c == _underscore) {
      _underscoreOrContinuation(start);
    } else if (c == _colon) {
      _pos++;
      _report(DiagnosticCode.statementSeparator, start);
      _emitNewline(start);
    } else if (c == _less) {
      _pos++;
      if (_peek() == _equal) {
        _pos++;
        _emit(TokenKind.lessEqual, start);
      } else if (_peek() == _greater) {
        _pos++;
        _emit(TokenKind.notEqual, start);
      } else {
        _emit(TokenKind.less, start);
      }
    } else if (c == _greater) {
      _pos++;
      if (_peek() == _equal) {
        _pos++;
        _emit(TokenKind.greaterEqual, start);
      } else {
        _emit(TokenKind.greater, start);
      }
    } else if (_singleCharTokens[c] case final kind?) {
      _pos++;
      _emit(kind, start);
    } else {
      _pos++;
      _report(DiagnosticCode.unexpectedCharacter, start, [_describe(c)]);
      _emit(TokenKind.error, start);
    }
  }

  /// Consumes one line break (`\n`, `\r\n` or `\r`).
  void _consumeLineBreak() {
    if (_peek() == _cr && _peek(1) == _lf) {
      _pos += 2;
    } else {
      _pos++;
    }
    _line++;
    _lineStart = _pos;
  }

  void _lineBreak() {
    final start = _pos;
    final line = _line;
    final column = start - _lineStart + 1;
    _consumeLineBreak();
    _emitNewline(start, line: line, column: column);
  }

  /// Emits a newline token unless it would be the first token or follow
  /// another newline: blank lines collapse into one.
  void _emitNewline(int start, {int? line, int? column}) {
    if (_tokens.isEmpty || _tokens.last.kind == TokenKind.newline) return;
    _emit(TokenKind.newline, start, line: line, column: column);
  }

  void _skipToLineEnd() {
    while (!_atEnd && !_isLineBreak(_peek())) {
      _pos++;
    }
  }

  void _comment(int start) {
    _skipToLineEnd();
    _comments.add(_make(TokenKind.comment, start));
  }

  void _word(int start) {
    var nonAscii = false;
    while (!_atEnd && _isWordPart(_peek())) {
      if (_isNonAscii(_peek())) nonAscii = true;
      _pos++;
    }
    final text = _src.substring(start, _pos);

    if (nonAscii) {
      _report(DiagnosticCode.nonAsciiIdentifier, start, [text]);
      _emit(TokenKind.identifier, start);
      return;
    }
    final keyword = Keyword.lookup(text);
    if (keyword != null) {
      _emit(TokenKind.keyword, start, keyword: keyword);
    } else if (text.toLowerCase() == 'rem') {
      _comment(start);
    } else {
      _emit(TokenKind.identifier, start);
    }
  }

  void _number(int start) {
    while (_isDigit(_peek())) {
      _pos++;
    }
    // A fraction needs digits on both sides of the dot: `1.` is `1` `.`.
    if (_peek() == _dot && _isDigit(_peek(1))) {
      _pos++;
      while (_isDigit(_peek())) {
        _pos++;
      }
      final text = _src.substring(start, _pos);
      _emit(TokenKind.doubleLiteral, start, value: double.parse(text));
      return;
    }
    final text = _src.substring(start, _pos);
    if (_exceedsInt64(text)) {
      _report(DiagnosticCode.integerTooLarge, start, [text]);
      _emit(TokenKind.integerLiteral, start);
    } else {
      _emit(TokenKind.integerLiteral, start, value: int.parse(text));
    }
  }

  /// Whether the digits in [text] exceed 2⁶³−1. Checked on the digits
  /// rather than with `int.tryParse`, which never fails on the web
  /// (numbers there are doubles), so the rule is the same on every platform.
  static bool _exceedsInt64(String text) {
    const max = '9223372036854775807';
    final digits = text.replaceFirst(RegExp('^0+(?=.)'), '');
    if (digits.length != max.length) return digits.length > max.length;
    return digits.compareTo(max) > 0;
  }

  void _string(int start) {
    _pos++; // opening quote
    final buffer = StringBuffer();
    while (true) {
      final c = _peek();
      if (c == -1 || _isLineBreak(c)) {
        // Unterminated: the rest of the line becomes one error token, and
        // lexing resumes on the next line.
        _report(DiagnosticCode.unterminatedString, start);
        _emit(TokenKind.error, start);
        return;
      }
      _pos++;
      if (c == _quote) {
        if (_peek() == _quote) {
          _pos++;
          buffer.writeCharCode(_quote);
        } else {
          _emit(TokenKind.stringLiteral, start, value: buffer.toString());
          return;
        }
      } else {
        buffer.writeCharCode(c);
      }
    }
  }

  /// `_` followed only by spaces or tabs up to the end of the line joins the
  /// next line to this one. Anywhere else it is L005.
  void _underscoreOrContinuation(int start) {
    var i = _pos + 1;
    while (i < _src.length &&
        (_src.codeUnitAt(i) == _space || _src.codeUnitAt(i) == _tab)) {
      i++;
    }
    if (i >= _src.length || _isLineBreak(_src.codeUnitAt(i))) {
      _pos = i;
      if (!_atEnd) _consumeLineBreak();
      return;
    }
    _pos++;
    _report(DiagnosticCode.misplacedLineContinuation, start);
    _emit(TokenKind.error, start);
  }

  Token _make(
    TokenKind kind,
    int start, {
    int? line,
    int? column,
    Keyword? keyword,
    Object? value,
  }) =>
      Token(
        kind: kind,
        text: _src.substring(start, _pos),
        line: line ?? _line,
        column: column ?? start - _lineStart + 1,
        offset: start,
        keyword: keyword,
        value: value,
      );

  void _emit(
    TokenKind kind,
    int start, {
    int? line,
    int? column,
    Keyword? keyword,
    Object? value,
  }) {
    _tokens.add(_make(kind, start,
        line: line, column: column, keyword: keyword, value: value));
  }

  void _report(DiagnosticCode code, int start, [List<String> args = const []]) {
    _diagnostics.add(Diagnostic(
      code: code,
      line: _line,
      column: start - _lineStart + 1,
      offset: start,
      length: _pos - start,
      args: args,
    ));
  }

  static String _describe(int c) => c < _space || c == 0x7F
      ? 'U+${c.toRadixString(16).toUpperCase().padLeft(4, '0')}'
      : String.fromCharCode(c);
}
