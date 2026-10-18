# GuBASIC 언어 (초안)

[English](LANGUAGE.md)

GuBASIC은 VB.NET을 단순화한 BASIC입니다. 이 문서는 **초안**입니다. 나중에 바꾸기 어려운 결정은 확정하고, 나머지는 열어 둡니다.

---

## 1. 어휘 규칙

| 규칙 | 결정 |
|---|---|
| 대소문자 | **구분하지 않습니다.** VB처럼 편집기가 모든 사용처를 선언할 때의 표기로 고쳐 줍니다. 트랜스파일러도 그 표기로 출력합니다. |
| 식별자 | **ASCII만:** 영문자로 시작하고, 뒤에는 영문자, 숫자, `_`. 한글(및 모든 비ASCII 문자)은 문자열과 주석에 쓸 수 있습니다. |
| 주석 | `'`부터 줄 끝까지. `REM`도 허용하지만 단어 전체일 때만입니다 (`REM 메모`는 주석, `Remark`는 식별자). 문장 뒤에도 쓸 수 있습니다: `x = 1 REM 메모`. |
| 줄 잇기 | 줄의 맨 끝에 있는 `_`(뒤에는 공백이나 탭만 올 수 있음)는 문장을 다음 줄로 이어 줍니다. 그 밖의 자리에 있는 `_`는 오류입니다(L005). `x_`는 그냥 식별자입니다. |
| 한 줄의 문장 수 | 하나. `:` 구분은 오류입니다(L003). 그래도 렉서는 `:`를 문장의 끝으로 보고, 줄의 나머지 부분도 검사합니다. |
| 숫자 | 정수(`123`)와 실수(`1.5`). 실수는 점 **양쪽**에 숫자가 있어야 합니다. `.5`와 `1.`은 숫자가 아닙니다(`0.5`, `1.0`으로 씁니다). **지수 표기**를 쓸 수 있습니다: `1E+21`, `1.5E-7`, `2e10`. `E`는 대소문자 상관없고, 부호는 써도 되고 안 써도 되며, 그 뒤에 숫자가 옵니다. 지수 표기 리터럴은 항상 `Double`입니다. 글자 모양(2.2절)과 같은 표기라서 출력된 값을 그대로 다시 쓸 수 있습니다. `Double` 범위를 넘는 리터럴(`1E400`)은 오류(L008)이고, 0이 아닌 값을 썼는데 너무 작아서 정확히 0이 되는 리터럴(`1E-400`)은 경고(L009)합니다. 정밀도만 줄고 0이 아닌 값이 남는 수(`4E-324`)는 경고하지 않습니다. 빼기 기호는 숫자의 일부가 아니라 연산자입니다. |
| 문자열 | `"..."`; 따옴표를 두 번 쓴 `""`는 따옴표 문자 하나. 문자열은 시작한 줄에서 닫아야 합니다(L001). |
| 문장의 끝 | 줄바꿈이 문장을 끝냅니다. 빈 줄과 주석만 있는 줄은 무시합니다. |
| 위치 | 줄과 칸은 1부터 셉니다. 탭은 한 칸으로 셉니다. |
| Dart 예약어 | 식별자가 Dart 예약어(`var`, `class`, `is`, `new` 등)와 겹치면 트랜스파일러가 자동으로 이름을 바꿉니다. 사용자에게는 보이지 않습니다. |

### 1.1 키워드

키워드는 대소문자를 구분하지 않으며(`dim`, `DIM`, `Dim`은 같음) 이름으로 쓸 수 없습니다.

```
Dim As Const Static Public Private Sub Function End Exit Return
If Then ElseIf Else Select Case For To Step Each In Next Do Loop While Until
Try Catch Finally Throw New Nothing True False Not And Or Xor Mod Is Me
Handles ReDim Preserve Optional Of ByVal
```

다음 Visual Basic 키워드는 **예약만 되어 있고 지원하지 않습니다.** 편집기가 대신 쓸 방법을 안내할 수 있게 하기 위해서입니다.

| 키워드 | 상태 | 대신 쓸 것 |
|---|---|---|
| `ByRef` | 2단계 예정 | 7.2절 참고 |
| `On` (`On Error`) | 지원하지 않음 | `Try … Catch` |
| `GoTo`, `GoSub` | 지원하지 않음 | 반복문, `Exit`, 프로시저 |
| `Variant` | 지원하지 않음 | `Object` |
| `Class` | 1.0에는 없음 | — |
| `AndAlso`, `OrElse` | 지원하지 않음 | `And`, `Or` (이미 단락 평가함) |
| `Wend` | 지원하지 않음 | `Do While … Loop` |
| `Call` | 지원하지 않음 | 프로시저를 바로 호출: `ShowScore("Kim", 90)` |
| `Set`, `Let` | 지원하지 않음 | 그냥 대입: `x = 값` |

타입 이름(`Integer`, `String` 등)과 내장 함수(`MsgBox` 등)는 키워드가 아니라 보통의 식별자입니다.

점(`.`) 뒤에서는 키워드도 멤버 이름으로 쓸 수 있습니다: `obj.End`, `list.Next` (VB.NET과 같음).

### 1.2 진단

렉서, 파서, 분석기는 오류를 만나도 멈추지 않습니다. 오류를 알리고 계속 읽어서, 실수 하나가 나머지를 가리지 않게 합니다. 코드는 바뀌지 않으며 다시 쓰지 않습니다.

아래 표에서 **경고**라고 표시한 것 말고는 모두 **오류**입니다. 오류는 고쳐야 합니다. 경고는 동작은 하지만 뜻밖일 수 있는 것을 알려 주며, **프로그램의 실행이나 빌드를 막지 않습니다**(D23). 코드의 접두사는 심각도가 아니라 누가 알리는지(L 렉서, P 파서, A 분석기, F 폼·프로젝트 파일, R 실행 중)를 나타냅니다.

**렉서**

| 코드 | 문제 | 렉서의 처리 |
|---|---|---|
| L001 | 문자열이 그 줄에서 `"`로 닫히지 않음 | 줄의 나머지를 오류 토큰 하나로 만들고, 다음 줄은 정상으로 읽음 |
| L002 | 문자열·주석 밖의 비ASCII 문자(한글 등) | 단어 전체를 식별자로 읽어서 문장 검사를 계속할 수 있게 함 |
| L003 | `:`로 한 줄에 여러 문장을 씀 | 문장의 끝으로 처리 |
| L004 | GuBASIC에서 의미가 없는 문자(`@`, `#`, `$` 등) | 오류 토큰 |
| L005 | 줄의 맨 끝이 아닌 곳의 `_` | 오류 토큰 |
| L006 | `Integer`(64비트)에 담기지 않는 큰 정수 | 값이 없는 정수 토큰. 정확히 9223372036854775808이면 메시지가 `Integer.MinValue`를 안내 |
| L007 | **폐지됨**(D26으로 불필요): 웹이 정확히 담지 못하는 정수를 경고했지만, 이제 Integer는 모든 플랫폼에서 정확합니다. 코드는 다시 쓰지 않습니다 | — |
| L008 | `Double` 범위를 넘는 `Double` 리터럴 (`1E400`) | 값이 없는 Double 토큰 |
| L009 | **경고.** 0이 아닌 값을 썼지만 너무 작아서 정확히 0이 되는 `Double` 리터럴 (`1E-400`) | 값이 0인 Double 토큰. 실행은 막지 않음(D23) |

**파서**

