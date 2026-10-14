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
| 숫자 | 정수(`123`)와 실수(`1.5`). 실수는 점 **양쪽**에 숫자가 있어야 합니다. `.5`와 `1.`은 숫자가 아닙니다(`0.5`, `1.0`으로 씁니다). 지수 표기(`1e5`)는 지원하지 않습니다. 빼기 기호는 숫자의 일부가 아니라 연산자입니다. |
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

렉서와 파서는 오류를 만나도 멈추지 않습니다. 오류를 알리고 계속 읽어서, 실수 하나가 나머지를 가리지 않게 합니다. 코드는 바뀌지 않으며 다시 쓰지 않습니다.

아래 표에서 **경고**라고 표시한 것 말고는 모두 **오류**입니다. 오류는 고쳐야 합니다. 경고는 동작은 하지만 뜻밖일 수 있는 것을 알려 주며, **프로그램의 실행이나 빌드를 막지 않습니다**(D23). 코드의 접두사는 심각도가 아니라 누가 알리는지(L 렉서, P 파서)를 나타냅니다.

**렉서**

| 코드 | 문제 | 렉서의 처리 |
|---|---|---|
| L001 | 문자열이 그 줄에서 `"`로 닫히지 않음 | 줄의 나머지를 오류 토큰 하나로 만들고, 다음 줄은 정상으로 읽음 |
| L002 | 문자열·주석 밖의 비ASCII 문자(한글 등) | 단어 전체를 식별자로 읽어서 문장 검사를 계속할 수 있게 함 |
| L003 | `:`로 한 줄에 여러 문장을 씀 | 문장의 끝으로 처리 |
| L004 | GuBASIC에서 의미가 없는 문자(`@`, `#`, `$` 등) | 오류 토큰 |
| L005 | 줄의 맨 끝이 아닌 곳의 `_` | 오류 토큰 |
| L006 | `Integer`(64비트)에 담기지 않는 큰 정수 | 값이 없는 정수 토큰 |
| L007 | **경고.** 웹이 정확히 담을 수 없는 9007199254740991(2⁵³−1)보다 큰 정수 | 보통의 정수 토큰. 숫자 문자열로 판단하므로 모든 플랫폼에서 똑같이 알림 |

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

- **`Integer`는 네이티브 플랫폼에서 64비트**입니다. 웹에서는 자바스크립트 숫자라서 2⁵³(약 9천조)까지만 정확합니다. 일반 앱은 이 범위에 닿지 않습니다. 정수 리터럴의 원문은 언제나 그대로 보존되고 트랜스파일러도 쓴 그대로 옮기므로, 네이티브 앱에서는 2⁵³을 넘는 수도 정확합니다. 2⁵³−1보다 큰 리터럴에는 모든 플랫폼에서 경고 L007이 나옵니다. 계산에 쓰지 않는 번호(주문 번호, 회원 ID 등)는 `String`으로 담으면 앞자리 0도 그대로 남습니다.
- **`Nothing`(null)은 객체에만 있습니다.** 값 타입은 항상 값이 있으므로 초보자가 null 오류를 만날 일이 거의 없습니다.
- **객체가 `Nothing`인지는 `Is`로 비교합니다:** `If player Is Nothing Then`. 반대는 `If Not player Is Nothing Then`으로 씁니다. (`=`는 객체가 아니라 값을 비교합니다.)
- **`Variant`는 없습니다.** 정말 아무 값이나 담아야 하면 `Object`를 씁니다.

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
- **반복 변수에 타입을 붙일 수 있습니다:** `For i As Integer = 1 To 10`, `For Each name As String In names`. 선언하지 않은 반복 변수를 자동으로 선언할지는 분석기 단계에서 정합니다(12절).

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

- 처리기는 `컨트롤이름_이벤트이름` 형식의 `Sub`입니다: `btnSave_Click`, `txtName_Changed`, `Form_Load`.
- 디자이너에서 컨트롤을 더블클릭하면 기본 이벤트의 처리기가 생깁니다.
- 컨트롤 이름을 바꾸면 처리기 이름도 바뀝니다.
- 2단계: `Handles`로 프로시저 하나가 여러 이벤트를 처리할 수 있습니다.

  ```vb
  Sub SaveData() Handles btnSave.Click, mnuSave.Click
  ```

- 처리기가 아직 실행 중이면(예: `MsgBox`나 `Http.Get`을 기다리는 중) 같은 이벤트로 다시 시작되지 않습니다.

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

## 10. 내장 함수 (첫 묶음)

문자열 함수는 고전 BASIC처럼 **1부터 셉니다.** 문자열 *메서드*(`.Substring`, `.IndexOf`)는 VB.NET처럼 0부터 셉니다.

| 분류 | 함수 |
|---|---|
| 문자열 | `Len`, `Left`, `Right`, `Mid`, `InStr`, `UCase`, `LCase`, `Trim`, `Replace`, `Split`, `Join` |
| 변환 | `CInt`, `CDbl`, `CStr`, `CBool`, `Val`, `Str` |
| 수학 | `Abs`, `Int`, `Round`, `Sqr`, `Rnd`, `Randomize`, `Min`, `Max` |
| 날짜 | `Now`, `Today`, `Year`, `Month`, `Day`, `Hour`, `Minute`, `Second` |
| 대화상자 | `MsgBox`, `InputBox` |
| 프로그램 | `DoEvents`, `End` |
| 설정 | `SaveSetting(key, value)`, `GetSetting(key, default)` |

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

- `Me`는 현재 폼을 가리킵니다.
- 2단계: 실행 중에 컨트롤을 만들 수 있습니다.

  ```vb
  Dim b As New Button
  b.Caption = "새 버튼"
  Me.Controls.Add(b)
  ```

## 12. 열린 질문

- 파일 확장자 (`.gbas`는 임시).
- 선언하지 않은 반복 변수 (6절). **추천안:** `For`나 `For Each`의 변수가 선언되어 있지 않으면, 그 반복문 안에서만 쓰는 변수로 자동 선언한다 (VB.NET의 `Option Infer`와 같은 방식). 분석기 단계에서 확정.
- 사용자 정의 클래스 (`Class … End Class`) — 1.0에는 없음.
- Dart 코드 삽입(비상구)의 정확한 문법.
