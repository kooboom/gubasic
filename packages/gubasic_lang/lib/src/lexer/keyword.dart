/// Whether GuBASIC accepts a keyword.
enum KeywordSupport {
  /// Part of the language.
  supported,

  /// Not yet supported, but planned for stage 2 (`ByRef`).
  plannedStage2,

  /// A Visual Basic keyword that GuBASIC deliberately does not support.
  ///
  /// The lexer still recognises it so that later stages can explain what
  /// to write instead.
  unsupported,
}

/// Every reserved word of GuBASIC, plus Visual Basic keywords the language
/// does not support.
///
/// Enum values carry a `kw` prefix because many spellings (`if`, `new`,
/// `in`, …) are reserved words in Dart. Each keyword is its own value, so
/// later stages can attach a different hint to each unsupported one.
enum Keyword {
  // Declarations
  kwDim('Dim'),
  kwAs('As'),
  kwConst('Const'),
  kwStatic('Static'),
  kwPublic('Public'),
  kwPrivate('Private'),
  kwSub('Sub'),
  kwFunction('Function'),
  kwEnd('End'),
  kwExit('Exit'),
  kwReturn('Return'),
  kwOptional('Optional'),
  kwByVal('ByVal'),
  kwHandles('Handles'),
  kwReDim('ReDim'),
  kwPreserve('Preserve'),
  kwOf('Of'),

  // Control flow
  kwIf('If'),
  kwThen('Then'),
  kwElseIf('ElseIf'),
  kwElse('Else'),
  kwSelect('Select'),
  kwCase('Case'),
  kwFor('For'),
  kwTo('To'),
  kwStep('Step'),
  kwEach('Each'),
  kwIn('In'),
  kwNext('Next'),
  kwDo('Do'),
  kwLoop('Loop'),
  kwWhile('While'),
  kwUntil('Until'),

  // Errors
  kwTry('Try'),
  kwCatch('Catch'),
  kwFinally('Finally'),
  kwThrow('Throw'),

  // Values and objects
  kwNew('New'),
  kwNothing('Nothing'),
  kwTrue('True'),
  kwFalse('False'),
  kwMe('Me'),

  // Controls as objects (docs/DESIGN.md D98)
  kwTypeOf('TypeOf'),
  kwCType('CType'),
  kwAddHandler('AddHandler'),
  kwAddressOf('AddressOf'),

  // Operators
  kwNot('Not'),
  kwAnd('And'),
  kwOr('Or'),
  kwXor('Xor'),
  kwMod('Mod'),
  kwIs('Is'),

  // Planned for stage 2
  kwByRef('ByRef', KeywordSupport.plannedStage2),

  // Visual Basic keywords GuBASIC does not support
  kwOn('On', KeywordSupport.unsupported),
  kwGoTo('GoTo', KeywordSupport.unsupported),
  kwGoSub('GoSub', KeywordSupport.unsupported),
  kwVariant('Variant', KeywordSupport.unsupported),
  kwClass('Class', KeywordSupport.unsupported),
  kwAndAlso('AndAlso', KeywordSupport.unsupported),
  kwOrElse('OrElse', KeywordSupport.unsupported),
  kwWend('Wend', KeywordSupport.unsupported),
  kwCall('Call', KeywordSupport.unsupported),
  kwSet('Set', KeywordSupport.unsupported),
  kwLet('Let', KeywordSupport.unsupported);

  const Keyword(this.spelling, [this.support = KeywordSupport.supported]);

  /// The canonical spelling, e.g. `ElseIf`.
  final String spelling;

  final KeywordSupport support;

  bool get isSupported => support == KeywordSupport.supported;

  static final Map<String, Keyword> _byLowerCase = {
    for (final k in values) k.spelling.toLowerCase(): k,
  };

  /// Looks up [word] ignoring case. Returns null if it is not a keyword.
  static Keyword? lookup(String word) => _byLowerCase[word.toLowerCase()];
}