파서가 오류에서 회복하는 방식:
- 문법 오류는 **문장 하나에 하나만** 알리고, 다음 줄로 넘어갑니다.
- 닫히지 않은 블록(`End If`가 없는 `If` 등)은 바깥 블록의 끝, 새 `Sub`/`Function`, 파일 끝을 만났을 때 **블록이 시작한 줄**에 알립니다.
- 렉서가 이미 오류를 알린 줄에는 파서가 문법 진단을 덧붙이지 않습니다.
- Visual Basic 기능에 대한 안내(P013~P022)는 항상 알리고, 가능하면 GuBASIC 방식으로 읽어서 나머지 부분도 계속 검사합니다.

| 코드 | 문제 | 파서의 처리 |
|---|---|---|
| P001 | 값이나 식이 빠짐 | 그 자리에 오류 노드를 넣음 |
| P002 | 키워드가 빠짐 (`Then`, `To`, `In`, `Case` 등) | 있는 것으로 보고 계속 읽음 |
| P003 | 기호가 빠짐 (`)`, `=`, `(`, `.`) | 있는 것으로 보고 계속 읽음 |
| P004 | 이름이 빠짐 | 빈 이름으로 처리 |
| P005 | 이 자리에 올 수 없는 내용 | 줄 끝까지 건너뜀 |
| P006 | 블록이 닫히지 않음 | 블록이 시작한 줄에 알림 |
| P007 | 열린 블록 없이 나온 닫는 문장 (`If` 없는 `End If` 등) | 그 줄을 건너뜀 |
| P008 | `Sub`나 `Function` 밖의 문장 | 트리에는 남겨 둠 |
| P009 | 이 자리에 쓸 수 없는 선언 (프로시저 안의 `Public`, 밖의 `Static`) | `Dim`으로 읽음 |
| P010 | `For i`를 `Next j`로 닫음 | — |
| P011 | 괄호 없는 인수 (`MsgBox "Hi"`) | `MsgBox("Hi")`로 읽음 |
| P012 | 선언 하나에 변수 여러 개 (`Dim a, b`) | 첫 번째만 남김 |
| P013 | `On Error` | 줄을 건너뜀. `Try … Catch`를 씀 |
| P014 | `GoTo`, `GoSub` | 줄을 건너뜀. 반복문, `Exit`, 프로시저를 씀 |
| P015 | `Variant` | 타입 이름으로 읽음. `Object`를 씀 |
| P016 | `Class … End Class` | 클래스 전체를 건너뜀 |
| P017 | `AndAlso`, `OrElse` | `And`, `Or`로 읽음 |
| P018 | `While … Wend` / `While … End While` | `Do While … Loop`로 읽음 |
| P019 | `Call` | `Call` 없이 호출로 읽음 |
| P020 | `Set`, `Let` | 그냥 대입으로 읽음 |
| P021 | `ByRef` (아직 준비 중, 2단계) | 정상으로 읽음. 메시지는 `Return`을 쓰는 `Function`을 안내 |
| P022 | `Handles` (아직 준비 중, 2단계) | 정상으로 읽음. 메시지는 `컨트롤이름_이벤트이름` 형태의 Sub 프로시저를 안내 |
| P023 | 열린 괄호 안에서 값이 빠진 채 줄이 끝남 (`(1 +`, `f(1,`) | 값과 `)` 누락을 진단 하나로 알림 |

**분석기**

분석기는 이름과 타입을 검사합니다(2.1절, 3.2절, 5.2절). 파서가 오류를 찾았어도 실행되며, 알아낼 수 없는 부분은 다시 검사하지 않아서 실수 하나에 진단 하나가 나옵니다.

| 코드 | 문제 |
|---|---|
| A001 | 선언하지 않은 이름 |
| A002 | 선언하지 않은 이름. 철자가 비슷한 이름이 있음("혹시 이것인가요") |
| A003 | 폼이 없는 코드(놀이터)에서 `.`과 함께 쓴 선언하지 않은 이름(`lblMessage.Caption`) 또는 `Me`: 컨트롤과 `Me`는 폼이 있어야 쓸 수 있음(11절) |
| A004 | 없는 타입 이름 |
| A005 | 같은 범위나 프로시저에 이미 선언한 이름 |
| A006 | 지역 변수를 선언보다 먼저 씀 |
| A007 | 타입도 값도 없는 `Dim`, `As`가 없는 매개변수나 `Function` |
| A008 | 다른 타입이 필요한 자리에 넣은 값(2.1절) |
| A009 | 숫자가 필요한 자리의 문자열(`CInt`, `CDbl`, `Val` 사용) |
| A010 | `Integer`가 필요한 자리의 `Double`(`CInt`나 `Int` 사용) |
| A011 | 문자열과 숫자를 `+`로 이음(`&` 사용) |
| A012 | `True`/`False`가 아닌 조건 |
| A013 | 이항 연산자를 쓸 수 없는 타입 |
| A014 | 단항 연산자를 쓸 수 없는 타입 |
| A015 | 인수 개수가 맞지 않음 |
| A016 | `Sub`나 `Function`이 아닌 것을 호출함 |
| A017 | 값이 필요한 자리에 쓴 `Sub` |
| A018 | 번호로 꺼낼 항목이 없는 값에 `(번호)`를 씀 |
| A019 | 타입에 없는 멤버 |
| A020 | `=` 왼쪽에 올 수 없는 것(상수, 프로시저, 호출 결과) |
| A021 | VB6 방식의 `함수이름 = 값`(`Return 값` 사용) |
| A022 | `Sub` 안의 `Return 값` |
| A023 | `Function` 안의 값 없는 `Return` |
| A024 | 짝이 맞는 반복문이나 프로시저 밖의 `Exit For` / `Exit Do` / `Exit Sub` / `Exit Function` |
| A025 | `List`나 배열이 아닌 값에 쓴 `For Each` |
| A026 | **경고.** 쓰지 않는 지역 변수 |
| A027 | **경고.** `Return`이 없는 `Function` |
| A028 | **경고.** 같은 이름의 폼 변수를 가리는 지역 변수 |
| A029 | **폐지**(D48로 필요 없어짐): `SaveSetting`과 `GetSetting`을 아직 쓸 수 없다고 알렸음. 번호는 다시 쓰지 않음 |
| A030 | 컨트롤과 같은 이름의 폼 변수나 프로시저(11절) |
| A031 | **경고.** 컨트롤과 같은 이름이라서 그 컨트롤을 가리는 지역 변수 |
| A032 | 이벤트가 정한 형태와 다르게 쓴 이벤트 처리기(8절) |
| A033 | 컨트롤 타입에 쓴 `New`: 컨트롤은 아직 코드로 만들 수 없음(2단계) |
| A034 | 프로그램이 읽기만 할 수 있는 속성에 값을 넣음(`lstNames.ListCount = 3`, `names.Count = 0`) |
| A035 | 타입에 없는 멤버. 철자가 비슷한 멤버가 있음(`lstCity.ListIndx`: "혹시 ListIndex인가요") |
| A036 | 타입에 없는 멤버. 다른 버전의 BASIC에서 쓰는 이름이고, GuBASIC에서는 이름이 다름(`btnOK.Text`: `Caption`을 씀. DESIGN.ko.md D50) |

**폼·프로젝트 파일**

폼 파일과 프로젝트 파일(11.2절, 11.3절)도 같은 방식으로 검사합니다. 문제는 파일 안의 그 자리에 알리고, 나머지는 계속 읽습니다.

