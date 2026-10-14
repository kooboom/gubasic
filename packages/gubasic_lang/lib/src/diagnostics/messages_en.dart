import 'diagnostic.dart';

/// English diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
///
/// Each message says what is wrong and how to fix it, in one or two
/// sentences.
const Map<DiagnosticCode, String> englishMessages = {
  DiagnosticCode.unterminatedString: 'This string has no closing quote ("). '
      'Close it with " on the same line.',
  DiagnosticCode.nonAsciiIdentifier:
      'Names can only use English letters, digits and "_", '
          'but "{0}" contains other characters. '
          'Put Korean or other text in a string ("...") or a comment (\').',
  DiagnosticCode.statementSeparator:
      'GuBASIC allows only one statement per line. '
          'Put the next statement on a new line instead of using ":".',
  DiagnosticCode.unexpectedCharacter:
      'The character "{0}" has no meaning in GuBASIC. '
          'Remove it, or put it in a string ("...") if it is meant as text.',
  DiagnosticCode.misplacedLineContinuation:
      '"_" continues a statement only when it is the last thing on the line. '
          'Move it to the end of the line or remove it; '
          'names must start with a letter.',
  DiagnosticCode.integerTooLarge: 'The number {0} is too large for an Integer '
      '(the largest is 9223372036854775807). '
      'For a larger, approximate value, write it as a Double: {0}.0',
};
