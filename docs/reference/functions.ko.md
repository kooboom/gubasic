# 함수

[참조 전체](README.ko.md)

## Text

- `Len(text As String) As Integer`: 글의 글자 수.
- `Left(text As String, length As Integer) As String`: 글의 앞에서 length 글자.
- `Right(text As String, length As Integer) As String`: 글의 뒤에서 length 글자.
- `Mid(text As String, start As Integer, [length As Integer]) As String`: start(1부터 셈)부터 length 글자, 없으면 끝까지.
- `InStr(text As String, find As String) As Integer`: find가 처음 나오는 자리(1부터 셈), 없으면 0.
- `UCase(text As String) As String`: 대문자로 바꾼 글.
- `LCase(text As String) As String`: 소문자로 바꾼 글.
- `Trim(text As String) As String`: 앞뒤 공백을 뺀 글.
- `Replace(text As String, find As String, with As String) As String`: find를 모두 with로 바꾼 글.
- `Split(text As String, separator As String) As String()`: separator마다 자른 글의 배열.
- `Join(items As String(), separator As String) As String`: 배열의 항목을 separator로 이은 글.

## Conversion

- `CInt(value As number or String) As Integer`: 정수로 바꾼 값(0.5는 0에서 먼 쪽으로). 글은 숫자로 읽음.
- `CDbl(value As number or String) As Double`: 실수로 바꾼 값. 글은 숫자로 읽음.
- `CStr(value As any value) As String`: 글로 바꾼 값.
- `CBool(value As number, Boolean or String) As Boolean`: Boolean으로 바꾼 값.
- `Val(text As String) As Double`: 글 앞부분의 숫자, 없으면 0.
- `Str(value As Integer or Double) As String`: 숫자를 글로.

## Math

- `Abs(value As Integer or Double) As Double`: 부호를 뺀 크기.
- `Int(value As Double) As Integer`: value보다 크지 않은 가장 큰 정수.
- `Round(value As Double, [digits As Integer]) As Double`: digits 자리(없으면 0)로 반올림한 값. 0.5는 0에서 먼 쪽으로.
- `Sqr(value As Double) As Double`: 제곱근.
- `Rnd() As Double`: 0 이상 1 미만의 난수.
- `Randomize([seed As Integer])`: 난수를 다시 시작함. seed를 주면 그 값에서.
- `Min(a As Integer or Double, b As Integer or Double) As Double`: 두 수 가운데 작은 것.
- `Max(a As Integer or Double, b As Integer or Double) As Double`: 두 수 가운데 큰 것.

## Arrays

- `UBound(items As array) As Integer`: 배열의 가장 큰 번호.

## Date and time

- `Now() As Date`: 이 기기의 지금 날짜와 시각.
- `Today() As Date`: 오늘 날짜(자정).
- `Milliseconds() As Integer`: 프로그램이 시작한 뒤 흐른 밀리초. 앞으로만 가는 시계(게임 루프용).
- `Year(date As Date) As Integer`: 날짜의 연.
- `Month(date As Date) As Integer`: 날짜의 월(1~12).
- `Day(date As Date) As Integer`: 날짜의 일.
- `Hour(date As Date) As Integer`: 날짜의 시(0~23).
- `Minute(date As Date) As Integer`: 날짜의 분.
- `Second(date As Date) As Integer`: 날짜의 초.
- `DateAdd(interval As String, number As Integer, date As Date) As Date`: date에 구간을 number만큼 더한 날짜: "yyyy", "q", "m", "d", "ww", "h", "n", "s" 또는 DateInterval.
- `DateDiff(interval As String, date1 As Date, date2 As Date) As Integer`: date1부터 date2까지 몇 구간인지.
- `Format(value As any value, format As String) As String`: .NET 서식 문자열로 쓴 날짜나 숫자: 사용자 지정("yyyy-MM-dd", "#,##0") 또는 표준("d", "N2", "C").

## Dialogs

- `MsgBox(prompt As String, [title As String])`: 메시지를 보이고 확인을 기다림.
- `InputBox(prompt As String, [title As String], [default As String]) As String`: 글 한 줄을 물음. 취소하면 "".

## Program

- `DoEvents()`: 화면을 그리고 다른 이벤트를 돌게 한 뒤 이어서 감.

## Settings

- `SaveSetting(key As String, value As String)`: 이 앱의 key에 값을 보관함.
- `GetSetting(key As String, default As String) As String`: key에 보관한 값, 없으면 default.