| 코드 | 문제 |
|---|---|
| F001 | 이 자리부터 내용이 정해진 형식(YAML)과 다름 |
| F002 | `formatVersion`이 없거나 정수가 아님 (버전 1로 읽음) |
| F003 | 더 새로운 GuBASIC으로 만든 파일. 나머지는 읽지 않음 |
| F004 | **경고.** GuBASIC이 모르는 키. 무시함 |
| F005 | 형태가 틀린 값 (목록이 아닌 `controls`, `type`이 없는 컨트롤 등) |
| F006 | 없거나 쓸 수 없는 컨트롤·폼 이름 |
| F007 | 이름이 같은 컨트롤 둘, 또는 프로젝트의 폼 둘 (대소문자 무관) |
| F008 | 없는 컨트롤 타입 |
| F009 | 컨트롤 타입에 없는 속성 |
| F010 | 타입이 틀린 속성 값 |
| F011 | `startup`에 적은 폼이 `forms`에 없음 |
| F012 | 범위를 벗어난 `Integer` 속성 값(11.1절) |
| F013 | 폼 파일에 쓸 수 없는 속성: 프로그램이 실행 중에 정하거나(`ListIndex`) 읽기만 하는 속성(11.1절) |

**실행 중**

프로그램이 도는 동안 발견하는 오류입니다. `Try`로 잡지 않으면(9절) 프로그램을 멈추고 그 줄을 알려 줍니다.

