import 'messages_en.dart';

/// How serious a diagnostic is. Errors must be fixed; warnings point out
/// something that works but may surprise, and never stop a program from
/// running or being built.
enum DiagnosticSeverity { error, warning }

/// Every diagnostic GuBASIC can report. Codes are stable: never reuse or
/// renumber one. The prefix says who reports it (L lexer, P parser); the
/// severity is separate. The full list is documented in docs/LANGUAGE.md.
enum DiagnosticCode {
  /// A string literal has no closing quote on its line.
  unterminatedString('L001'),

  /// Non-ASCII text outside a string or comment.
  nonAsciiIdentifier('L002'),

  /// `:` used to put several statements on one line.
  statementSeparator('L003'),

  /// A character that has no meaning in GuBASIC.
  unexpectedCharacter('L004'),

  /// `_` that is not the last thing on its line.
  misplacedLineContinuation('L005'),

  /// An integer literal that does not fit in 64 bits.
  integerTooLarge('L006'),

  /// An integer literal above 2⁵³−1, which the web cannot store exactly.
  integerInexactOnWeb('L007', DiagnosticSeverity.warning),

  // Parser: structure

  /// An expression is missing.
  expectedExpression('P001'),

  /// A keyword is missing. Args: the keyword (`Then`, `To`, …).
  expectedKeyword('P002'),

  /// A symbol is missing. Args: the symbol (`)`, `=`, …).
  expectedSymbol('P003'),

  /// A name is missing.
  expectedName('P004'),

  /// Something that does not belong here. Args: its text.
  unexpectedToken('P005'),

  /// A block is not closed. Args: block, line it started on, closing
  /// statement (`If`, `3`, `End If`).
  unclosedBlock('P006'),

  /// A closing statement with no open block. Args: the closer, the opener
  /// (`End If`, `If`).
  unmatchedCloser('P007'),

  /// A statement outside any `Sub` or `Function`.
  statementOutsideProcedure('P008'),

  /// A declaration that cannot appear here. Args: its keyword.
  declarationNotAllowedHere('P009'),

  /// `Next j` closing `For i`. Args: the two names.
  nextVariableMismatch('P010'),

  /// `MsgBox "Hi"`: a call with arguments but no parentheses.
  callWithoutParentheses('P011'),

  /// `Dim a, b`: more than one variable in one declaration.
  oneVariablePerDeclaration('P012'),

  // Parser: Visual Basic features GuBASIC does not support

  /// `On Error`.
  unsupportedOnError('P013'),

  /// `GoTo`, `GoSub`. Args: the keyword.
  unsupportedGoTo('P014'),

  /// `Variant`.
  unsupportedVariant('P015'),

  /// `Class`.
  unsupportedClass('P016'),

  /// `AndAlso`, `OrElse`. Args: the keyword, the replacement.
  unsupportedShortCircuit('P017'),

  /// `While … Wend` / `While … End While`.
  unsupportedWhile('P018'),

  /// `Call`.
  unsupportedCall('P019'),

  /// `Set`, `Let`. Args: the keyword.
  unsupportedSetLet('P020'),

  /// `ByRef`: not available yet (planned for stage 2).
  byRefNotAvailable('P021'),

  /// `Handles`: not available yet (planned for stage 2).
  handlesNotAvailable('P022');

  const DiagnosticCode(this.code, [this.severity = DiagnosticSeverity.error]);

  /// The stable code shown to users, e.g. `L001`.
  final String code;

  final DiagnosticSeverity severity;
}

/// A problem found in GuBASIC source.
///
/// The message is not stored; it is looked up by [code] in a message
/// catalog, so that other languages (Korean) can be added later without
/// touching the lexer or parser.
class Diagnostic {
  const Diagnostic({
    required this.code,
    required this.line,
    required this.column,
    required this.offset,
    required this.length,
    this.args = const [],
  });

  final DiagnosticCode code;
  DiagnosticSeverity get severity => code.severity;
  bool get isError => severity == DiagnosticSeverity.error;
  bool get isWarning => severity == DiagnosticSeverity.warning;

  final int line;
  final int column;
  final int offset;
  final int length;

  /// Values substituted into the message template as `{0}`, `{1}`, ….
  final List<String> args;

  /// The English message.
  String get message => formatMessage(englishMessages);

  /// The message from [catalog], falling back to English for missing codes.
  String formatMessage(Map<DiagnosticCode, String> catalog) {
    var text = catalog[code] ?? englishMessages[code]!;
    for (var i = 0; i < args.length; i++) {
      text = text.replaceAll('{$i}', args[i]);
    }
    return text;
  }

  @override
  String toString() => '${code.code} @$line:$column $message';
}
