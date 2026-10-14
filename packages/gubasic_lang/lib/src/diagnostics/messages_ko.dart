import 'diagnostic.dart';

/// Korean diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
///
/// Written in the same "~합니다" style as the Korean documents: what is
/// wrong and how to fix it, in one or two sentences. A particle never
/// follows a placeholder directly (it would depend on the inserted word);
/// it attaches to a fixed word instead: "{0} 키워드가", not "{0}가".
const Map<DiagnosticCode, String> koreanMessages = {
  // Lexer
  DiagnosticCode.unterminatedString: '문자열이 닫히지 않았습니다. 같은 줄 안에서 따옴표(")로 닫아 주세요.',
  DiagnosticCode.nonAsciiIdentifier:
      '변수 이름에는 영문자, 숫자, _만 쓸 수 있습니다(문제가 된 이름: {0}). '
          '한글은 문자열("...")이나 주석(\')에 써 주세요.',
  DiagnosticCode.statementSeparator:
      'GuBASIC은 한 줄에 한 문장만 씁니다. ":" 대신 줄을 바꿔 다음 문장을 써 주세요.',
  DiagnosticCode.unexpectedCharacter: '"{0}" 문자는 GuBASIC에서 쓰지 않습니다. '
      '지우거나, 글자 그대로 쓰려면 문자열("...") 안에 넣어 주세요.',
  DiagnosticCode.misplacedLineContinuation:
      '"_" 기호는 줄의 맨 끝에 있을 때만 다음 줄로 이어 씁니다. '
          '줄 끝으로 옮기거나 지워 주세요. 이름은 영문자로 시작해야 합니다.',
  DiagnosticCode.integerTooLarge:
      'Integer에 담기에는 너무 큰 수입니다(입력한 수: {0}, 가장 큰 값: 9223372036854775807). '
          '더 큰 수가 필요하면 소수점을 붙여 Double로 써 주세요(예: {0}.0).',

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
  DiagnosticCode.statementOutsideProcedure: '문장은 Sub나 Function 안에 써야 합니다. '
      '이곳에는 선언(Dim, Const, Sub, Function)만 쓸 수 있습니다.',
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
      'GuBASIC은 {0} 문을 지원하지 않습니다. 반복문이나 Exit, 또는 별도의 Sub나 Function을 써 주세요.',
  DiagnosticCode.unsupportedVariant:
      'GuBASIC에는 Variant 타입이 없습니다. 아무 값이나 담아야 하면 Object를 써 주세요.',
  DiagnosticCode.unsupportedClass:
      '사용자 정의 클래스는 GuBASIC 1.0에서 쓸 수 없습니다. 모듈에 Sub와 Function을 만들어 써 주세요.',
  DiagnosticCode.unsupportedShortCircuit:
      'GuBASIC에는 {0} 연산자가 없습니다. {1} 연산자를 써 주세요. 결과가 정해지면 오른쪽은 이미 건너뜁니다.',
  DiagnosticCode.unsupportedWhile:
      'GuBASIC에는 While ... Wend 문이 없습니다. Do While ... Loop를 써 주세요.',
  DiagnosticCode.unsupportedCall:
      'GuBASIC에서는 Call을 쓰지 않습니다. Call을 지우고 ShowScore("Kim", 90)처럼 바로 호출해 주세요.',
  DiagnosticCode.unsupportedSetLet:
      'GuBASIC에서는 {0} 키워드를 쓰지 않습니다. 지우고 x = 값처럼 바로 대입해 주세요.',
  DiagnosticCode.plannedForStage2: '{0} 기능은 아직 쓸 수 없습니다(2단계 예정). 지금은 지워 주세요.',
};
