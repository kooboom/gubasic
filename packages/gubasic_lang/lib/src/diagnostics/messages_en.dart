import 'diagnostic.dart';

/// English diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
///
/// Each message says what is wrong and how to fix it, in one or two
/// sentences. A suggested fix never silently changes what the program
/// means; if it has a trade-off, the message says so.
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
  DiagnosticCode.integerTooLarge: 'The number {0} is too large for an Integer, '
      'which holds up to 9223372036854775807. '
      'If an approximate value is enough, you can add a decimal point to make '
      'it a Double ({0}.0), but its last digits may change.',
  DiagnosticCode.doubleTooLarge: 'The number {0} is too large for a Double '
      '(the largest is about 1.7976931348623157E+308). Use a smaller number.',
  DiagnosticCode.doubleBecomesZero: 'This number is so small that it becomes '
      '0 as a Double (you wrote {0}). If you meant 0, write 0.',
  DiagnosticCode.integerTooLargeMinValue: 'The number {0} is too large for '
      'an Integer, which holds up to 9223372036854775807. If you need the '
      'smallest Integer (-9223372036854775808), use Integer.MinValue.',

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
      'Statements must be inside a Sub or Function. Outside them, only '
          'declarations (Dim, Private, Public, Const) and Sub or Function '
          'can be written.',
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
      'Put the code that can fail between Try and Catch ex As Exception, and '
      'what to do instead (ex.Message says what went wrong) before End Try.',
  DiagnosticCode.unsupportedGoTo: 'GuBASIC does not support {0}. '
      'Use a loop, Exit, or a separate Sub or Function instead.',
  DiagnosticCode.unsupportedVariant: 'GuBASIC has no Variant type. '
      'Use Object when a variable must hold any kind of value.',
  DiagnosticCode.unsupportedClass:
      'User-defined classes are not available in GuBASIC 1.0. '
          'Write Sub or Function procedures in a module instead.',
  DiagnosticCode.unsupportedShortCircuit: 'GuBASIC has no {0}. '
      'Use {1} instead: And and Or also skip the right side when the left '
      'side already decides the result.',
  DiagnosticCode.unsupportedWhile:
      'GuBASIC does not have While ... Wend. Use Do While ... Loop instead.',
  DiagnosticCode.unsupportedCall:
      'GuBASIC does not use Call. Remove it and call the procedure directly, '
          'for example ShowScore("Kim", 90).',
  DiagnosticCode.unsupportedSetLet:
      'GuBASIC does not use {0}. Remove it and assign directly: x = value.',
  DiagnosticCode.byRefNotAvailable: 'ByRef is not available yet. '
      'To get a changed value back, write a Function and give the value '
      'back with Return.',
  DiagnosticCode.otherCast: 'GuBASIC turns a control into another type '
      'with CType: write CType(value, Type) instead of {0}(value, Type).',
  DiagnosticCode.loadControl: 'GuBASIC has no control arrays, so there is '
      'no Load for a control. Make one with Dim b As New Button, then put it '
      'on the form with Me.Controls.Add(b).',
  DiagnosticCode.unloadControl: 'GuBASIC has no control arrays, so there is '
      'no Unload for a control. Take one off the form with '
      'Me.Controls.Remove(control).',
  DiagnosticCode.expectedValueAndParen:
      'A value and the symbol ")" are missing here. Write the value, then '
          'close the parenthesis.',
  DiagnosticCode.unloadStatement: 'GuBASIC closes a form with a method, '
      'not Unload: write {0}.Close.',
  DiagnosticCode.loadStatement: 'GuBASIC has no Load statement: to show a '
      'form, write {0}.Show. To call a procedure, put its arguments in '
      'parentheses.',

  // Analyzer: names
  DiagnosticCode.unknownName: '"{0}" is not declared. '
      'Declare it with Dim first, or check the spelling.',
  DiagnosticCode.unknownNameDidYouMean: '"{0}" is not declared. '
      'There is a similar name, "{1}"; check the spelling.',
  DiagnosticCode.unknownNameMaybeControl: '"{0}" is not declared. '
      'This code has no form, so controls and Me cannot be used here (the '
      'playground runs code without a form); use variables declared with '
      'Dim, or open the code as a project with a form.',
  DiagnosticCode.unknownType:
      'There is no type named "{0}". Check the spelling.',
  DiagnosticCode.duplicateDeclaration:
      '"{0}" is already declared on line {1}. Use a different name.',
  DiagnosticCode.usedBeforeDeclaration:
      '"{0}" is used before its declaration on line {1}. '
          'Move the declaration above this line.',
  DiagnosticCode.missingTypeAndValue: '"{0}" needs a type. Add As and a type, '
      'for example {0} As Integer; a Dim can give an initial value instead '
      '(Dim {0} = 0).',

  // Analyzer: types
  DiagnosticCode.typeMismatch:
      'A value of type {0} cannot be stored where {1} is expected. '
          'Convert it with a function such as CInt, CDbl, CStr or CBool if '
          'that is what you mean.',
  DiagnosticCode.stringToNumber:
      'Text is not turned into a number automatically. '
          'Use CInt (whole number), CDbl or Val to convert it.',
  DiagnosticCode.doubleToInteger:
      'A Double is not turned into an Integer automatically, because the '
          'fraction would be lost. Use CInt to round (2.5 becomes 3, -2.5 '
          'becomes -3), or Int to round down to the smaller whole number '
          '(Int(-2.5) is -3).',
  DiagnosticCode.stringPlusNumber:
      'Text and a number cannot be joined with "+". Use "&" to join them as '
          'text, or convert the text with CInt or CDbl to add numbers.',
  DiagnosticCode.conditionNotBoolean: 'A condition must be True or False, '
      'but this expression is of type {0}. Compare it instead, for example '
      'x <> 0.',
  DiagnosticCode.binaryOperatorNotApplicable:
      'The operator {0} cannot be used with {1} and {2}. Check both sides: '
          'And, Or and Xor need True/False values, and Is compares objects '
          '(use = for values).',
  DiagnosticCode.unaryOperatorNotApplicable:
      'The operator {0} cannot be used with {1}. '
          '"-" and "+" need a number; Not needs True or False.',

  // Analyzer: calls, members, assignment
  DiagnosticCode.wrongArgumentCount:
      '{0} expects {1} argument(s), but {2} were given. Check the call.',
  DiagnosticCode.notCallable: '"{0}" is not a Sub or Function, so it cannot '
      'be called. Check the name.',
  DiagnosticCode.subHasNoValue: '{0} is a Sub and gives back no value. Call '
      'it on its own line, or make it a Function that uses Return.',
  DiagnosticCode.notIndexable: 'A value of type {0} has no numbered items. '
      'Only arrays and lists can be used with (index); for text, use Mid.',
  DiagnosticCode.unknownMember:
      '{0} has no member named "{1}". Check the spelling.',
  DiagnosticCode.unknownMemberDidYouMean: '{0} has no member named "{1}". '
      'There is a similar member, "{2}"; check the spelling.',
  DiagnosticCode.unknownPictureInCode: '"{0}" is not one of this project\'s '
      'pictures, so the program will stop here when it runs. Add the picture '
      'to the project, or check its name.',
  DiagnosticCode.showWithArgument: 'Show takes no argument. To show the '
      'form as a dialog and wait until it is closed, write {0}.ShowDialog.',
  DiagnosticCode.badAnchorInCode: '"{0}" is not an Anchor, so the program '
      'will stop here when it runs. Name the edges the control keeps its '
      'distance to with Left, Top, Right and Bottom, as in "Right Bottom", '
      'or "" for none.',
  DiagnosticCode.memberHasOtherName: '{0} has no member named "{1}". '
      'GuBASIC calls it differently: use {2}.',
  DiagnosticCode.notAssignable: '"{0}" cannot be given a value. Only '
      'variables, items of arrays or lists, and properties can be on the '
      'left of "=" (constants, procedures and call results cannot change).',
  DiagnosticCode.assignToFunctionName:
      'In GuBASIC a Function gives back its value with Return. '
          'Write Return value instead of {0} = value.',
  DiagnosticCode.returnValueInSub:
      'A Sub gives back no value, so Return must stand alone here. Remove '
          'the value, or make this procedure a Function.',
  DiagnosticCode.returnWithoutValue: 'A Function must give back a value. '
      'Write the value after Return.',
  DiagnosticCode.exitOutsideBlock: '{0} can only be used inside a matching '
      'loop or procedure. Remove it, or move it inside.',
  DiagnosticCode.cannotLoopOver: 'For Each cannot go through a value of '
      'type {0}. Use a List or an array.',

  // Analyzer: warnings
  DiagnosticCode.unusedLocal:
      '"{0}" is declared but never used. Remove it if it is not needed.',
  DiagnosticCode.functionWithoutReturn: 'Function {0} has no Return, so it '
      'always gives back the default value. Add Return with the value to '
      'give back.',
  DiagnosticCode.nameIsControl: '"{0}" is already the name of a control on '
      'the form. Use a different name here, or rename the control.',
  DiagnosticCode.localHidesControl: 'This local "{0}" hides the control of '
      'the same name, which cannot be reached here. Rename the local.',
  DiagnosticCode.handlerSignature: '{0} runs for the event {1}, so its first '
      'line must be {2}. Change it to that, or rename the procedure if it is '
      'not meant to handle the event.',
  DiagnosticCode.unknownEvent: '{0} is a {1}, which has no event named '
      '"{2}". Check the spelling, or the control.',
  DiagnosticCode.eventHandledTwice: 'The event {0} is already handled by '
      '{1}, and an event has one handler. Remove it from one of the two.',
  DiagnosticCode.handlerNameMismatch: '{0} is named as the handler of {1}, '
      'but its Handles does not list it, so it does not run for {1}. Add '
      '{1} to Handles, or rename the procedure.',
  DiagnosticCode.senderTypeMismatch: '{0} handles {1}, a {2}, but its '
      'sender is a {3}, which cannot hold it. Write sender As {2}, or '
      'sender As Control for controls of different types.',
  DiagnosticCode.netHandlerSignature: 'GuBASIC tells a handler which '
      'control raised the event with one parameter of its type: write '
      '({1}), or leave the parentheses empty. {0} cannot take Object and '
      'EventArgs.',
  DiagnosticCode.castNeedsControlType: '{0} is not a control type. CType '
      'and TypeOf work with controls; for numbers and text, use CInt, CDbl '
      'or CStr.',
  DiagnosticCode.controlNarrowing: 'A {0} may hold any control, not only '
      'a {1}. Write CType(value, {1}), after checking with TypeOf value Is '
      '{1} if it may be another control.',
  DiagnosticCode.newForm: '{0} is not made with New: a project\'s forms '
      'are used by their names, as in Form2.Show, and Control is the type '
      'of any control. Make a particular control, such as New Button.',
  DiagnosticCode.controlArrayHandler: 'GuBASIC has no control arrays, so '
      'a handler gets no Index. To handle several controls with {0}, list '
      'them after Handles and take the one clicked as sender: Sub '
      'Pressed(sender As {2}) Handles {1}, … A Tag can number them.',
  DiagnosticCode.controlArrayItem: '{0} is one control: GuBASIC has no '
      'control arrays. Give each control its own name, or go through them '
      'with For Each c As Control In Me.Controls; a Tag can number them.',
  DiagnosticCode.eventHasOtherName: 'GuBASIC calls the event {0} '
      'differently: it is {1}. Write {2}.',
  DiagnosticCode.placedInDesigner: 'A {0} is put on the form in the '
      'designer, not made with New. Add one from the toolbox, and set its '
      'properties in code.',
  DiagnosticCode.vb6KeyHandler: 'GuBASIC tells a key event its key in one '
      'parameter: write {1}, then read e.KeyCode (as in e.KeyCode = '
      'Keys.Left) and e.Shift, e.Control and e.Alt.',
  DiagnosticCode.ambiguousName: '{0} is Public in {1}, so it is not clear '
      'which is meant here. Write it with its module\'s name, as in {2}.',
  DiagnosticCode.mainTwice: '{0} has a Sub Main too, and a program starts '
      'with one. Keep Sub Main in one module, and rename the other.',
  DiagnosticCode.notAProcedure: '"{0}" is not a Sub of this code, so it '
      'cannot handle an event. Name a Sub after AddressOf.',
  DiagnosticCode.readOnlyProperty:
      '"{0}" can only be read: the program cannot give it a value.',

  // Form and project files
  DiagnosticCode.fileSyntax: 'This file cannot be read from here on: the '
      'text is not in the expected layout. Check the indentation and the '
      'colon after each key.',
  DiagnosticCode.formatVersionMissing: 'The file needs a formatVersion line '
      'with a whole number, for example formatVersion: 1.',
  DiagnosticCode.formatVersionTooNew: 'This file was written by a newer '
      'GuBASIC (formatVersion {0}); this GuBASIC reads up to {1}. Update '
      'GuBASIC to open it.',
  DiagnosticCode.unknownKey:
      '"{0}" is not a key GuBASIC knows, so it is ignored. Check the spelling.',
  DiagnosticCode.wrongValueForm:
      '"{0}" is not written in the expected form. Write it like {1}.',
  DiagnosticCode.invalidControlName: '"{0}" cannot be used as a name. A name '
      'starts with an English letter and goes on with letters, digits or _; '
      'it cannot be a keyword or Form.',
  DiagnosticCode.duplicateControlName: 'The name "{0}" is already used on '
      'line {1}. Give each control and each form its own name.',
  DiagnosticCode.unknownControlType: 'There is no control type "{0}". '
      'Check the spelling (the types are: {1}).',
  DiagnosticCode.unknownProperty: 'A {1} has no property "{0}". Check the '
      'spelling (its properties are: {2}).',
  DiagnosticCode.wrongPropertyType:
      'The value of {0} must be of type {1}. Check the value.',
  DiagnosticCode.unknownStartupForm: 'The startup form "{0}" is not in the '
      'list of forms. Add it to forms, or choose a form that is listed.',
  DiagnosticCode.propertyOutOfRange: 'The value of {0} must be from {1} '
      'to {2}. Check the value.',
  DiagnosticCode.invalidPictureName: '"{0}" cannot be the name of a picture. '
      'A picture\'s name ends in .png, .jpg, .jpeg or .gif and has none of '
      '/ \\ : * ? " < > |.',
  DiagnosticCode.duplicatePicture: '"{0}" differs from "{1}" (line {2}) only '
      'in upper and lower case. GuBASIC does not tell them apart, as on '
      'Windows and macOS, so a project cannot have both; rename one.',
  DiagnosticCode.unknownPicture: 'The project has no picture "{0}". Add it '
      'to the project\'s pictures, or choose another.',
  DiagnosticCode.noSubMain: 'The project starts with Sub Main, but no '
      'module has a Sub Main(). Add one to a module, or start with a form.',
  DiagnosticCode.badProjectId: '"{0}" is not an app ID, so it is ignored '
      'and the next export of the app makes a new one. An app ID is 8 to 32 '
      'lowercase letters and digits.',
  DiagnosticCode.badAnchor: '"{0}" is not an Anchor. Name edges of the form '
      'with Left, Top, Right and Bottom, as in "Right Bottom", or "" for '
      'none.',
  DiagnosticCode.notDesignProperty: '{0} cannot be set in the form file: it '
      'is set or worked out while the program runs. Remove this line, and '
      'set it in code if needed (for example in Form_Load).',

  // Run time
  DiagnosticCode.integerOverflow: 'The result is too large for an Integer '
      '(from -9223372036854775808 to 9223372036854775807). If an '
      'approximate value is enough, calculate with Double instead.',
  DiagnosticCode.divisionByZero: 'Division by zero. Check the divisor '
      'first, for example If d <> 0 Then.',
  DiagnosticCode.indexOutOfRange: 'There is no item number {0}: there are {1} '
      'items, numbered from 0. Check the number.',
  DiagnosticCode.nothingReference: 'This object is Nothing, so it has no '
      'members or items. Create it first, for example with New.',
  DiagnosticCode.conversionFailed: '"{0}" cannot be turned into {1}. Check '
      'the value before converting it.',
  DiagnosticCode.memberNotFound: 'A value of type {1} has no member "{0}". '
      'Check what the Object variable holds.',
  DiagnosticCode.invalidArgument: 'The value given to {0} is outside what it '
      'accepts. Check the arguments.',
  DiagnosticCode.settingsTooLarge: 'The settings of this program would be '
      'longer than 65536 characters. Save fewer or shorter values.',
  DiagnosticCode.pictureNotFound: 'This project has no picture "{0}". Add it '
      'to the project, or check the name.',
  DiagnosticCode.badAnchorValue: '"{0}" is not an Anchor. Name the edges '
      'with Left, Top, Right and Bottom, as in "Right Bottom", or "" for '
      'none.',
  DiagnosticCode.dialogAlreadyShown: '{0} is already shown, so it cannot '
      'be shown as a dialog. Hide or close it first, or use {0}.Show.',
  DiagnosticCode.controlNameTaken: '{1} already has a control named {0}. '
      'Give the new control another Name before adding it.',
  DiagnosticCode.controlAlreadyOnForm: '{0} is already on {1}. A control '
      'is on one form at a time: remove it from there first.',
  DiagnosticCode.controlNotOnForm: '{0} is not on {1}, so it cannot be '
      'removed from it. Check which form it was added to.',
  DiagnosticCode.nameOfControlOnForm: '{0} is on a form, so its Name '
      'cannot change any more. Set Name before Controls.Add.',
  DiagnosticCode.badControlName: '"{0}" is not a name: a control\'s Name '
      'starts with an English letter, then letters, digits or "_".',
  DiagnosticCode.eventAlreadyHandled: '{0} already has a handler, {1}, and '
      'an event has one handler. Use that procedure, or another control.',
  DiagnosticCode.castFailed: 'This value is a {0}, not a {1}, so CType '
      'cannot turn it into one. Check it first with TypeOf value Is {1}.',
  DiagnosticCode.settingsNotSaved: 'The setting could not be saved ({0}). '
      'There may be no room left where settings are kept.',
  DiagnosticCode.unhandledException: 'An error was thrown and not caught: '
      '{0}. Use Try ... Catch to handle it.',
  DiagnosticCode.callsTooDeep: 'Procedures called each other too deeply '
      '(more than {0} calls in a row). Check that the recursion stops.',
  DiagnosticCode.propertyValueOutOfRange: 'The value of {0} must be from {1} '
      'to {2}. Check the value before setting it.',

  DiagnosticCode.localHidesField: 'This local "{0}" hides the form-level '
      'variable of the same name declared on line {1}, which cannot be '
      'reached here. Rename one of them, or use Static if the value should '
      'be kept between calls.',
};
