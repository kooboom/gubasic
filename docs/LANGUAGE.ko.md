# GuBASIC 언어 (초안)

[English](LANGUAGE.md)

GuBASIC은 VB.NET을 단순화한 BASIC입니다. 이 문서는 **초안**입니다. 나중에 바꾸기 어려운 결정은 확정하고, 나머지는 열어 둡니다.

---

## 1. 어휘 규칙

| 규칙 | 결정 |
|---|---|
| 대소문자 | **구분하지 않습니다.** VB처럼 편집기가 모든 사용처를 선언할 때의 표기로 고쳐 줍니다. 트랜스파일러도 그 표기로 출력합니다. |
| 식별자 | **ASCII만:** 영문자로 시작하고, 뒤에는 영문자, 숫자, `_`. 한글(및 모든 비ASCII 문자)은 문자열과 주석에 쓸 수 있습니다. |
| 주석 | `'`부터 줄 끝까지. `REM`도 허용. |
| 줄 잇기 | `_`로 끝나는 줄은 다음 줄로 이어집니다. |
| 한 줄의 문장 수 | 하나. (`:` 구분은 지원하지 않습니다.) |
| 문자열 | `"..."`; 따옴표를 두 번 쓴 `""`는 따옴표 문자 하나. |
| Dart 예약어 | 식별자가 Dart 예약어(`var`, `class`, `is`, `new` 등)와 겹치면 트랜스파일러가 자동으로 이름을 바꿉니다. 사용자에게는 보이지 않습니다. |

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

- **`Integer`는 네이티브 플랫폼에서 64비트**입니다. 웹에서는 자바스크립트 숫자라서 2⁵³(약 9천조)까지만 정확합니다. 일반 앱은 이 범위에 닿지 않습니다.
- **`Nothing`(null)은 객체에만 있습니다.** 값 타입은 항상 값이 있으므로 초보자가 null 오류를 만날 일이 거의 없습니다.
- **`Variant`는 없습니다.** 정말 아무 값이나 담아야 하면 `Object`를 씁니다.

## 3. 변수

### 3.1 선언

```vb
Dim score As Integer          ' 타입 명시
Dim name = "Jekyll"           ' String으로 추론
Dim total As Integer = 100    ' 타입과 초깃값
```

**선언은 항상 필수입니다** (`Option Explicit`가 늘 켜져 있음). 선언하지 않은 이름을 쓰면 컴파일 오류가 납니다. 오타를 잡아 줍니다.

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
| 논리 | `Not`, `And`, `Or`, `Xor` |
| 대입 | `=` (문장으로 쓸 때) |

- **`And`와 `Or`는 단락 평가합니다.** `AndAlso` / `OrElse`는 없습니다.
- `&`는 숫자를 자동으로 문자열로 바꿉니다: `"점수: " & 90`.

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

## 7. 프로시저

```vb
Sub ShowScore(name As String, score As Integer)
    MsgBox(name & ": " & score)
End Sub

Function Average(a As Integer, b As Integer) As Double
    Return (a + b) / 2
End Function
```

- 호출할 때는 항상 괄호를 씁니다: `ShowScore("Kim", 90)`.
- 매개변수는 **값으로 전달**됩니다. `ByRef`는 2단계 예정입니다.
- 선택 매개변수: `Optional title As String = "안내"`.

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
- 비동기 프로시저 위에서 `ByRef`의 의미.
- 사용자 정의 클래스 (`Class … End Class`) — 1.0에는 없음.
- Dart 코드 삽입(비상구)의 정확한 문법.
