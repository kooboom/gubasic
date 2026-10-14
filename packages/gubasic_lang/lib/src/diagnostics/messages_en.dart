import 'diagnostic.dart';

/// English diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
const Map<DiagnosticCode, String> englishMessages = {
  DiagnosticCode.unterminatedString:
      'This string has no closing quote ("). Close it on the same line.',
  DiagnosticCode.nonAsciiIdentifier:
      'Identifiers can only use English letters, digits and "_". '
          '"{0}" contains other characters. '
          'Other languages are fine inside strings and comments.',
  DiagnosticCode.statementSeparator:
      'GuBASIC allows only one statement per line. '
          'Put the next statement on a new line instead of using ":".',
  DiagnosticCode.unexpectedCharacter:
      'The character "{0}" has no meaning in GuBASIC.',
  DiagnosticCode.misplacedLineContinuation:
      '"_" continues a line only when it is the last thing on the line.',
  DiagnosticCode.integerTooLarge: 'The number {0} is too large for an Integer.',
};
