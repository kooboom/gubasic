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
  DiagnosticCode.doubleTooLarge:
      'Double에 담기에는 너무 큰 수입니다(입력한 수: {0}, 가장 큰 값: 약 1.7976931348623157E+308). 더 작은 수를 써 주세요.',
  DiagnosticCode.doubleBecomesZero:
      '이 수는 너무 작아서 Double에 담으면 0이 됩니다(입력한 수: {0}). 0을 쓰려던 것이면 0을 써 주세요.',
  DiagnosticCode.integerTooLargeMinValue:
      'Integer에 담기에는 너무 큰 수입니다(입력한 수: {0}). '
          'Integer는 9223372036854775807까지 담을 수 있습니다. '
          '가장 작은 Integer(-9223372036854775808)가 필요하면 Integer.MinValue를 쓰세요.',

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
      'GuBASIC은 On Error를 지원하지 않습니다. 오류가 날 수 있는 코드는 Try와 Catch ex As Exception 사이에, 대신 할 일은 그 뒤 End Try 앞에 써 주세요(무엇이 잘못됐는지는 ex.Message에 있습니다).',
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
  DiagnosticCode.otherCast:
      'GuBASIC에서는 컨트롤을 다른 타입으로 바꿀 때 CType을 씁니다. {0}(값, 타입) 대신 CType(값, 타입)으로 써 주세요.',
  DiagnosticCode.loadControl:
      'GuBASIC에는 컨트롤 배열이 없어서 컨트롤에 쓰는 Load도 없습니다. Dim b As New Button으로 컨트롤을 만들고 Me.Controls.Add(b)로 폼에 넣어 주세요.',
  DiagnosticCode.unloadControl:
      'GuBASIC에는 컨트롤 배열이 없어서 컨트롤에 쓰는 Unload도 없습니다. Me.Controls.Remove(컨트롤)로 폼에서 빼 주세요.',
  DiagnosticCode.expectedValueAndParen:
      '여기에는 값과 ) 기호가 필요합니다. 값을 쓰고 괄호를 닫아 주세요.',
  DiagnosticCode.unloadStatement:
      'GuBASIC에서는 Unload 대신 메서드로 폼을 닫습니다. {0}.Close로 고쳐 주세요.',
  DiagnosticCode.loadStatement:
      'GuBASIC에는 Load 문이 없습니다. 폼을 보이려면 {0}.Show로 쓰고, 프로시저를 부르려면 인자를 괄호 안에 넣어 주세요.',

  // Analyzer: names
  DiagnosticCode.unknownName: '{0} 이름이 선언되지 않았습니다. 먼저 Dim으로 선언하거나 철자를 확인해 주세요.',
  DiagnosticCode.formMethodWithoutMe:
      '{0} 메서드는 폼의 메서드입니다. GuBASIC에서는 폼 메서드를 모두 Me.{0} 형태로 씁니다.',
  DiagnosticCode.popupMenuStatement:
      'GuBASIC에서 PopupMenu는 괄호를 쓰는 폼 메서드입니다. Me.PopupMenu({0}) 형태로 써 주세요.',
  DiagnosticCode.unknownNameDidYouMean:
      '{0} 이름이 선언되지 않았습니다. 비슷한 이름으로 {1} 이름이 있으니 철자를 확인해 주세요.',
  DiagnosticCode.unknownNameMaybeControl: '{0} 이름이 선언되지 않았습니다. '
      '이 코드에는 폼이 없어서 컨트롤과 Me를 쓸 수 없습니다(놀이터는 폼 없이 코드만 실행합니다). '
      'Dim으로 선언한 변수를 쓰거나, 폼이 있는 프로젝트로 열어 주세요.',
  DiagnosticCode.unknownType: '{0} 타입이 없습니다. 철자를 확인해 주세요.',
  DiagnosticCode.duplicateDeclaration:
      '{0} 이름은 {1}번 줄에서 이미 선언했습니다. 다른 이름을 써 주세요.',
  DiagnosticCode.usedBeforeDeclaration:
      '{0} 이름을 선언하기 전에 썼습니다(선언: {1}번 줄). 선언을 이 줄보다 위로 옮겨 주세요.',
  DiagnosticCode.missingTypeAndValue: '{0} 이름에는 타입이 필요합니다. '
      '{0} As Integer처럼 As와 타입을 써 주세요. Dim 문에서는 Dim {0} = 0처럼 초깃값을 주어도 됩니다.',

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
  DiagnosticCode.unknownMemberDidYouMean:
      '{0} 타입에는 {1} 멤버가 없습니다. 비슷한 멤버로 {2} 멤버가 있으니 철자를 확인해 주세요.',
  DiagnosticCode.unknownPictureInCode:
      '"{0}" 그림은 이 프로젝트에 없어서, 실행하면 여기서 프로그램이 멈춥니다. 그림을 프로젝트에 넣거나 이름을 확인해 주세요.',
  DiagnosticCode.showWithArgument:
      'Show에는 인자가 없습니다. 폼을 대화상자로 띄우고 닫힐 때까지 기다리려면 {0}.ShowDialog로 써 주세요.',
  DiagnosticCode.badShortcutInCode:
      '"{0}" 값은 단축키가 아니어서, 실행하면 여기서 프로그램이 멈춥니다. "Ctrl+O"나 "F5"처럼 Ctrl, Shift, Alt와 키 하나를 +로 이어 적거나, 없으면 ""로 적어 주세요. 글자나 숫자 키에는 Ctrl이나 Alt가 있어야 합니다.',
  DiagnosticCode.openStatement:
      'GuBASIC에서는 텍스트 파일을 File로 읽고 씁니다. text = File.ReadAllText(path), File.ReadAllLines(path), File.WriteAllText(path, text), File.AppendAllText(path, text) 형태로 써 주세요.',
  DiagnosticCode.fileNotFound:
      '{0} 파일이 없습니다. 이름을 확인하거나 OpenFileDialog로 사용자가 고르게 해 주세요. 있는지는 File.Exists로 알 수 있습니다.',
  DiagnosticCode.fileNotChosen:
      '웹에서는 사용자가 고른 파일만 쓸 수 있습니다. {0} 파일을 먼저 OpenFileDialog로 열거나 SaveFileDialog로 저장해 주세요.',
  DiagnosticCode.fileError:
      '{0} 파일을 읽거나 쓰지 못했습니다({1}). 다른 프로그램에서 열려 있지 않은지, 그곳에 쓸 수 있는지 확인해 주세요.',
  DiagnosticCode.badDateLiteral:
      '날짜는 #2026-10-29#처럼, 시각까지는 #2026-10-29 14:30#처럼 연, 월, 일 순서로 써 주세요.',
  DiagnosticCode.noPdfFont:
      'PDF 파일을 만들 글꼴이 이 앱에 없습니다. GuBASIC에서 프로젝트를 다시 내보내 주세요. PdfDocument를 쓰는 앱에는 글꼴이 함께 들어갑니다.',
  DiagnosticCode.pdfSize:
      'PDF의 글자 크기는 4포인트에서 72포인트까지입니다. 받은 값은 {0} 입니다. 처음 값은 TitleSize 18, TextSize 11, TableSize 10입니다.',
  DiagnosticCode.badInterval:
      '"{0}" 값은 구간이 아닙니다. "yyyy", "q", "m", "d", "ww", "h", "n", "s" 가운데 하나나 DateInterval.Day 같은 것을 써 주세요.',
  DiagnosticCode.tableIndex:
      '줄이나 열 번호 {0} 자리는 없습니다. 0부터 세며, 개수는 {1} 개입니다. 먼저 RowCount나 ColumnCount와 비교해 주세요.',
  DiagnosticCode.tableColumn:
      '그런 열이 없습니다: {0}. 열 이름은 Header로 확인하고, 있는지는 Column(name)이 -1이 아닌지로 알 수 있습니다(있는 열: {1}).',
  DiagnosticCode.noFiles: '여기서는 파일을 읽고 쓸 수 없습니다. IDE에서 실행하거나 앱으로 실행해 주세요.',
  DiagnosticCode.popupWithoutItems:
      '{0} 메뉴에는 항목이 없어서 PopupMenu로 보일 것이 없습니다. 메뉴 편집기에서 항목을 넣거나, 이 항목이 든 메뉴를 보여 주세요.',
  DiagnosticCode.popupOfOtherForm:
      '{0} 메뉴는 {1} 폼의 메뉴여서 {2} 폼이 보여 줄 수 없습니다. {1}.PopupMenu를 쓰거나 {2} 폼에 메뉴를 따로 만들어 주세요.',
  DiagnosticCode.badShortcut:
      '"{0}" 값은 단축키가 아닙니다. "Ctrl+O"나 "F5"처럼 Ctrl, Shift, Alt와 키 하나를 +로 이어 적거나, 없으면 ""로 적어 주세요. 글자나 숫자 키에는 Ctrl이나 Alt가 있어야 합니다.',
  DiagnosticCode.badShortcutValue:
      '"{0}" 값은 단축키가 아닙니다. "Ctrl+O"나 "F5"처럼 Ctrl, Shift, Alt와 키 하나를 +로 이어 적거나, 없으면 ""로 적어 주세요. 글자나 숫자 키에는 Ctrl이나 Alt가 있어야 합니다.',
  DiagnosticCode.badAnchorInCode:
      '"{0}" 값은 Anchor 값이 아니어서, 실행하면 여기서 프로그램이 멈춥니다. 컨트롤이 거리를 지킬 폼의 가장자리를 "Right Bottom"처럼 Left, Top, Right, Bottom으로 적거나, 없으면 ""로 적어 주세요.',
  DiagnosticCode.memberHasOtherName:
      '{0} 타입에는 {1} 멤버가 없습니다. GuBASIC에서는 이름이 달라서 {2} 멤버를 씁니다.',
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
  DiagnosticCode.nameIsControl:
      '{0} 이름은 이미 폼에 있는 컨트롤의 이름입니다. 여기서 다른 이름을 쓰거나 컨트롤의 이름을 바꿔 주세요.',
  DiagnosticCode.localHidesControl:
      '이 지역 변수 {0} 이름이 같은 이름의 컨트롤을 가려서, 여기서는 컨트롤을 쓸 수 없습니다. 지역 변수의 이름을 바꿔 주세요.',
  DiagnosticCode.handlerSignature:
      '{0} 프로시저는 {1} 이벤트 때 실행되므로 첫 줄이 {2} 형태여야 합니다. '
          '그렇게 고치거나, 이벤트를 처리할 프로시저가 아니라면 이름을 바꿔 주세요.',
  DiagnosticCode.unknownEvent:
      '{0} 컨트롤은 {1} 타입이고, "{2}" 이벤트가 없습니다. 철자나 컨트롤을 확인해 주세요.',
  DiagnosticCode.eventHandledTwice:
      '{0} 이벤트는 이미 {1} 프로시저가 처리하고, 이벤트 하나는 처리기 하나가 처리합니다. 둘 중 하나에서 빼 주세요.',
  DiagnosticCode.handlerNameMismatch:
      '{0} 프로시저는 이름이 {1} 이벤트의 처리기 같지만 Handles에 그 이벤트가 없어서, {1} 이벤트 때는 실행되지 않습니다. Handles에 {1} 이벤트를 넣거나 이름을 바꿔 주세요.',
  DiagnosticCode.senderTypeMismatch:
      '{0} 프로시저는 {2} 타입인 {1} 이벤트를 처리하는데, sender의 타입 {3} 타입으로는 그 컨트롤을 담을 수 없습니다. sender As {2} 형태로 쓰거나, 종류가 다른 컨트롤을 함께 처리하려면 sender As Control로 써 주세요.',
  DiagnosticCode.netHandlerSignature:
      'GuBASIC에서는 이벤트를 낸 컨트롤을 그 타입의 매개변수 하나로 알려 줍니다. ({1}) 형태로 쓰거나 괄호를 비워 주세요. {0} 프로시저는 Object와 EventArgs를 받을 수 없습니다.',
  DiagnosticCode.castNeedsControlType:
      '{0} 타입은 컨트롤 타입이 아닙니다. CType과 TypeOf는 컨트롤에 씁니다. 숫자와 글자에는 CInt, CDbl, CStr을 써 주세요.',
  DiagnosticCode.controlNarrowing:
      '{0} 타입에는 {1} 컨트롤만이 아니라 어떤 컨트롤이든 들어 있을 수 있습니다. CType(값, {1}) 형태로 쓰고, 다른 컨트롤일 수도 있으면 먼저 TypeOf 값 Is {1} 형태로 확인해 주세요.',
  DiagnosticCode.newForm:
      '{0} 타입은 New로 만들지 않습니다. 프로젝트의 폼은 Form2.Show처럼 이름으로 쓰고, Control은 어떤 컨트롤이든 담는 타입입니다. New Button처럼 특정한 컨트롤을 만들어 주세요.',
  DiagnosticCode.controlArrayHandler:
      'GuBASIC에는 컨트롤 배열이 없어서 처리기는 Index를 받지 않습니다. {0} 프로시저로 여러 컨트롤을 처리하려면 Handles 뒤에 컨트롤을 적고 누른 컨트롤을 sender로 받아 주세요: Sub Pressed(sender As {2}) Handles {1}, … 번호는 Tag에 담을 수 있습니다.',
  DiagnosticCode.controlArrayItem:
      '{0} 이름은 컨트롤 하나입니다. GuBASIC에는 컨트롤 배열이 없습니다. 컨트롤마다 이름을 따로 주거나, For Each c As Control In Me.Controls로 차례로 돌아 주세요. 번호는 Tag에 담을 수 있습니다.',
  DiagnosticCode.eventHasOtherName:
      'GuBASIC에서는 {0} 이벤트의 이름이 다릅니다. 이벤트 이름은 {1} 이벤트이니 {2} 형태로 써 주세요.',
  DiagnosticCode.placedInDesigner:
      '{0} 컨트롤은 New로 만들지 않고 디자이너에서 폼에 놓습니다. 도구 상자에서 넣고, 속성은 코드에서 정해 주세요.',
  DiagnosticCode.vb6KeyHandler:
      'GuBASIC에서는 키 이벤트가 매개변수 하나로 키를 알려 줍니다. {1} 형태로 쓰고, e.KeyCode(e.KeyCode = Keys.Left처럼)와 e.Shift, e.Control, e.Alt를 읽어 주세요.',
  DiagnosticCode.vb6MouseHandler:
      'GuBASIC에서는 마우스 이벤트가 매개변수 하나로 단추와 위치를 알려 줍니다. {1} 형태로 쓰고, e.Button(e.Button = MouseButtons.Right처럼)과 e.X, e.Y를 읽어 주세요.',
  DiagnosticCode.ambiguousName:
      '{0} 이름은 {1} 모듈에서 모두 Public이라 여기서 어느 것인지 알 수 없습니다. {2} 형태처럼 모듈 이름과 함께 써 주세요.',
  DiagnosticCode.mainTwice:
      '{0} 모듈에도 Sub Main이 있는데, 프로그램은 하나로 시작합니다. Sub Main은 한 모듈에만 두고 다른 것의 이름을 바꿔 주세요.',
  DiagnosticCode.typeHasOtherName:
      'GuBASIC에서는 {0} 타입의 이름이 {1} 타입입니다. {1} 이름으로 써 주세요.',
  DiagnosticCode.notAProcedure:
      '"{0}" 이름은 이 코드의 Sub 프로시저가 아니어서 이벤트를 처리할 수 없습니다. AddressOf 뒤에는 Sub 프로시저의 이름을 써 주세요.',
  DiagnosticCode.readOnlyProperty:
      '"{0}" 값은 읽기만 할 수 있습니다. 프로그램에서 값을 넣을 수 없습니다.',

  // Form and project files
  DiagnosticCode.fileSyntax:
      '이 파일을 여기부터 읽을 수 없습니다. 내용이 정해진 형식과 다릅니다. 들여쓰기와 각 키 뒤의 콜론(:)을 확인해 주세요.',
  DiagnosticCode.formatVersionMissing:
      '파일에 formatVersion 줄이 필요합니다. formatVersion: 1처럼 정수로 써 주세요.',
  DiagnosticCode.formatVersionTooNew:
      '이 파일은 더 새로운 GuBASIC으로 만들었습니다(formatVersion {0}). 이 GuBASIC은 {1} 버전까지 읽습니다. '
          'GuBASIC을 업데이트한 뒤 열어 주세요.',
  DiagnosticCode.unknownKey: '{0} 키는 GuBASIC이 모르는 키라서 무시합니다. 철자를 확인해 주세요.',
  DiagnosticCode.wrongValueForm: '{0} 키의 값이 정해진 형태가 아닙니다. {1} 형태로 써 주세요.',
  DiagnosticCode.invalidControlName: '"{0}" 값은 이름으로 쓸 수 없습니다. '
      '이름은 영문자로 시작하고 영문자, 숫자, _만 쓸 수 있으며 키워드나 Form은 쓸 수 없습니다.',
  DiagnosticCode.duplicateControlName:
      '{0} 이름은 {1}번 줄에서 이미 썼습니다. 컨트롤과 폼마다 다른 이름을 붙여 주세요.',
  DiagnosticCode.unknownControlType:
      '{0} 컨트롤 타입이 없습니다. 철자를 확인해 주세요(쓸 수 있는 타입: {1}).',
  DiagnosticCode.unknownProperty:
      '{1} 컨트롤에는 {0} 속성이 없습니다. 철자를 확인해 주세요(쓸 수 있는 속성: {2}).',
  DiagnosticCode.wrongPropertyType: '{0} 속성의 값은 {1} 타입이어야 합니다. 값을 확인해 주세요.',
  DiagnosticCode.unknownStartupForm:
      '시작 폼으로 정한 {0} 폼이 폼 목록에 없습니다. forms 목록에 추가하거나 목록에 있는 폼을 골라 주세요.',
  DiagnosticCode.propertyOutOfRange:
      '{0} 속성의 값은 {1} 이상 {2} 이하여야 합니다. 값을 확인해 주세요.',
  DiagnosticCode.invalidPictureName: '"{0}" 이름은 그림 이름으로 쓸 수 없습니다. '
      '그림 이름은 .png, .jpg, .jpeg, .gif로 끝나야 하고 / \\ : * ? " < > | 글자를 쓸 수 없습니다.',
  DiagnosticCode.duplicatePicture: '"{0}" 그림은 "{1}" 그림({2}번 줄)과 대소문자만 다릅니다. '
      'GuBASIC은 Windows, macOS처럼 둘을 같은 이름으로 보므로 한 프로젝트에 함께 둘 수 없습니다. 하나의 이름을 바꿔 주세요.',
  DiagnosticCode.unknownPicture:
      '프로젝트에 "{0}" 그림이 없습니다. 프로젝트의 그림에 넣거나 다른 그림을 골라 주세요.',
  DiagnosticCode.noSubMain:
      '프로젝트가 Sub Main으로 시작하는데, Sub Main()이 있는 모듈이 없습니다. 모듈에 Sub Main을 넣거나 폼으로 시작해 주세요.',
  DiagnosticCode.controlTypeHasOtherName:
      'GuBASIC에서는 {0} 컨트롤의 이름이 {1} 컨트롤입니다. type: {1} 형태로 써 주세요.',
  DiagnosticCode.notContainer:
      '{0} 컨트롤은 Frame이 아니어서 다른 컨트롤을 담지 못합니다. 그 컨트롤들을 폼이나 Frame의 controls: 아래로 옮겨 주세요.',
  DiagnosticCode.badProjectId:
      '"{0}" 값은 앱 ID가 아니어서 무시하고, 앱을 다음에 내보낼 때 새 ID를 만듭니다. 앱 ID는 영어 소문자와 숫자 8~32자입니다.',
  DiagnosticCode.badAnchor:
      '"{0}" 값은 Anchor 값이 아닙니다. 폼의 가장자리를 "Right Bottom"처럼 Left, Top, Right, Bottom으로 적거나, 없으면 ""로 적어 주세요.',
  DiagnosticCode.notDesignProperty: '{0} 속성은 폼 파일에 쓸 수 없습니다. '
      '프로그램이 실행될 때 정하거나 계산하는 속성입니다. 이 줄을 지우고, '
      '필요하면 코드(예: Form_Load)에서 정해 주세요.',

  // Run time
  DiagnosticCode.integerOverflow:
      '계산 결과가 Integer 범위(-9223372036854775808부터 9223372036854775807까지)를 넘었습니다. '
          '대략적인 값이면 충분할 때는 Double로 계산해 주세요.',
  DiagnosticCode.divisionByZero:
      '0으로 나눌 수 없습니다. If d <> 0 Then처럼 나누는 수를 먼저 확인해 주세요.',
  DiagnosticCode.indexOutOfRange:
      '번호 {0} 항목이 없습니다(항목 수: {1}, 번호는 0부터). 번호를 확인해 주세요.',
  DiagnosticCode.nothingReference:
      '이 객체는 Nothing이라서 멤버나 항목이 없습니다. New 등으로 먼저 만들어 주세요.',
  DiagnosticCode.conversionFailed:
      '"{0}" 값은 {1} 타입으로 바꿀 수 없습니다. 바꾸기 전에 값을 확인해 주세요.',
  DiagnosticCode.memberNotFound:
      '{1} 타입 값에는 {0} 멤버가 없습니다. Object 변수에 무엇이 들어 있는지 확인해 주세요.',
  DiagnosticCode.invalidArgument:
      '{0} 함수에 넘긴 값이 받을 수 있는 범위를 벗어났습니다. 인수를 확인해 주세요.',
  DiagnosticCode.settingsTooLarge: '이 프로그램의 설정이 65536자를 넘게 됩니다. '
      '저장하는 값을 줄이거나 짧게 해 주세요.',
  DiagnosticCode.pictureNotFound:
      '이 프로젝트에 "{0}" 그림이 없습니다. 그림을 프로젝트에 넣거나 이름을 확인해 주세요.',
  DiagnosticCode.badAnchorValue:
      '"{0}" 값은 Anchor 값이 아닙니다. 가장자리를 "Right Bottom"처럼 Left, Top, Right, Bottom으로 적거나, 없으면 ""로 적어 주세요.',
  DiagnosticCode.dialogAlreadyShown:
      '{0} 폼은 이미 보이고 있어서 대화상자로 띄울 수 없습니다. 먼저 숨기거나 닫고, 아니면 {0}.Show를 써 주세요.',
  DiagnosticCode.controlNameTaken:
      '{1} 폼에는 이미 {0} 컨트롤이 있습니다. 새 컨트롤을 넣기 전에 Name을 다르게 정해 주세요.',
  DiagnosticCode.controlAlreadyOnForm:
      '{0} 컨트롤은 이미 {1} 폼에 있습니다. 컨트롤은 한 번에 한 폼에만 있을 수 있으니, 먼저 거기서 빼 주세요.',
  DiagnosticCode.controlNotOnForm:
      '{0} 컨트롤은 {1} 폼에 없어서 뺄 수 없습니다. 어느 폼에 넣었는지 확인해 주세요.',
  DiagnosticCode.nameOfControlOnForm:
      '{0} 컨트롤은 폼에 있어서 Name을 더 바꿀 수 없습니다. Name은 Controls.Add 전에 정해 주세요.',
  DiagnosticCode.badControlName:
      '"{0}" 값은 이름이 아닙니다. 컨트롤의 Name은 영어 글자로 시작하고, 그다음에 글자, 숫자, "_"만 씁니다.',
  DiagnosticCode.eventAlreadyHandled:
      '{0} 이벤트에는 이미 {1} 처리기가 있고, 이벤트 하나는 처리기 하나가 처리합니다. 그 프로시저를 쓰거나 다른 컨트롤을 써 주세요.',
  DiagnosticCode.castFailed:
      '이 값은 {1} 타입이 아니라 {0} 타입이어서 CType으로 바꿀 수 없습니다. 먼저 TypeOf 값 Is {1} 형태로 확인해 주세요.',
  DiagnosticCode.frameNotEmpty:
      '{0} 컨트롤 안에 다른 컨트롤이 있어서 폼에서 뺄 수 없습니다. 안에 있는 컨트롤부터 빼 주세요.',
  DiagnosticCode.settingsNotSaved: '설정을 저장하지 못했습니다({0}). '
      '설정을 보관하는 곳에 자리가 없을 수 있습니다.',
  DiagnosticCode.unhandledException:
      '오류가 발생했지만 처리하지 않았습니다: {0}. Try ... Catch로 잡아서 처리해 주세요.',
  DiagnosticCode.callsTooDeep:
      '프로시저 호출이 너무 깊어졌습니다(연속 {0}번 초과). 재귀가 끝나는 조건을 확인해 주세요.',
  DiagnosticCode.propertyValueOutOfRange:
      '{0} 속성의 값은 {1} 이상 {2} 이하여야 합니다. 넣기 전에 값을 확인해 주세요.',

  DiagnosticCode.localHidesField:
      '이 지역 변수 {0} 이름이 {1}번 줄에서 선언한 같은 이름의 폼 변수를 가립니다. '
          '여기서는 폼 변수를 쓸 수 없습니다. 둘 중 하나의 이름을 바꾸거나, 호출 사이에 값을 남기려면 Static을 써 주세요.',
};
