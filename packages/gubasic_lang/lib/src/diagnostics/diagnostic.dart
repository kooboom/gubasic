import 'messages_en.dart';

/// How serious a diagnostic is. Errors must be fixed; warnings point out
/// something that works but may surprise, and never stop a program from
/// running or being built.
enum DiagnosticSeverity { error, warning }

/// Every diagnostic GuBASIC can report. Codes are stable: never reuse or
/// renumber one. The prefix says who reports it (L lexer, P parser,
/// A analyzer, F form and project files, R run time); the severity is
/// separate. The full list is documented in docs/LANGUAGE.md.
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

  /// L006 for exactly 9223372036854775808 (one more than the largest
  /// Integer): the message adds a pointer to Integer.MinValue. Same code,
  /// a second message.
  integerTooLargeMinValue('L006'),

  /// A Double literal beyond the Double range (`1E400`).
  doubleTooLarge('L008'),

  /// A non-zero Double literal so small that it becomes 0 (`1E-400`).
  doubleBecomesZero('L009', DiagnosticSeverity.warning),

  // L007 (an integer the web could not store exactly) is retired: Integer
  // is exact 64-bit on every platform (D26). The code is not reused.

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

  // P022 (Handles not available yet) is retired: Handles works since D98.
  // The code is not reused.

  /// A line that ends inside an open parenthesis, with a value missing:
  /// `(1 +`, `f(1,`. Says both what and `)` are missing.
  expectedValueAndParen('P023'),

  /// `Unload Form2` (Visual Basic 6): GuBASIC closes a form with
  /// `Form2.Close` (docs/DESIGN.md D88). Args: the form as written.
  unloadStatement('P024'),

  /// `Load Form2` (Visual Basic 6): GuBASIC shows a form with
  /// `Form2.Show`. Args: the form as written.
  loadStatement('P025'),

  /// `DirectCast` or `TryCast` (Visual Basic .NET): read as `CType`, which
  /// is GuBASIC's (D98). Args: the word as written.
  otherCast('P026'),

  /// `Load Command1(1)` (Visual Basic 6): a control array's new element.
  /// GuBASIC makes a control with New and Controls.Add (D99).
  loadControl('P027'),

  /// `Unload Command1(1)` (Visual Basic 6): GuBASIC takes a control off
  /// its form with Controls.Remove (D99).
  unloadControl('P028'),

  // Analyzer: names

  /// A name that is not declared. Args: the name.
  unknownName('A001'),

  /// A name that is not declared, with a similar visible name. Args: the
  /// name, the suggestion.
  unknownNameDidYouMean('A002'),

  /// An undeclared name used with `.` (likely a control), or `Me`.
  /// Args: the name.
  unknownNameMaybeControl('A003'),

  /// A type name that does not exist. Args: the name.
  unknownType('A004'),

  /// A name declared twice in the same scope. Args: name, first line.
  duplicateDeclaration('A005'),

  /// A local used above its declaration. Args: name, declaration line.
  usedBeforeDeclaration('A006'),

  /// `Dim x` with neither a type nor an initial value, or a parameter or
  /// Function without `As`. Args: the name.
  missingTypeAndValue('A007'),

  // Analyzer: types

  /// A value that cannot be stored where another type is expected.
  /// Args: the value's type, the expected type.
  typeMismatch('A008'),

  /// Text where a number is expected.
  stringToNumber('A009'),

  /// A Double where an Integer is expected.
  doubleToInteger('A010'),

  /// Text and a number joined with `+`.
  stringPlusNumber('A011'),

  /// A condition that is not Boolean. Args: its type.
  conditionNotBoolean('A012'),

  /// A binary operator used with types it does not support.
  /// Args: operator, left type, right type.
  binaryOperatorNotApplicable('A013'),

  /// A unary operator used with a type it does not support.
  /// Args: operator, type.
  unaryOperatorNotApplicable('A014'),

  // Analyzer: calls, members, assignment

  /// Wrong number of arguments. Args: callee, expected, given.
  wrongArgumentCount('A015'),

  /// Something that is not a Sub or Function, called. Args: its name.
  notCallable('A016'),

  /// A Sub used where a value is needed. Args: its name.
  subHasNoValue('A017'),

  /// `(index)` on something without numbered items. Args: its type.
  notIndexable('A018'),

  /// A member a known type does not have. Args: type, member.
  unknownMember('A019'),

  /// Something that cannot be on the left of `=`. Args: its source text.
  notAssignable('A020'),

  /// VB6 style `FunctionName = value`. Args: the function name.
  assignToFunctionName('A021'),

  /// `Return value` in a Sub.
  returnValueInSub('A022'),

  /// `Return` without a value in a Function.
  returnWithoutValue('A023'),

  /// `Exit For/Do/Sub/Function` outside a matching block. Args: the
  /// statement (`Exit For`).
  exitOutsideBlock('A024'),

  /// `For Each` over something that is not a List or an array.
  /// Args: its type.
  cannotLoopOver('A025'),

  // Analyzer: warnings

  /// A local variable that is never used. Args: its name.
  unusedLocal('A026', DiagnosticSeverity.warning),

  /// A Function with no Return statement. Args: its name.
  functionWithoutReturn('A027', DiagnosticSeverity.warning),

  /// A local that hides a form-level variable. Args: name, line of the
  /// form-level declaration.
  localHidesField('A028', DiagnosticSeverity.warning),

  // A029 (SaveSetting / GetSetting not available yet) is retired: they
  // work since D48. The code is not reused.

  // Analyzer: forms and controls

  /// A form-level variable or procedure with the name of a control.
  /// Args: the name.
  nameIsControl('A030'),

  /// A local with the name of a control, which it hides. Args: the name.
  localHidesControl('A031', DiagnosticSeverity.warning),

  /// An event handler written differently from its event. Args: the
  /// handler's name, the event (`btnSave.Click`), the expected first line
  /// (`Sub btnSave_Click()`).
  handlerSignature('A032'),

  // A033 (controls cannot be created by code yet) is retired: they can
  // since D98. The code is not reused; a form with New is A047.

  /// A value given to a property the program can only read
  /// (`lstNames.ListCount = 3`, `names.Count = 0`). Args: the property as
  /// written.
  readOnlyProperty('A034'),

  /// A member the type does not have, with a similar one it has
  /// (`lstCity.ListIndx`). Args: the type, the member as written, the
  /// similar member.
  unknownMemberDidYouMean('A035'),

  /// A member the type does not have, under a name other versions of
  /// BASIC use for one GuBASIC calls differently (`btnOK.Text` for
  /// `Caption`), listed as `otherNames` in the component.yaml. Args: the
  /// type, the member as written, GuBASIC's member(s).
  memberHasOtherName('A036'),

  /// Text given to a picture property (`imgShape.Picture = "tri.png"`)
  /// that is not a picture of the project: the program would stop there
  /// (R013). Args: the text.
  unknownPictureInCode('A037', DiagnosticSeverity.warning),

  /// Text given to `Anchor` (`btnOk.Anchor = "Rihgt"`) with a word that is
  /// not an edge: the program would stop there (R014). Args: the text.
  badAnchorInCode('A038', DiagnosticSeverity.warning),

  /// Text that is not a shortcut given to a Shortcut (D106): R024 when
  /// it runs. Args: the text.
  badShortcutInCode('A057', DiagnosticSeverity.warning),

  /// `Form2.Show vbModal` (Visual Basic 6): Show takes no argument; a form
  /// that the code waits for is shown with ShowDialog (D88). Args: the
  /// form as written.
  showWithArgument('A039'),

  // Analyzer: events and controls as objects (D98)

  /// An event the control does not have, in `Handles` or `AddHandler`.
  /// Args: the control as written, its type, the event as written.
  unknownEvent('A040'),

  /// Two procedures handle the same event: one event has one handler.
  /// Args: the event (`btnA.Click`), the procedure that handles it first.
  eventHandledTwice('A041'),

  /// A procedure named as the handler of one event whose `Handles` does
  /// not list that event: it handles only what `Handles` lists. Args: the
  /// procedure, the event its name suggests (`btnA.Click`).
  handlerNameMismatch('A042', DiagnosticSeverity.warning),

  /// A handler's `sender` cannot hold one of the controls it handles.
  /// Args: the procedure, the event (`lblA.Click`), the control's type,
  /// the parameter's type.
  senderTypeMismatch('A043'),

  /// A handler written as in Visual Basic .NET, `(sender As Object, e As
  /// EventArgs)`. Args: the procedure, the parameter to write
  /// (`sender As Button`).
  netHandlerSignature('A044'),

  /// `CType` or `TypeOf … Is` with a type that is not a control's. Args:
  /// the type.
  castNeedsControlType('A045'),

  /// A Control where a particular control type is expected. Args: the
  /// value's type (`Control`), the expected type (`TextBox`).
  controlNarrowing('A046'),

  /// `New Form2` or `New Form`: a project's forms are used by their names
  /// (D88). Args: the type as written.
  newForm('A047'),

  /// `AddressOf` names something that is not a procedure of this code.
  /// Args: the name.
  notAProcedure('A048'),

  /// `Sub Command1_Click(Index As Integer)` (Visual Basic 6): a control
  /// array's handler. Args: the procedure, the event (`Command1.Click`),
  /// the control's type (D99).
  controlArrayHandler('A049'),

  /// `Command1(0)`: a control used as a control array. Args: the control
  /// as written (D99).
  controlArrayItem('A050'),

  /// An event under a name other versions of BASIC use, listed as
  /// `otherEvents` in the component.yaml (`Timer1_Timer` for Tick). Args:
  /// the event as written (`Timer1.Timer`), GuBASIC's event (`Tick`), how
  /// to write it (`Timer1_Tick`) (D100).
  eventHasOtherName('A051'),

  /// `New Timer`: a control not seen on the form is put on it in the
  /// designer. Args: the type (D100).
  placedInDesigner('A052'),

  /// `Sub Form_KeyDown(KeyCode As Integer, Shift As Integer)` (Visual
  /// Basic 6): GuBASIC's key events take a KeyEventArgs. Args: the
  /// procedure, the line to write (D101).
  vb6KeyHandler('A053'),

  /// A name two modules make Public, written without its module's name.
  /// Args: the name, the modules, the name with the first module's
  /// (D102).
  ambiguousName('A054'),

  /// `Sub Main` in two modules. Args: the other module (D102).
  mainTwice('A055'),

  /// A type under the name another version of BASIC gives it
  /// (`RadioButton` for OptionButton). Args: the type as written,
  /// GuBASIC's (D104).
  typeHasOtherName('A056'),

  // Form and project files (.form.yaml, .gbproj)

  /// The file is not in the expected layout (YAML syntax).
  fileSyntax('F001'),

  /// `formatVersion` is missing or not a whole number.
  formatVersionMissing('F002'),

  /// The file was written by a newer GuBASIC. Args: its version, the
  /// newest this GuBASIC reads.
  formatVersionTooNew('F003'),

  /// A key GuBASIC does not know; it is ignored. Args: the key.
  unknownKey('F004', DiagnosticSeverity.warning),

  /// A value written in the wrong form. Args: the key, an example of the
  /// right form.
  wrongValueForm('F005'),

  /// A missing or unusable control or form name. Args: the name.
  invalidControlName('F006'),

  /// Two controls (or two forms of a project) with the same name. Args:
  /// the name, the first one's line.
  duplicateControlName('F007'),

  /// A control type that does not exist. Args: the type, the known types.
  unknownControlType('F008'),

  /// A property the control type does not have. Args: property, type,
  /// the type's properties.
  unknownProperty('F009'),

  /// A property value of the wrong type. Args: property, expected type.
  wrongPropertyType('F010'),

  /// `startup` names a form the project does not list. Args: the name.
  unknownStartupForm('F011'),

  /// An Integer property value outside its range. Args: property, the
  /// smallest and the largest value allowed.
  propertyOutOfRange('F012'),

  /// A property the form file cannot set: the program sets it while it
  /// runs (ListBox's ListIndex) or only reads it. Args: the property.
  notDesignProperty('F013'),

  /// A project's picture with a name a picture cannot have. Args: the
  /// name.
  invalidPictureName('F014'),

  /// Two pictures whose names differ only in the case of English letters
  /// (or in how Hangul is encoded). Args: the second, the first, its line.
  duplicatePicture('F015'),

  /// A picture property naming a picture the project does not have.
  /// Args: the name.
  unknownPicture('F016'),

  /// `Anchor` in a form file with a word that is not an edge. Args: the
  /// value.
  badAnchor('F017'),

  /// A project file's `id` that is not an app ID (lowercase letters and
  /// digits, 8 to 32): it is ignored, and the next export makes a new one.
  /// Args: the value.
  badProjectId('F018', DiagnosticSeverity.warning),

  /// `startup: Sub Main`, but no module has a `Sub Main()` (D102).
  noSubMain('F019'),

  /// A control type in a form file under the name another version of BASIC
  /// gives it. Args: the type as written, GuBASIC's (D104).
  controlTypeHasOtherName('F020'),
  notContainer('F021'),

  /// A Shortcut that is not one (D106). Args: the text.
  badShortcut('F022'),

  // Run time (the interpreter)

  /// An Integer result outside the 64-bit range.
  integerOverflow('R001'),

  /// Division by zero with /, \ or Mod.
  divisionByZero('R002'),

  /// An item number outside an array, list or text. Args: the number, the
  /// item count.
  indexOutOfRange('R003'),

  /// A member or item of an object that is Nothing.
  nothingReference('R004'),

  /// Text that cannot be converted. Args: the text, the target type.
  conversionFailed('R005'),

  /// A member a value does not have (found at run time, through Object).
  /// Args: member, the value's type.
  memberNotFound('R006'),

  /// An argument outside what a built-in function accepts. Args: the
  /// function.
  invalidArgument('R007'),

  /// An exception that was thrown and not caught. Args: its message.
  unhandledException('R008'),

  /// Procedures calling each other too deeply. Args: the limit.
  callsTooDeep('R009'),

  /// An Integer property set to a value outside its range. Args: the
  /// property, the smallest and the largest value allowed.
  propertyValueOutOfRange('R010'),

  /// SaveSetting would make the program's settings longer than
  /// [settingsLimit] characters.
  settingsTooLarge('R011'),

  /// SaveSetting could not keep the settings. Args: what went wrong.
  settingsNotSaved('R012'),

  /// A picture property set to a name the project has no picture of.
  /// Args: the name.
  pictureNotFound('R013'),

  /// `Anchor` set to text with a word that is not an edge. Args: the text.
  badAnchorValue('R014'),

  /// ShowDialog of a form that is already shown (D88). Args: the form.
  dialogAlreadyShown('R015'),

  /// `Controls.Add` of a control whose name the form already has. Args:
  /// the name, the form.
  controlNameTaken('R016'),

  /// `Controls.Add` of a control that is on a form already. Args: the
  /// control, the form it is on.
  controlAlreadyOnForm('R017'),

  /// `Controls.Remove` of a control that is not on that form. Args: the
  /// control, the form.
  controlNotOnForm('R018'),

  /// `Name` set on a control that is on a form. Args: the control.
  nameOfControlOnForm('R019'),

  /// `Name` set to text that is not a name. Args: the text.
  badControlName('R020'),

  /// `AddHandler` for an event that already has a handler. Args: the
  /// event (`btn5.Click`), its handler.
  eventAlreadyHandled('R021'),

  /// `CType` of a control of another type. Args: the value's type, the
  /// type asked for.
  castFailed('R022'),

  /// `Me.Controls.Remove` of a Frame that holds controls (D105). Args:
  /// the Frame's name.
  frameNotEmpty('R023'),

  /// A Shortcut set to text that is not one (D106). Args: the text.
  badShortcutValue('R024'),

  /// `PopupMenu` of a menu item that has no items (D106). Args: its name.
  popupWithoutItems('R025'),

  /// `PopupMenu` of another form's menu (D106). Args: the menu, its form,
  /// the form asked to show it.
  popupOfOtherForm('R026');

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
    this.replacements = const [],
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

  /// Names that could replace the text the diagnostic points at, for "did
  /// you mean" in the code editor: the similar name of A002 or A035, the
  /// GuBASIC member(s) of A036. Empty for most diagnostics.
  final List<String> replacements;

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

/// [diagnostics] in source order. Diagnostics at the same offset keep
/// their order in the list (callers list lexer before parser before
/// analyzer).
List<Diagnostic> sortDiagnostics(List<Diagnostic> diagnostics) {
  final indexed = [
    for (var i = 0; i < diagnostics.length; i++) (i, diagnostics[i]),
  ];
  indexed.sort((a, b) {
    final byOffset = a.$2.offset.compareTo(b.$2.offset);
    return byOffset != 0 ? byOffset : a.$1.compareTo(b.$1);
  });
  return [for (final (_, d) in indexed) d];
}
