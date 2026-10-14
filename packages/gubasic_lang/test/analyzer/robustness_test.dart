import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Pieces of real and broken code, as in the parser's robustness test,
/// weighted towards things the analyzer looks at.
const _pieces = [
  'Sub A()',
  'Function F(x As Integer) As Integer',
  'End Sub',
  'End Function',
  'Dim a As Integer',
  'Dim s As String = "x"',
  'Dim l As New List(Of String)',
  'Dim arr(3) As Double',
  'Const K = 1',
  'Static c As Integer',
  'Dim q',
  'If a > 0 Then',
  'Else',
  'End If',
  'For i = 1 To 10',
  'For Each n In l',
  'Next',
  'Do While a < 3',
  'Loop',
  'Select Case a',
  'Case 1, 2',
  'Case Else',
  'End Select',
  'Try',
  'Catch ex As Exception',
  'End Try',
  'Return a + 1',
  'Return',
  'Exit For',
  'Exit Function',
  'a = a + 1',
  's = s & a',
  'F = 3',
  'K = 2',
  'x = F(2) + F',
  'l.Add(a)',
  'l(0) = s',
  'arr(1.5) = 2',
  'Debug.Print(a)',
  'MsgBox("hi")',
  'Dim y = InputBox("?")',
  'lbl.Text = s',
  'Me.Caption = 1',
  'ReDim Preserve arr(9)',
  'Throw New Exception("e")',
  'a = "1" + 1',
  'a = 2.5',
  'If a Then',
  'x = Not a',
  'x = s And True',
  'Dim t = Nothing',
  'Call F(1)',
  '(',
  ')',
  ',',
  '.',
  '=',
  '+',
  '"open',
  '점수',
  '\n',
  '\n',
  '\n',
  ' ',
];

void main() {
  test('random programs never make the analyzer throw', () {
    final random = Random(20261016);
    for (var i = 0; i < 1000; i++) {
      final length = random.nextInt(30);
      final src = [
        for (var j = 0; j < length; j++)
          _pieces[random.nextInt(_pieces.length)] +
              (random.nextInt(3) == 0 ? ' ' : '\n'),
      ].join();
      final CompileResult r;
      try {
        r = compile(src);
      } catch (e, s) {
        fail('compile threw $e\n$s\nsource:\n$src');
      }
      for (final d in r.diagnostics) {
        expect(d.offset, inInclusiveRange(0, src.length), reason: src);
        expect(d.offset + d.length, lessThanOrEqualTo(src.length));
        expect(d.message, isNot(contains('{')), reason: '$d');
        expect(d.formatMessage(koreanMessages), isNot(contains('{')));
      }
    }
  });
}
