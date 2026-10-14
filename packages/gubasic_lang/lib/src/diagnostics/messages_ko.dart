import 'diagnostic.dart';

/// Korean diagnostic messages. `{0}`, `{1}`, … are replaced by
/// [Diagnostic.args].
///
/// Written in the same "~합니다" style as the Korean documents: what is
/// wrong and how to fix it, in one or two sentences.
const Map<DiagnosticCode, String> koreanMessages = {
  DiagnosticCode.unterminatedString: '문자열이 닫히지 않았습니다. 같은 줄 안에서 따옴표(")로 닫아 주세요.',
  DiagnosticCode.nonAsciiIdentifier:
      '변수 이름에는 영문자, 숫자, _만 쓸 수 있는데 "{0}"에 다른 문자가 들어 있습니다. '
          '한글은 문자열("...")이나 주석(\')에 써 주세요.',
  DiagnosticCode.statementSeparator:
      'GuBASIC은 한 줄에 한 문장만 씁니다. ":" 대신 줄을 바꿔 다음 문장을 써 주세요.',
  DiagnosticCode.unexpectedCharacter: '"{0}" 문자는 GuBASIC에서 쓰지 않습니다. '
      '지우거나, 글자 그대로 쓰려면 문자열("...") 안에 넣어 주세요.',
  DiagnosticCode.misplacedLineContinuation: '"_"는 줄의 맨 끝에 있을 때만 다음 줄로 이어 씁니다. '
      '줄 끝으로 옮기거나 지워 주세요. 이름은 영문자로 시작해야 합니다.',
  DiagnosticCode.integerTooLarge:
      '{0}은 Integer에 담기에는 너무 큰 수입니다(가장 큰 값은 9223372036854775807). '
          '더 큰 수가 필요하면 {0}.0처럼 소수점을 붙여 Double로 써 주세요.',
};
