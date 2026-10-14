import 'diagnostic.dart';

/// Korean diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
///
/// Written in the same "~합니다" style as the Korean documents: what is
/// wrong and how to fix it, in one or two sentences. A suggested fix never
/// silently changes what the program means; if it has a trade-off, the
/// message says so.
///
/// Particles:
/// - Never directly after a placeholder (it would depend on the inserted
///   word); attach it to a fixed word instead: "{0} 키워드가", not "{0}가".
/// - After a fixed English word, choose by how it is read: Sub [섭] takes
///   이나/과/을. If that looks odd, join with "또는" or add a Korean word
///   ("Sub 프로시저를").
const Map<DiagnosticCode, String> koreanMessages = {
  // Lexer
  DiagnosticCode.unterminatedString: '문자열이 닫히지 않았습니다. 같은 줄 안에서 따옴표(")로 닫아 주세요.',
  DiagnosticCode.nonAsciiIdentifier:
      '이름에는 영문자, 숫자, _만 쓸 수 있습니다(문제가 된 이름: {0}). '
          '한글은 문자열("...")이나 주석(\')에 써 주세요.',
  DiagnosticCode.statementSeparator:
      'GuBASIC은 한 줄에 한 문장만 씁니다. ":" 대신 줄을 바꿔 다음 문장을 써 주세요.',
  DiagnosticCode.unexpectedCharacter: '"{0}" 문자는 GuBASIC에서 쓰지 않습니다. '
      '지우거나, 글자 그대로 쓰려면 문자열("...") 안에 넣어 주세요.',
  DiagnosticCode.misplacedLineContinuation:
      '"_" 기호는 줄의 맨 끝에 있을 때만 다음 줄로 이어 씁니다. '
          '줄 끝으로 옮기거나 지워 주세요. 이름은 영문자로 시작해야 합니다.',
  DiagnosticCode.integerTooLarge: 'Integer에 담기에는 너무 큰 수입니다(입력한 수: {0}). '
      'Integer는 9223372036854775807까지 담을 수 있습니다. '
      '대략적인 값이면 충분할 때는 소수점을 붙여 Double로 쓸 수 있지만({0}.0), '
      '이때는 끝자리가 달라질 수 있습니다.',
  DiagnosticCode.integerInexactOnWeb:
      '웹 브라우저가 정확히 담을 수 있는 가장 큰 정수(9007199254740991)보다 큰 수입니다(입력한 수: {0}). '
          'macOS·Windows·iOS·Android 앱에서는 그대로 쓸 수 있지만, 웹에서는 끝자리가 달라질 수 있습니다. '
          '계산에 쓰지 않는 번호(주문 번호, 회원 ID 등)라면 문자열("...")로 담아 주세요. 앞자리 0도 그대로 남습니다.',

  // Parser: structure
  DiagnosticCode.expectedExpression:
      '여기에는 값이나 식이 필요합니다. 값을 쓰거나, 앞의 연산자나 쉼표를 지워 주세요.',
  DiagnosticCode.expectedKeyword: '여기에는 {0} 키워드가 필요합니다. 문장을 마저 써 주세요.',
  DiagnosticCode.expectedSymbol: '여기에는 {0} 기호가 필요합니다. 문장을 마저 써 주세요.',
  DiagnosticCode.expectedName: '여기에는 이름이 필요합니다. 영문자로 시작하는 이름을 써 주세요.',
  DiagnosticCode.unexpectedToken:
      '이 자리에 올 수 없는 내용이 있습니다: {0}. 오타가 있거나 줄바꿈이 빠지지 않았는지 확인해 주세요.',
  DiagnosticCode.unclosedBlock:
      '{1}번 줄에서 시작한 {0} 블록이 닫히지 않았습니다. {2} 문장을 넣어 주세요.',
  DiagnosticCode.unmatchedCloser:
      '{0} 문장과 짝이 되는 {1} 문장이 없습니다. 지우거나, 앞에 {1} 문장을 써 주세요.',
  DiagnosticCode.statementOutsideProcedure: '문장은 Sub 또는 Function 안에 써야 합니다. '
      '그 밖에는 선언(Dim, Private, Public, Const)과 Sub, Function만 쓸 수 있습니다.',
  DiagnosticCode.declarationNotAllowedHere: '이 자리에는 {0} 선언을 쓸 수 없습니다. '
      '프로시저 안에서는 Dim, Static, Const를, 밖에서는 Dim, Private, Public, Const를 씁니다.',
  DiagnosticCode.nextVariableMismatch:
      'Next 뒤의 이름이 For 문의 변수와 다릅니다(Next {0}, For {1}). '
          '같은 이름을 쓰거나 Next만 써 주세요.',
  DiagnosticCode.callWithoutParentheses:
      'GuBASIC에서는 인수를 괄호 안에 씁니다. MsgBox("안녕")처럼 이름(인수) 형태로 써 주세요.',
  DiagnosticCode.oneVariablePerDeclaration:
      '한 줄에는 변수 하나만 선언합니다. 다음 변수는 Dim 문을 따로 써서 선언해 주세요.',

  // Parser: Visual Basic features GuBASIC does not support
  DiagnosticCode.unsupportedOnError:
      'GuBASIC은 On Error를 지원하지 않습니다. 오류가 날 수 있는 코드를 Try ... Catch ... End Try로 감싸 주세요.',
  DiagnosticCode.unsupportedGoTo:
      'GuBASIC은 {0} 문을 지원하지 않습니다. 반복문이나 Exit, 또는 별도의 Sub 또는 Function을 써 주세요.',
  DiagnosticCode.unsupportedVariant:
      'GuBASIC에는 Variant 타입이 없습니다. 아무 값이나 담아야 하면 Object를 써 주세요.',
  DiagnosticCode.unsupportedClass:
      '사용자 정의 클래스는 GuBASIC 1.0에서 쓸 수 없습니다. 모듈에 Sub 또는 Function을 만들어 써 주세요.',
  DiagnosticCode.unsupportedShortCircuit:
      'GuBASIC에는 {0} 연산자가 없습니다. 대신 {1} 연산자를 써 주세요. '
          'And와 Or도 왼쪽만으로 결과가 정해지면 오른쪽을 계산하지 않습니다.',
  DiagnosticCode.unsupportedWhile:
      'GuBASIC에는 While ... Wend 문이 없습니다. Do While ... Loop를 써 주세요.',
  DiagnosticCode.unsupportedCall:
      'GuBASIC에서는 Call을 쓰지 않습니다. Call을 지우고 ShowScore("Kim", 90)처럼 바로 호출해 주세요.',
  DiagnosticCode.unsupportedSetLet:
      'GuBASIC에서는 {0} 키워드를 쓰지 않습니다. 지우고 x = 값처럼 바로 대입해 주세요.',
  DiagnosticCode.byRefNotAvailable: 'ByRef는 아직 준비 중입니다. '
      '바뀐 값을 돌려받으려면 Function을 만들어 Return으로 돌려주세요.',
  DiagnosticCode.handlesNotAvailable: 'Handles는 아직 준비 중입니다. '
      "지금은 btnSave_Click처럼 '컨트롤이름_이벤트이름'으로 Sub 프로시저를 만들어 주세요.",

  // Analyzer: names
  DiagnosticCode.unknownName: '{0} 이름이 선언되지 않았습니다. 먼저 Dim으로 선언하거나 철자를 확인해 주세요.',
  DiagnosticCode.unknownNameDidYouMean:
      '{0} 이름이 선언되지 않았습니다. 비슷한 이름으로 {1} 이름이 있으니 철자를 확인해 주세요.',
  DiagnosticCode.unknownNameMaybeControl: '{0} 이름이 선언되지 않았습니다. '
      '컨트롤이나 폼이라면 폼 디자이너가 생기면 쓸 수 있습니다. 지금은 Dim으로 선언한 변수를 써 주세요.',
  DiagnosticCode.unknownType: '{0} 타입이 없습니다. 철자를 확인해 주세요. '
      'Button 같은 컨트롤 타입은 폼 디자이너가 생기면 쓸 수 있습니다.',
  DiagnosticCode.duplicateDeclaration:
      '{0} 이름은 {1}번 줄에서 이미 선언했습니다. 다른 이름을 써 주세요.',
  DiagnosticCode.usedBeforeDeclaration:
      '{0} 이름을 선언하기 전에 썼습니다(선언: {1}번 줄). 선언을 이 줄보다 위로 옮겨 주세요.',
  DiagnosticCode.missingTypeAndValue: '{0} 변수에는 타입이나 초깃값이 필요합니다. '
      'Dim {0} As Integer처럼 타입을 쓰거나, Dim {0} = 값처럼 초깃값을 주세요.',

  // Analyzer: types
  DiagnosticCode.typeMismatch: '{1} 타입이 필요한 자리에 {0} 타입 값을 넣을 수 없습니다. '
      '의도한 것이라면 CInt, CDbl, CStr, CBool 같은 변환 함수로 바꿔 주세요.',
  DiagnosticCode.stringToNumber:
      '문자열은 숫자로 자동으로 바뀌지 않습니다. CInt(정수), CDbl, Val 중 하나로 바꿔 주세요.',
  DiagnosticCode.doubleToInteger:
      'Double 값은 소수 부분이 사라지므로 Integer로 자동으로 바뀌지 않습니다. '
          '반올림하려면 CInt를(2.5는 3, -2.5는 -3), 더 작은 쪽 정수로 내리려면 Int를 써 주세요. '
          '예를 들어 Int(-2.5)는 -3입니다.',
  DiagnosticCode.stringPlusNumber: '문자열과 숫자는 +로 이을 수 없습니다. '
      '글자로 이으려면 &를 쓰고, 숫자로 더하려면 CInt나 CDbl로 문자열을 바꿔 주세요.',
  DiagnosticCode.conditionNotBoolean:
      '조건에는 True 또는 False 값이 와야 하는데, 이 식은 {0} 타입입니다. x <> 0처럼 비교식으로 써 주세요.',
  DiagnosticCode.binaryOperatorNotApplicable:
      '{0} 연산자는 {1} 타입과 {2} 타입에 쓸 수 없습니다. 양쪽 값을 확인해 주세요. '
          'And, Or, Xor에는 True/False 값이 필요하고, Is 연산자는 객체를 비교합니다(값은 =로 비교).',
  DiagnosticCode.unaryOperatorNotApplicable:
      '{0} 연산자는 {1} 타입에 쓸 수 없습니다. - 기호와 + 기호에는 숫자가, Not에는 True 또는 False 값이 필요합니다.',

  // Analyzer: calls, members, assignment
  DiagnosticCode.wrongArgumentCount:
      '{0} 호출의 인수 개수가 맞지 않습니다(필요한 개수: {1}, 넘긴 개수: {2}). 호출을 확인해 주세요.',
  DiagnosticCode.notCallable:
      '{0} 이름은 Sub 또는 Function이 아니라서 호출할 수 없습니다. 이름을 확인해 주세요.',
  DiagnosticCode.subHasNoValue: '{0} 프로시저는 값을 돌려주지 않는 Sub 프로시저입니다. '
      '따로 한 줄에 호출하거나, Return을 쓰는 Function으로 바꿔 주세요.',
  DiagnosticCode.notIndexable: '{0} 타입 값에는 번호로 꺼낼 항목이 없습니다. '
      '(번호)는 배열과 List에만 쓸 수 있고, 문자열에는 Mid 함수를 써 주세요.',
  DiagnosticCode.unknownMember: '{0} 타입에는 {1} 멤버가 없습니다. 철자를 확인해 주세요.',
  DiagnosticCode.notAssignable: '{0} 부분에는 값을 넣을 수 없습니다. '
      '= 왼쪽에는 변수, 배열이나 List의 항목, 속성만 올 수 있습니다(상수, 프로시저, 호출 결과는 바꿀 수 없음).',
  DiagnosticCode.assignToFunctionName: 'GuBASIC의 Function은 Return으로 값을 돌려줍니다. '
      '{0} = 값 대신 Return 값으로 써 주세요.',
  DiagnosticCode.returnValueInSub: 'Sub 프로시저는 값을 돌려주지 않으므로 여기서는 Return만 씁니다. '
      '값을 지우거나, 이 프로시저를 Function으로 바꿔 주세요.',
  DiagnosticCode.returnWithoutValue:
      'Function은 값을 돌려줘야 합니다. Return 뒤에 돌려줄 값을 써 주세요.',
  DiagnosticCode.exitOutsideBlock:
      '{0} 문은 짝이 맞는 반복문이나 프로시저 안에서만 쓸 수 있습니다. 지우거나 안쪽으로 옮겨 주세요.',
  DiagnosticCode.cannotLoopOver:
      'For Each 문은 {0} 타입 값을 차례로 돌 수 없습니다. List나 배열을 써 주세요.',

  // Analyzer: warnings
  DiagnosticCode.unusedLocal: '{0} 변수를 선언했지만 쓰지 않았습니다. 필요 없으면 지워 주세요.',
  DiagnosticCode.functionWithoutReturn:
      '{0} 함수에 Return 문이 없어서 항상 기본값을 돌려줍니다. 돌려줄 값과 함께 Return을 써 주세요.',
  DiagnosticCode.localHidesField:
      '이 지역 변수 {0} 이름이 {1}번 줄에서 선언한 같은 이름의 폼 변수를 가립니다. '
          '여기서는 폼 변수를 쓸 수 없습니다. 둘 중 하나의 이름을 바꾸거나, 호출 사이에 값을 남기려면 Static을 써 주세요.',
};
