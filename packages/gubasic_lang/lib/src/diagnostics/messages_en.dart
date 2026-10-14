import 'diagnostic.dart';

/// English diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
///
/// Each message says what is wrong and how to fix it, in one or two
/// sentences.
const Map<DiagnosticCode, String> englishMessages = {
  // Lexer
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
      'If you need a larger number, add a decimal point to make it a Double '
      '(for example {0}.0).',

  // Parser: structure
  DiagnosticCode.expectedExpression: 'A value or expression is missing here. '
      'Write the value, or remove the operator or comma before it.',
  DiagnosticCode.expectedKeyword:
      'The keyword "{0}" is missing here. Add it to complete the statement.',
  DiagnosticCode.expectedSymbol:
      'The symbol "{0}" is missing here. Add it to complete the statement.',
  DiagnosticCode.expectedName:
      'A name is missing here. Write a name that starts with an English '
          'letter.',
  DiagnosticCode.unexpectedToken:
      '"{0}" does not belong here. Check for a typo or a missing line break.',
  DiagnosticCode.unclosedBlock:
      'The {0} block that starts on line {1} is never closed. '
          'Add "{2}" where the block should end.',
  DiagnosticCode.unmatchedCloser: '"{0}" has no matching "{1}". '
      'Remove it, or add the "{1}" statement before it.',
  DiagnosticCode.statementOutsideProcedure:
      'Statements must be inside a Sub or Function. '
          'Only declarations (Dim, Const, Sub, Function) can be written here.',
  DiagnosticCode.declarationNotAllowedHere:
      '"{0}" cannot be used here. Inside a procedure, declare with Dim, '
          'Static or Const; outside, use Dim, Private, Public or Const.',
  DiagnosticCode.nextVariableMismatch: '"Next {0}" does not match "For {1}". '
      'Use the same name, or write just "Next".',
  DiagnosticCode.callWithoutParentheses:
      'GuBASIC puts arguments in parentheses. '
          'Write the call as Name(arguments), for example MsgBox("Hi").',
  DiagnosticCode.oneVariablePerDeclaration: 'Declare one variable per line. '
      'Put the next variable in its own Dim statement.',

  // Parser: Visual Basic features GuBASIC does not support
  DiagnosticCode.unsupportedOnError: 'GuBASIC does not support On Error. '
      'Use Try ... Catch ... End Try around the code that can fail.',
  DiagnosticCode.unsupportedGoTo: 'GuBASIC does not support {0}. '
      'Use a loop, Exit, or a separate Sub or Function instead.',
  DiagnosticCode.unsupportedVariant: 'GuBASIC has no Variant type. '
      'Use Object when a variable must hold any kind of value.',
  DiagnosticCode.unsupportedClass:
      'User-defined classes are not available in GuBASIC 1.0. '
          'Use a module with Sub and Function procedures instead.',
  DiagnosticCode.unsupportedShortCircuit: 'GuBASIC has no {0}. '
      'Use {1}: it already skips the right side when the result is known.',
  DiagnosticCode.unsupportedWhile:
      'GuBASIC does not have While ... Wend. Use Do While ... Loop instead.',
  DiagnosticCode.unsupportedCall:
      'GuBASIC does not use Call. Remove it and call the procedure directly, '
          'for example ShowScore("Kim", 90).',
  DiagnosticCode.unsupportedSetLet:
      'GuBASIC does not use {0}. Remove it and assign directly: x = value.',
  DiagnosticCode.plannedForStage2: '{0} is not available yet; it is planned '
      'for stage 2. Remove it for now.',
};