| 코드 | 문제 |
|---|---|
| R001 | `Integer` 결과가 64비트 범위를 넘음 (`+ - *`, 단항 `-`, `\`, `CInt`, `Int`, `Round`, `For` 카운터) |
| R002 | `/`, `\`, `Mod`로 0으로 나눔 |
| R003 | 배열, 목록, 문자열의 범위를 벗어난 번호 (`Substring`, `Insert`, `RemoveAt`) |
| R004 | `Nothing`인 객체의 멤버나 항목을 씀 |
| R005 | 바꿀 수 없는 문자열 (`CInt("abc")`, `CBool("maybe")`) |
| R006 | `Object` 변수에 든 값에 없는 멤버를 씀 |
| R007 | 내장 함수가 받을 수 없는 인수 (`Sqr(-1)`, `Mid(s, 0)`, `Round(x, 16)`) |
| R008 | 던졌지만 아무도 잡지 않은 예외 |
| R009 | 프로시저 호출이 10,000단계보다 깊어짐 (끝나지 않는 재귀) |
| R010 | 범위를 벗어난 값을 `Integer` 속성에 넣음(11.1절) |
| R011 | `SaveSetting`으로 프로그램의 설정이 65536자를 넘게 됨(10절) |
| R012 | `SaveSetting`이 설정을 저장하지 못함. 예: 브라우저 저장 공간이 가득 참(10절) |

## 2. 타입

| GuBASIC | Dart | 기본값 |
|---|---|---|
| `Integer` | `int` | `0` |
| `Double` | `double` | `0.0` |
| `Boolean` | `bool` | `False` |
| `String` | `String` | `""` |
| `Date` | `DateTime` | 0001-01-01 |
| `Object` | `Object?` | `Nothing` |
| `List(Of T)` | `List<T>` | 빈 목록 (`New`로 선언할 때) |
| 컨트롤·컴포넌트 타입 (`Button`, `Label` 등) | 런타임 클래스 | `Nothing` |

- **`Integer`는 모든 플랫폼에서 정확한 64비트 정수**이며, 웹도 마찬가지입니다(D26). 범위는 `Integer.MinValue`(-9223372036854775808)부터 `Integer.MaxValue`(9223372036854775807)까지입니다. 이 범위를 넘는 결과는 조용히 틀린 수가 되지 않고 실행 중 오류(R001)가 됩니다.
- **`Nothing`(null)은 객체에만 있습니다.** 값 타입은 항상 값이 있으므로 초보자가 null 오류를 만날 일이 거의 없습니다.
- **객체가 `Nothing`인지는 `Is`로 비교합니다:** `If player Is Nothing Then`. 반대는 `If Not player Is Nothing Then`으로 씁니다. (`=`는 객체가 아니라 값을 비교합니다.)
- **`Variant`는 없습니다.** 정말 아무 값이나 담아야 하면 `Object`를 씁니다.
- **컨트롤 타입**(`Form`, `Button`, `Label`, `TextBox`, `CheckBox`, `ListBox`. 11.1절)은 `As` 뒤에 쓸 수 있고, 컨트롤은 객체입니다: `Dim b As Button = btnSave`, `If b Is Nothing Then`. 컨트롤은 아직 `New`로 만들 수 없으며(A033), 컨트롤은 폼에 있는 것들입니다.

### 2.1 자동 변환

대입, 인수, `Return` 값에 같은 규칙이 적용됩니다. 그 밖의 변환에는 변환 함수가 필요합니다.

| 출발 → 도착 | |
|---|---|
| `Integer` → `Double` | 자동 |
| `Integer`, `Double`, `Boolean`, `Date` → `String` | 자동. 2.2절의 글자 모양으로 바뀜(`lblCount.Caption = count`) |
| 모든 값 → `Object` | 자동 |
| `Nothing` → `Object`, `List`, 배열, `Exception` | 자동. `String`이나 다른 값 타입에는 안 됨 |
| `String` → 숫자 | **안 됨**(A009): `CInt`, `CDbl`, `Val`을 씀 |
| `Double` → `Integer` | **안 됨**(A010): `CInt`(반올림)나 `Int`(내림)를 씀. 그렇지 않으면 소수 부분이 소리 없이 사라지기 때문 |
| `Object` → 구체적인 타입 | **안 됨**(A008): `CInt`, `CDbl`, `CStr`, `CBool`을 씀 |
| `Boolean` ↔ 숫자 | **안 됨**(A008) |

**반올림.** `CInt`와 `Round`는 학교 수학과 엑셀의 ROUND처럼 0.5를 **0에서 먼 쪽**으로 올립니다(사사오입): `CInt(2.5)`는 3, `CInt(-2.5)`는 -3입니다. `Int`는 **더 작은 쪽 정수로 내립니다**: `Int(2.5)`는 2, `Int(-2.5)`는 -3입니다. 이는 Visual Basic과 다릅니다. Visual Basic의 `CInt`는 0.5를 가까운 짝수로 보내고(2.5 → 2) ([Type Conversion Functions](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/functions/type-conversion-functions)), `Math.Round`도 기본으로 같은 방식입니다([Math.Round](https://learn.microsoft.com/en-us/dotnet/api/system.math.round)). 초보자에게 2.5 → 2는 버그처럼 보입니다. 또 Visual Basic의 `Int`는 받은 값과 같은 타입을 돌려주지만([Type Conversion Functions](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/functions/type-conversion-functions)), GuBASIC의 `Int`는 `Integer`를 돌려주므로 `Int(x)`를 `Integer` 변수에 바로 넣을 수 있습니다.

### 2.2 값의 글자 모양

`String`으로의 자동 변환, `CStr`, `&`, `Debug.Print`는 모두 한 가지 규칙을 쓰며, 모든 플랫폼에서 같은 글자가 나옵니다. 같은 표기를 리터럴로도 쓸 수 있고, 출력된 값을 다시 쓰면 같은 수가 됩니다(정수 값인 `Double`은 소수점 없이 출력되므로, 다시 쓰면 같은 값의 `Integer`로 읽힙니다).

| 타입 | 글자 모양 | 예 |
|---|---|---|
| `Integer` | 숫자 그대로 | `42`, `-7` |
| `Double` | 정수 값이면 소수점 없이, 아니면 원래 값을 정확히 되살릴 수 있는 가장 짧은 표기. 크기가 1E-6 이상 1E+15 미만이면 소수점 표기, 그 밖에는 `d.dddE±n` | `1`, `0.25`, `0.30000000000000004`, `1E+15`, `2.5E-7`. `-0`은 `0`, 그 밖에 `NaN`, `Infinity`, `-Infinity` |
| `Boolean` | `True` / `False` | |
| `Date` | `yyyy-MM-dd HH:mm:ss` | `2026-03-07 09:05:02` |

## 3. 변수

### 3.1 선언

```vb
Dim score As Integer          ' 타입 명시
Dim name = "Jekyll"           ' String으로 추론
Dim total As Integer = 100    ' 타입과 초깃값
```

**선언은 항상 필수입니다** (`Option Explicit`가 늘 켜져 있음). 선언하지 않은 이름을 쓰면 컴파일 오류가 납니다. 오타를 잡아 줍니다.

**선언 하나에 변수 하나.** `Dim a, b As Integer`는 쓸 수 없습니다(P012). VB6에서는 `a`가 `Variant`, VB.NET에서는 `Integer`가 되어 뜻이 갈립니다. 한 줄에 변수 하나씩 쓰면 헷갈릴 일이 없습니다.

### 3.2 범위와 수명

| 종류 | 위치·방법 | 보이는 범위 | 사라지는 때 |
|---|---|---|---|
| 지역 | `Sub` / `Function` 안의 `Dim` | 그 프로시저 | 호출이 끝날 때 |
| 폼 변수 | 폼 코드 맨 위의 `Dim`(또는 `Private`) | 그 폼의 모든 프로시저 | 폼이 닫힐 때 |
| 전역 | 모듈 파일(`Module1.gbas`)의 `Public` | 앱 전체 | 앱이 끝날 때 |
| 정적 | 프로시저 안의 `Static` | 그 프로시저 | 앱이 끝날 때 (호출 사이에 값 유지) |

```vb
Sub btnCount_Click()
    Static count As Integer
    count = count + 1
    lblCount.Caption = count
End Sub
```

Dart에는 정적 지역 변수가 없어서, 트랜스파일러가 `Static`을 숨겨진 폼 필드로 바꿉니다.

**이름 규칙**(분석기가 검사):
- 이름은 가장 안쪽 블록에서 바깥으로 찾습니다: 블록 지역 변수, 프로시저의 지역 변수와 매개변수, 폼 변수와 프로시저, 마지막으로 내장 함수. 대소문자는 구분하지 않습니다.
- **블록(`If`, `For`, `Do`, `Select Case`, `Try`) 안의 `Dim`은 그 블록 안에서만 보입니다.** 나란히 있는 두 블록은 같은 이름을 다시 쓸 수 있습니다.
- 한 프로시저 안에서는 블록이 달라도 같은 이름을 한 번만 선언할 수 있습니다(A005).
- 폼 변수와 같은 이름의 지역 변수는 쓸 수 있지만 경고합니다(A028). 그 자리에서는 폼 변수를 쓸 수 없게 되어, `Static`이어야 할 카운터에서 흔히 실수하기 때문입니다.
- 지역 변수는 선언한 줄 아래에서만 쓸 수 있습니다(A006). 폼 변수와 프로시저는 파일 어디서나 쓸 수 있습니다.
- **`Dim`은 실행될 때마다 변수를 새로 시작합니다**(초깃값이나 타입의 기본값으로). 그래서 반복문 안의 `Dim`은 돌 때마다 처음부터 시작합니다. 반복 사이에 값을 남기려면 `Static`이나 반복문 위의 `Dim`을 씁니다. 이는 Visual Basic과 다릅니다. Visual Basic에서는 블록 안에서 선언한 변수를 프로시저가 시작될 때 한 번만 초기화합니다([Lifetime](https://learn.microsoft.com/en-us/dotnet/visual-basic/programming-guide/language-features/declared-elements/lifetime)).

### 3.3 상수

```vb
Const MaxScore As Integer = 100
```

## 4. 배열과 목록

- **배열은 0부터 시작하고, `Dim`의 숫자는 마지막 번호입니다** (VB.NET과 같음). `Dim a(5)`는 `a(0)`부터 `a(5)`까지 6칸입니다.
- 동적 배열:

  ```vb
  Dim a() As Integer
  ReDim a(9)              ' 10칸, 값 초기화
  ReDim Preserve a(19)    ' 20칸, 기존 값 유지
  ```

- `UBound(a)`는 마지막 번호를 돌려줍니다.
- 새 코드에서는 목록을 권장합니다.

  ```vb
  Dim names As New List(Of String)
  names.Add("Kim")
  For Each n In names
      lstNames.AddItem(n)
  Next
  ```

## 5. 연산자

| 종류 | 연산자 |
|---|---|
| 산술 | `+ - * /` (`/`는 항상 `Double`), `\` 정수 나눗셈, `Mod`, `^` 거듭제곱 |
| 문자열 연결 | `&` (권장); 두 문자열에는 `+`도 가능 |
| 비교 | `= <> < > <= >=` |
| 같은 객체인지 | `Is` (예: `x Is Nothing`) |
| 논리 | `Not`, `And`, `Or`, `Xor` |
| 대입 | `=` (문장으로 쓸 때) |

- **`And`와 `Or`는 단락 평가합니다.** `AndAlso` / `OrElse`는 없습니다.
- `&`는 숫자를 자동으로 문자열로 바꿉니다: `"점수: " & 90`.

### 5.1 우선순위

VB.NET과 같고, 위쪽이 먼저 계산됩니다. 같은 단계의 연산자는 **왼쪽부터** 계산합니다.

| 단계 | 연산자 |
|---|---|
| 1 | `^` |
| 2 | 단항 `-`, 단항 `+` |
| 3 | `*`, `/` |
| 4 | `\` |
| 5 | `Mod` |
| 6 | `+`, `-` |
| 7 | `&` |
| 8 | `=`, `<>`, `<`, `>`, `<=`, `>=`, `Is` |
| 9 | `Not` |
| 10 | `And` |
| 11 | `Or` |
| 12 | `Xor` |

| 식 | 뜻 | 값 |
|---|---|---|
| `1 + 2 * 3 ^ 2` | `1 + (2 * (3 ^ 2))` | 19 |
| `-2 ^ 2` | `-(2 ^ 2)` | -4 |
| `2 ^ 3 ^ 2` | `(2 ^ 3) ^ 2` | **64** |
| `Not a = b And c` | `(Not (a = b)) And c` | |
| `"n=" & n + 1` | `"n=" & (n + 1)` | |

- **`^`도 왼쪽부터 계산합니다.** VB와 엑셀은 `2 ^ 3 ^ 2`를 `(2 ^ 3) ^ 2` = 64로 계산합니다. 2^3^2를 2^(3^2) = 512로 읽는 수학 표기와 다릅니다. 512를 원하면 `2 ^ (3 ^ 2)`로 씁니다.
- **문장 맨 앞의 `=`는 대입이고, 그 밖의 `=`는 비교입니다.** `x = y = z`는 `y`와 `z`가 같은지를 `x`에 넣습니다.

### 5.2 피연산자와 결과의 타입

| 연산자 | 피연산자 | 결과 |
|---|---|---|
| `+ - *` | 숫자 | 둘 다 `Integer`면 `Integer`, 아니면 `Double` |
| `+` | `String` 둘 | `String` |
| `/`, `^` | 숫자 | 항상 `Double` |
| `\` | **`Integer`만**(먼저 `CInt`나 `Int`를 씀) | `Integer` |
| `Mod` | 숫자 | 둘 다 `Integer`면 `Integer`, 아니면 `Double` |
| `&` | 모든 값(2.2절) | `String` |
| `= <> < > <= >=` | 숫자 둘, `String` 둘, `Date` 둘. `Boolean`은 `=`와 `<>`만 | `Boolean` |
| `Is` | 객체나 `Nothing` | `Boolean` |
| `Not`, `And`, `Or`, `Xor` | **`Boolean`만** | `Boolean` |

- `"1" + 1`은 오류입니다(A011). 문자열은 숫자로 자동으로 바뀌지 않고, 숫자를 문자열로 바꾸면 소리 없이 `"11"`이 되기 때문입니다. 이으려면 `&`를, 더하려면 `CInt`를 씁니다.
- GuBASIC 1.0에서 `And`, `Or`, `Xor`, `Not`은 `True`/`False`에만 쓰므로, 비트 연산이 아니라 항상 논리 연산입니다.
- **조건**(`If`, `ElseIf`, `Do While`, `Loop Until` 등)은 `True`나 `False`여야 합니다. `If count Then`이 아니라 `If count <> 0 Then`으로 씁니다(A012).

### 5.3 실행 중 계산

- **정수 넘침은 오류입니다(R001).** Visual Basic도 기본으로 정수 넘침을 검사합니다([-removeintchecks](https://learn.microsoft.com/en-us/dotnet/visual-basic/reference/command-line-compiler/removeintchecks)).
- **0으로 나누기는 `/`, `\`, `Mod` 모두 오류입니다(R002).** `\`는 Visual Basic도 같습니다([\ Operator](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/operators/integer-division-operator)). `/`에 `Double` 값을 쓰면 Visual Basic은 무한대나 NaN을 돌려주지만([/ Operator](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/operators/floating-point-division-operator)), GuBASIC은 오류로 알립니다. 초보자가 일부러 0으로 나누는 일은 드물기 때문입니다.
- `\`는 0 쪽으로 버립니다(`-7 \ 2`는 -3). `Mod`의 부호는 왼쪽 값을 따릅니다(`-7 Mod 3`은 -1).
- 너무 커진 `Double`은 `Infinity`가 되며, 오류가 아닙니다.

## 6. 제어 구조

```vb
If score >= 90 Then
    grade = "A"
ElseIf score >= 80 Then
    grade = "B"
Else
    grade = "C"
End If

Select Case day
    Case 1, 7
        kind = "주말"
    Case 2 To 6
        kind = "평일"
    Case Is > 7
        kind = "잘못된 값"
    Case Else
        kind = "?"
End Select

For i = 1 To 10 Step 2
Next

For Each item In items
Next

Do While running
    DoEvents
Loop

Do
Loop Until done
```

`Exit For`, `Exit Do`, `Exit Sub`, `Exit Function`을 지원합니다. `GoTo`는 지원하지 않습니다.

- **한 줄 `If`.** `If x > 0 Then y = 1 Else y = 2`는 문장 하나이며 `End If`가 필요 없습니다. 한 줄에는 간단한 문장(대입, 호출, `Exit`, `Return` 등)만 쓸 수 있고, 반복문 같은 블록은 여러 줄 형태로 씁니다.
- **반복 변수에 타입을 붙일 수 있습니다:** `For i As Integer = 1 To 10`, `For Each name As String In names`.
- **선언하지 않은 반복 변수는 그 반복문 안에서만 쓰는 변수로 자동 선언합니다.** `i`를 선언하지 않고 `For i = 1 To 10`이라고 쓰면, 반복문 안에서만 있는 `i`가 생깁니다. 타입은 시작, 끝, Step 값에서 정합니다(하나라도 `Double`이면 `Double`, 아니면 `Integer`). `For Each`이면 목록이나 배열의 항목 타입을 따릅니다. 이미 선언된 변수는 그대로 씁니다. Visual Basic도 같습니다([For...Next, Counter Argument](https://learn.microsoft.com/en-us/dotnet/visual-basic/language-reference/statements/for-next-statement)).

## 7. 프로시저

```vb
Sub ShowScore(name As String, score As Integer)
    MsgBox(name & ": " & score)
End Sub

Function Average(a As Integer, b As Integer) As Double
    Return (a + b) / 2
End Function
```

- 인수는 항상 괄호 안에 씁니다: `ShowScore("Kim", 90)`. 인수가 없는 호출은 괄호를 생략할 수 있습니다: `Form2.Show`, `DoEvents`. VB6 방식의 `MsgBox "Hi"`는 진단합니다(P011).
- **함수는 `Return`으로만 결과를 돌려줍니다.** 함수 이름에 대입하는 VB6 방식(`Average = (a + b) / 2`)은 지원하지 않습니다. 분석기가 그 줄을 짚어 주고 `Return`을 쓰라고 안내합니다.
- 선택 매개변수: `Optional title As String = "안내"`.

### 7.1 인수 전달: `ByVal`

매개변수는 **값으로 전달**됩니다. `ByVal`은 기본값이라 써도 되고 생략해도 됩니다. 다음 두 줄은 같은 뜻입니다.

```vb
Sub ShowScore(ByVal name As String, ByVal score As Integer)
Sub ShowScore(name As String, score As Integer)
```

값이 객체(`List`, 컨트롤 등)이면 프로시저는 복사본이 아니라 **같은 객체**를 받습니다. 객체의 내용은 바꿀 수 있지만, 호출한 쪽 변수가 다른 객체를 가리키게 할 수는 없습니다.

```vb
Sub Fill(items As List(Of String))
    items.Add("Kim")                  ' 호출한 쪽의 목록이 바뀜
    items = New List(Of String)       ' 지역 매개변수만 바뀜
    items.Add("Lee")                  ' 새 목록에 들어가며, 호출한 쪽은 이 목록을 보지 못함
End Sub

Sub Form_Load()
    Dim names As New List(Of String)
    Fill(names)
    ' 이제 names에는 "Kim"만 들어 있음
End Sub
```

### 7.2 `ByRef` (2단계)

`ByRef`를 쓰면 프로시저가 호출한 쪽의 변수에 값을 넣을 수 있습니다. 아직은 쓸 수 없지만, 편집기가 그렇게 안내할 수 있도록 키워드는 예약해 두었습니다. 구현 방침:

- **읽기·쓰기 클로저 쌍.** `ByRef` 인수는 호출한 쪽 변수를 읽는 클로저와 쓰는 클로저, 두 개로 전달합니다. 모든 프로시저가 비동기라서(DESIGN.ko.md 3.1절) 프로시저는 어느 `await`에서든 멈출 수 있습니다. 클로저는 그동안에도 호출한 쪽 변수를 계속 가리키고, 인터프리터와 트랜스파일된 Dart가 같은 방식을 씁니다.
- **배열 요소는 호출 시점에 고정.** `Swap(a(i), a(j))`에서 배열과 인덱스는 호출할 때 한 번만 계산합니다. 프로시저가 도는 동안 `i`가 바뀌어도, 처음 넘겨받은 요소를 계속 읽고 씁니다.
- **속성은 복사 후 되돌려 쓰기(copy-in/copy-out).** `Clean(txtName.Text)`에서 속성 값을 호출 전에 임시 변수로 읽고, 프로시저는 그 임시 변수로 일하며, 프로시저가 끝나면 결과를 속성에 다시 씁니다 (VB.NET과 같음).
- **오류로 끝나면 되돌려 쓰지 않음.** 프로시저가 오류로 끝나면 속성에 값을 되돌려 쓰지 **않습니다.** 실패한 작업의 중간 값이 남지 않게 하기 위해서입니다 (D22).

## 8. 이벤트

- 처리기는 `컨트롤이름_이벤트이름` 형식의 `Sub`입니다: `btnSave_Click`, `txtName_Changed`. 폼 자신의 이벤트는 폼 이름과 상관없이 `Form`을 씁니다: `Form_Load`. 대소문자는 가리지 않습니다.
- 그 컨트롤(또는 `Form`)에 그 이름의 이벤트가 있을 때만 처리기입니다. `btnSave_Clicked`는 보통 프로시저입니다. 처리기는 이벤트의 매개변수와 똑같은 매개변수를 가진 `Sub`여야 합니다(11.1절의 이벤트에는 매개변수가 없습니다). 그렇지 않으면 실행되지 않는 보통 프로시저로 조용히 넘기지 않고 알립니다(A032).
- 디자이너에서 컨트롤을 더블클릭하면 기본 이벤트의 처리기가 생깁니다.
- 컨트롤 이름을 바꾸면 처리기 이름도 바뀝니다.
- 2단계: `Handles`로 프로시저 하나가 여러 이벤트를 처리할 수 있습니다.

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

### 8.1 처리기가 실행되는 순서

폼이 있는 프로그램은 **한 번에 처리기 하나만** 실행합니다(D28).

- **실행 중인 처리기는 자기 이벤트로 다시 시작되지 않습니다.** `btnSave_Click`이 실행되는 동안 `btnSave`를 다시 클릭하면 무시되며, 나중에 실행되도록 쌓이지도 않습니다(D5).
- **다른 처리기는 차례를 기다립니다.** 실행 중인 처리기가 끝나거나 `DoEvents`에서 기다리는 동안 시작됩니다. 그 사이에 들어온 이벤트는 들어온 순서대로 실행됩니다.
- **처리기 중간에 다른 처리기가 실행될 수 있는 곳은 `DoEvents`뿐입니다.** 긴 반복 중에도 화면은 갱신되고 중지 버튼도 동작하지만, 반복이 `DoEvents`를 부르거나 끝날 때까지 다른 처리기는 실행되지 않습니다.
- **`MsgBox`와 `InputBox`는 모달입니다.** 떠 있는 동안에는 폼의 컨트롤을 쓸 수 없고, 다른 것은 실행되지 않으며, 폼을 닫을 수도 없습니다. 그 사이의 이벤트는 쌓이지 않고 버려집니다. Visual Basic .NET의 `MsgBox`도 기본으로 그렇습니다. `Buttons`를 생략하면 0, 곧 `ApplicationModal`이며, "the user must respond to the message box before continuing work in the current application"이라고 설명되어 있습니다([Interaction.MsgBox](https://learn.microsoft.com/en-us/dotnet/api/microsoft.visualbasic.interaction.msgbox)).
- **폼 변수는 모두가 함께 씁니다.** `DoEvents`에서 기다리던 처리기는 다시 이어질 때 그동안 다른 처리기가 넣은 값을 봅니다. 지역 변수는 처리기마다 따로입니다.
- **`Static`은 프로시저에 속합니다.** 어느 처리기에서 부르든 한 프로시저의 호출은 모두 그 프로시저의 `Static` 변수 하나를 씁니다. 두 처리기가 각자 같은 이름의 `Static`을 선언하면 서로 다른 변수입니다.
- **`End`는 프로그램 전체를 끝냅니다.** `DoEvents`에서 기다리던 처리기는 이어지지 않고, 열린 대화상자는 닫힙니다. 아무도 잡지 않은 오류도 마찬가지입니다(9절).

```vb
Dim done As Boolean

Sub btnStart_Click()
    done = False
    Do While Not done
        DoEvents          ' 여기서 btnStop_Click이 실행될 수 있습니다
    Loop
    lblStatus.Caption = "멈춤"
End Sub

Sub btnStop_Click()
    done = True
End Sub
```

## 9. 오류 처리

```vb
Try
    Dim text = File.ReadAll("data.txt")
    lblInfo.Caption = Len(text) & "글자"
Catch ex As Exception
    MsgBox("파일을 열 수 없습니다: " & ex.Message)
Finally
    lblStatus.Caption = "완료"
End Try
```

- `Throw New Exception("메시지")`로 오류를 일으킵니다.
- `On Error GoTo`와 `On Error Resume Next`는 **지원하지 않습니다.**
- 처리되지 않은 오류가 나면 프로그램이 멈추고, IDE가 해당 줄을 강조하며 쉬운 말로 설명합니다.
- **실행 중 오류(R 코드)도 던진 예외처럼 `Try`로 잡을 수 있습니다.** `ex.Message`에는 오류 설명이 프로그램을 시작할 때 고른 언어로 들어 있습니다. 아무도 잡지 않은 예외는 R008로 프로그램을 멈춥니다.

### 9.1 프로그램 실행

- 폼이 없는 코드는 `Sub Main()`에서, `Main`이 없으면 `Sub Form_Load()`에서 시작하고, 그 프로시저가 끝나면 끝납니다. 폼 변수의 초깃값을 먼저 계산합니다.
- 폼이 있는 프로그램은 폼으로 시작합니다: 폼 변수의 초깃값을 계산하고, `Form_Load`를 실행한 뒤, 폼을 보여 주고 이벤트를 기다립니다(8.1절). 이때 `Sub Main`은 보통 프로시저입니다. 프로그램은 폼을 닫거나, `End`를 실행하거나, 오류를 잡지 않았거나, 중지 버튼을 누르면 끝납니다.
- 오류가 있는 프로그램은 실행되지 않고, 경고만 있으면 실행됩니다(D23).
- 호출은 10,000단계까지 이어질 수 있고, 그보다 깊으면 R009입니다. 이 제한은 모든 플랫폼에서 같습니다. 끝나지 않는 재귀를 1초도 안 돼 잡아내며, 인터프리터 자체는 VM과 Chrome에서 100만 단계 넘게도 안전한 것을 측정으로 확인했습니다.
- 프로그램이 도는 동안 인터프리터는 반복 1,000번이나 호출 1,000번마다 화면이 갱신될 틈을 주어 중지 버튼이 동작하게 합니다. 이는 프로그램이 계산하는 결과를 바꾸지 않으며 다른 처리기를 실행하지도 않습니다. `DoEvents`는 요청할 때 화면을 갱신하고, 다른 처리기도 실행되게 합니다(8.1절).

## 10. 내장 함수 (첫 묶음)

문자열 함수는 고전 BASIC처럼 **1부터 셉니다.** 문자열 *메서드*(`.Substring`, `.IndexOf`)는 VB.NET처럼 0부터 셉니다.

| 분류 | 함수 |
|---|---|
| 문자열 | `Len`, `Left`, `Right`, `Mid`, `InStr`, `UCase`, `LCase`, `Trim`, `Replace`, `Split`, `Join` |
| 변환 | `CInt`, `CDbl`, `CStr`, `CBool`, `Val`, `Str` |
| 수학 | `Abs`, `Int`, `Round`, `Sqr`, `Rnd`, `Randomize`, `Min`, `Max`. 상수 `Integer.MaxValue`, `Integer.MinValue` |
| 날짜 | `Now`, `Today`, `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second` |
| 대화상자 | `MsgBox`, `InputBox` |
| 개발자용 출력 | `Debug.Print(값)`: 놀이터의 직접 실행 창(VB6의 직접 실행 창)에 한 줄 씀 |
| 프로그램 | `DoEvents`, `End` |
| 설정 | `SaveSetting(key, value)`, `GetSetting(key, default)` |

- `Debug.Print`도 인수가 있는 다른 호출처럼 괄호가 필요합니다. `Debug.Print "x"`가 아니라 `Debug.Print("x")`로 씁니다(P011).
- `CInt`, `Round`, `Int`는 2.1절처럼 반올림하고, `Int`는 `Integer`를 돌려줍니다.
- `Mid(text, start[, length])`, `Left`, `Right`: 시작 위치가 1보다 작거나 길이가 음수이면 R007입니다. 길이가 끝을 넘으면 있는 만큼만 가져옵니다. `InStr`은 못 찾으면 0입니다.
- `CInt(문자열)`은 정수는 정확히(2⁵³을 넘어도) 읽고, 그 밖의 수는 `Double`을 거쳐 2.1절처럼 반올림합니다. `CBool`은 숫자(0은 `False`)와 대소문자에 상관없는 문자열 `True` / `False`를 받습니다. `Val`은 문자열 맨 앞의 수를 읽고, 없으면 0입니다. `Str`은 수의 글자 모양이며 앞에 공백을 붙이지 않습니다.
- `Round(x, 자릿수)`: 자릿수는 0부터 15까지입니다. `x`의 가장 짧은 소수 표기를 기준으로 0에서 먼 쪽으로 반올림하므로, `Round(2.675, 2)`는 쓴 그대로 2.68입니다.
- `Rnd()`는 0 이상 1 미만의 `Double`을 돌려주며 모든 플랫폼에서 같습니다. 64비트 상태는 프로그램이 시작할 때 0이고, `Randomize(seed)`는 상태를 `seed`로 정하며, 시드 없는 `Randomize`는 현재 시각을 씁니다. `Rnd()`는 매번 64비트 넘침 무시 연산과 부호 없는 오른쪽 이동(`>>>`)으로 다음을 계산합니다(SplitMix64).

  ```
  state = state + 0x9E3779B97F4A7C15
  z = state
  z = (z Xor (z >>> 30)) * 0xBF58476D1CE4E5B9
  z = (z Xor (z >>> 27)) * 0x94D049BB133111EB
  z = z Xor (z >>> 31)
  Rnd = (z >>> 11) / 2^53
  ```

- `Now`와 `Today`는 기기의 현지 시각을 씁니다.
- **`SaveSetting(key, value)`와 `GetSetting(key, default)`**는 프로그램을 다시 실행해도 남는 글자를 저장합니다. `GetSetting`은 `key`로 저장된 값을, 저장된 것이 없으면 `default`를 돌려줍니다. 키는 대소문자를 가리지 않으며(`best`와 `Best`는 같은 키), 빈 키는 R007입니다. 값은 글자입니다. 숫자는 글자로 저장되므로(2.2절) 읽을 때 바꿔 줍니다: `CInt(GetSetting("best", "0"))`.
- **설정은 프로젝트마다 따로이며, 프로젝트 이름으로 나뉩니다**(`.gbproj`의 `name`, 11.3절). 이름이 같은 두 프로젝트는 설정을 함께 쓰고, 새 이름으로 저장한 프로젝트는 설정 없이 시작합니다. 설정은 프로젝트의 파일이나 `.zip`에 들어가지 않습니다. IDE의 **파일 → 저장된 설정 지우기**는 열린 프로젝트의 설정을 지웁니다. 프로젝트가 없는 놀이터는 모든 프로그램이 설정 하나를 함께 씁니다.
- 프로그램 하나의 설정은 모두 합쳐 65536자까지입니다(R011). 웹 IDE가 프로젝트를 보관하는 브라우저 저장 공간을 프로그램이 채우지 못하게 하려는 것입니다. 설정은 평문으로 저장되므로 비밀번호는 넣지 마세요(DESIGN.md D48).

## 11. 폼과 컨트롤

```vb
Sub Form_Load()
    Me.Caption = "점수 기록장"
    lblTitle.Caption = "환영합니다"
End Sub

Sub btnNext_Click()
    Form2.Show
End Sub
```

- `Me`는 현재 폼을 가리키며, 속성은 `Form`의 속성입니다(11.1절).
- 컨트롤은 폼 파일(11.2절)에 있는 것들입니다. 컨트롤 이름은 폼 변수처럼 그 폼의 코드 어디서나 쓸 수 있습니다. 폼 변수나 프로시저에는 컨트롤의 이름을 쓸 수 없습니다(A030). 지역 변수에는 쓸 수 있지만 그러면 컨트롤을 가립니다(경고 A031).
- **컨트롤이 겹치면** 폼 파일의 순서와 상관없이 `Label`은 언제나 다른 컨트롤(`Button`, `TextBox`, `CheckBox`, `ListBox`) 아래에 있고, 클릭은 위에 있는 컨트롤이 받습니다. 같은 층의 컨트롤끼리는 폼 파일에서 뒤에 있는 것이 위에 있습니다(DESIGN.md D41).
- 놀이터의 프로그램처럼 폼이 없는 코드에서는 컨트롤과 `Me`를 쓸 수 없습니다(A003).
- 2단계: 실행 중에 컨트롤을 만들 수 있습니다.

  ```vb
  Dim b As New Button
  b.Caption = "새 버튼"
  Me.Controls.Add(b)
  ```

### 11.1 기본 컨트롤

| 컨트롤 | 속성 | 이벤트 |
|---|---|---|
| `Form` | `Caption` (`String`), `Width`, `Height` (`Integer`) | `Load` |
| `Button` | `Caption` (`String`), `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `Label` | `Caption` (`String`), `Left`, `Top`, `Width`, `Height` (`Integer`) | `Click` |
| `TextBox` | `Text` (`String`), `Left`, `Top`, `Width`, `Height` (`Integer`) | `Changed` |
| `CheckBox` | `Caption` (`String`), `Checked` (`Boolean`), `Left`, `Top`, `Width`, `Height` (`Integer`) | `Changed` |
| `ListBox` | `ListIndex` (`Integer`, 코드에서만 정함), `ListCount` (`Integer`)와 `Text` (`String`)는 읽기만 함, `Left`, `Top`, `Width`, `Height` (`Integer`). 메서드: `AddItem(item)`, `RemoveItem(index)`, `Clear()`, `List(index)` | `Changed` |

- 컨트롤은 모두 컴포넌트이며, 기본값과 함께 `components/이름/component.yaml`에 정의되어 있습니다(DESIGN.ko.md 5절). 위 표의 이벤트는 기본 이벤트, 곧 디자이너에서 더블클릭하면 만들어지는 이벤트를 먼저 적었습니다.
- `Left`, `Top`, `Width`, `Height`는 논리 픽셀(화면 밀도가 달라도 같은 크기) 단위이며, 폼 안쪽의 왼쪽 위 모서리부터 잽니다. 폼의 `Width`와 `Height`는 창의 제목 표시줄과 테두리를 뺀 안쪽 크기입니다. 나중 단계에서는 이 속성들의 뜻을 바꾸지 않고 속성(`Anchor` 등)을 더합니다(D12).
- `Integer` 속성은 32비트입니다: −2147483648부터 2147483647까지이며 모든 플랫폼에서 같습니다. `Width`와 `Height`는 음수가 될 수 없습니다. 범위를 벗어난 값은 프로그램이 넣을 때 실행 중 오류(R010), 폼 파일에서는 F012입니다.
- **`TextBox.Changed`**는 `Text`가 바뀐 뒤에 실행됩니다. 사용자가 입력했든 프로그램이 `Text`를 바꿨든 같습니다. 프로그램이 `Text`를 바꾸면 처리기는 그 대입의 일부로 바로 실행되므로, 다음 줄에서 이미 처리기가 한 일을 볼 수 있습니다. 같은 글자를 다시 넣으면 실행되지 않습니다. 처리기가 자기 TextBox의 `Text`를 바꿔도 그 변화로 처리기가 다시 시작되지는 않습니다(8.1절).
- **입력기(IME)로 입력할 때.** `Text`에는 입력기가 **확정한** 글자만 들어 있고, `Changed`는 입력기가 글자를 확정할 때마다 실행됩니다. 화면에 보이는 글자가 아직 확정되지 않았을 수 있습니다. 한글은 받침이 다음 글자로 넘어갈 수 있기 때문입니다(도깨비불). 갈가를 입력하면 갈, 갉, 갈가 순서로 보이는데, 갈은 ㅏ를 칠 때 비로소 확정되고 ㄱ은 다음 글자로 넘어갑니다. 그래서 처리기가 음절 중간에 글자를 바꾸는 일이 없습니다. 음절 중간에 글자를 바꾸면 Windows의 Flutter에서 입력이 깨지는 문제가 알려져 있습니다([flutter/flutter#121376](https://github.com/flutter/flutter/issues/121376)). 대가: 글자 수 세기처럼 키를 누를 때마다 따라가는 코드는 입력 중인 음절을 입력기가 확정한 뒤에야 봅니다. 어느 글자가 아직 조합 중인지 플랫폼이 알려 주지 않는 곳(macOS 앱, D37)에서는 runtime이 글자가 바뀌는 모양으로 알아내며, 결과는 같습니다.
- **`CheckBox.Changed`**는 `Checked`가 바뀐 뒤에 실행됩니다. 사용자가 상자나 `Caption`을 클릭했을 때, 그리고 프로그램이 `Checked`를 바꿨을 때입니다. `TextBox.Changed`와 같이, 프로그램이 바꾸면 처리기가 바로 실행되고, 같은 값을 다시 넣으면 실행되지 않으며, 처리기가 자기 `Checked`를 바꿔도 그 변화로 다시 시작되지 않습니다. CheckBox의 `Changed`가 실행 중일 때 그 CheckBox를 클릭하면 무시되고 상자도 그대로이므로, 상자는 처리기가 다루는 상태를 보여 줍니다(8.1절). CheckBox의 상태는 두 가지이며, Visual Basic 6의 세 번째 상태(회색)는 넣지 않았습니다(DESIGN.md D44).
- **ListBox의 항목**은 코드에서 넣으며 번호는 0부터입니다. `AddItem(item)`은 끝에 하나를 넣고, `RemoveItem(index)`는 하나를 지우고, `Clear()`는 모두 지우며, `List(index)`는 한 항목의 글자를 돌려줍니다. `ListCount`는 항목 수, `ListIndex`는 고른 항목의 번호(고른 것이 없으면 −1), `Text`는 고른 항목의 글자(고른 것이 없으면 `""`)입니다. `ListCount`와 `Text`는 읽기만 할 수 있습니다(A034). `ListIndex`는 폼 파일이 아니라 코드에서만 정합니다(F013). 없는 항목 번호는 실행 중 오류(R003)이고, `ListIndex = -1`은 아무것도 고르지 않습니다. 디자이너에서 항목을 넣는 기능은 아직 없습니다(DESIGN.md D46).
- **`ListBox.Changed`**는 `ListIndex`가 바뀔 때마다 실행됩니다. 사용자가 다른 항목을 고를 때, 프로그램이 `ListIndex`를 바꿀 때(`TextBox.Changed`처럼 그 대입의 일부로 바로), 그리고 `RemoveItem`이나 `Clear`가 고른 항목을 옮기거나 지울 때(그 호출의 일부로)입니다. 고른 항목보다 위의 항목을 지우면 고른 번호가 하나 당겨져 같은 항목이 계속 골라져 있고, 고른 항목을 지우거나 `Clear`하면 아무것도 고르지 않은 상태가 됩니다. 고른 항목을 다시 고르거나 같은 `ListIndex`를 넣으면 실행되지 않습니다. ListBox의 `Changed`가 실행 중일 때 그 ListBox에서 고르면 무시되고 아무것도 바뀌지 않습니다(8.1절).
- **글자를 조합하는 중에 클릭할 때.** 클릭이 프로그램에 전달되기 전에, 어느 TextBox에서든 아직 조합 중인 글자를 확정합니다. 순서는 항상 같습니다: 글자 확정, `TextBox.Changed` 실행, 그다음 `Click` 실행(CheckBox나 ListBox를 클릭했다면 그 컨트롤의 `Changed` 실행). 그래서 사용자가 한글을 스페이스 없이 치고 바로 버튼을 누르면, `Click` 처리기의 `txtName.Text`는 이미 한글입니다.

### 11.2 폼 파일

폼 `Form1`은 나란히 있는 파일 두 개입니다: `Form1.form.yaml`(폼과 컨트롤)과 `Form1.gbas`(코드). 폼 이름은 파일 이름에서 옵니다.

```yaml
formatVersion: 1
properties:
  Caption: Hello
  Width: 320
  Height: 120
controls:
  - name: lblMessage
    type: Label
    properties:
      Left: 16
      Top: 16
      Width: 288
  - name: btnHello
    type: Button
    properties:
      Caption: Say hello
      Left: 16
      Top: 56
      Width: 120
```

- 파일은 일반 텍스트가 되도록 YAML로 씁니다(D13). 디자이너가 쓰지만 손으로 고칠 수도 있으며, 실수는 F 코드로 알립니다(1.2절).
- `formatVersion`은 이 형식의 버전이며 지금은 1입니다. 더 새로운 버전의 파일은 읽지 않아서(F003) 예전 GuBASIC이 파일을 잘못 읽는 일이 없습니다. 예전 파일을 다르게 읽게 되는 변경에는 새 버전과 변환기를 둡니다(D12).
- `properties`에는 기본값과 다른 값만 적습니다. 키와 속성 이름은 대소문자를 가리지 않습니다.
- 컨트롤마다 `name`과 `type`, 필요하면 `properties`가 있습니다. 이름은 식별자 규칙(1절)을 따릅니다: 영문자로 시작하고 영문자, 숫자, `_`를 씁니다. 키워드나 `Form`은 쓸 수 없고, 대소문자만 다른 같은 이름의 컨트롤 둘도 둘 수 없습니다.
- `String` 속성은 적힌 그대로 값이 됩니다: `Caption: 2026`은 글자 `2026`입니다. 따옴표, `-`, `[`, `{`로 시작하거나 `: `, ` #`가 들어 있어서 YAML이 다르게 읽을 글자는 따옴표로 감싸 주세요.
- IDE는 폼 파일을 늘 같은 방식으로 씁니다(D31): 속성은 그 컴포넌트의 `component.yaml` 순서대로, 기본값과 다른 값만, 따옴표는 YAML이 다르게 읽을 글자에만 씁니다(`Caption: "2026"`). 바뀌지 않은 폼을 저장하면 같은 파일이 나오고, Git에는 바뀐 줄만 보입니다. 손으로 쓴 파일의 주석과 줄 배치는 IDE가 저장할 때 남지 않습니다.

### 11.3 프로젝트 파일

프로젝트는 `.gbproj` 파일과 그 옆의 폼들입니다:

```yaml
formatVersion: 1
name: Hello
startup: Form1
forms:
  - Form1
```

- `forms`에는 폼을 적습니다. 폼마다 11.2절의 파일 두 개가 있습니다. 폼은 하나 이상 있어야 합니다.
- `startup`은 프로그램이 시작하는 폼입니다. 없으면 `forms`의 첫 폼입니다.
- [examples/hello](../examples/hello)는 README 예제를 프로젝트로 만든 것입니다.

## 12. 열린 질문

- 파일 확장자 (`.gbas`는 임시).
- 사용자 정의 클래스 (`Class … End Class`) — 1.0에는 없음.
- Dart 코드 삽입(비상구)의 정확한 문법.
