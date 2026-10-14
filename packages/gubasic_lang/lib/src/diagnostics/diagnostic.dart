import 'messages_en.dart';

/// Every diagnostic GuBASIC can report. Codes are stable: never reuse or
/// renumber one. The full list is documented in docs/LANGUAGE.md.
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
  integerTooLarge('L006');

  const DiagnosticCode(this.code);

  /// The stable code shown to users, e.g. `L001`.
  final String code;
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
