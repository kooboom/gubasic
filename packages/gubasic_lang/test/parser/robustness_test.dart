import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Building blocks for random programs: real statements, their pieces,
/// and things that break parsers.
const _pieces = [
  'Sub A()',
  'Function F(x As Integer) As Integer',
  'End Sub',
  'End Function',
  'If x Then',
  'ElseIf y Then',
  'Else',
  'End If',
  'If a Then b = 1 Else b = 2',
  'For i = 1 To 10 Step 2',
  'For Each n In names',
  'Next',
  'Next i',
  'Do While a',
  'Do',
  'Loop',
  'Loop Until b',
  'While c',
  'Wend',
  'Select Case d',
  'Case 1, 2',
  'Case Is > 3',
  'Case Else',
  'End Select',
  'Try',
  'Catch ex As Exception',
  'Finally',
  'End Try',
  'Dim a As Integer',
  'Dim b, c',
  'Const K = 1',
  'Static s As String',
  'x = 1 + 2 * 3',
  'MsgBox("hi")',
  'MsgBox "hi"',
  'Form2.Show',
  'Return x',
  'Exit For',
  'End',
  'ReDim Preserve a(9)',
  'Throw New Exception("e")',
  'On Error Resume Next',
  'GoTo L',
  'Call F()',
  'Set o = Nothing',
  'Class C',
  'End Class',
  'Public',
  'Private Sub',
  'Handles a.B',
  '(',
  ')',
  ',',
  '.',
  '=',
  'Not',
  'And',
  'AndAlso',
  'Is',
  '+',
  '-',
  '^',
  '"open',
  '점수',
  '@',
  ':',
  '_',
  '\n',
  '\n',
  '\n',
  ' ',
];

void main() {
  test('random programs never throw and produce a well-formed tree', () {
    final random = Random(20261015);
    for (var i = 0; i < 1000; i++) {
      final length = random.nextInt(30);
      final src = [
        for (var j = 0; j < length; j++)
          _pieces[random.nextInt(_pieces.length)] +
              (random.nextInt(3) == 0 ? '\n' : ' '),
      ].join();

      final ParseResult r;
      try {
        r = parse(src);
      } catch (e, s) {
        fail('parse threw $e\n$s\nsource:\n$src');
      }

      _checkSpans(r.unit, src);
      for (final d in r.diagnostics) {
        expect(d.offset, inInclusiveRange(0, src.length), reason: src);
        expect(d.offset + d.length, lessThanOrEqualTo(src.length));
        expect(d.message, isNot(contains('{')), reason: '$d');
        expect(d.formatMessage(koreanMessages), isNot(contains('{')));
      }
      // Printing must work on any tree.
      astToText(r.unit, lineMap: LineMap(src));
    }
  });
}

/// Every node lies inside the source and inside its parent; children come
/// in source order.
void _checkSpans(Node node, String src) {
  expect(node.start, lessThanOrEqualTo(node.end),
      reason: '${node.label}\n$src');
  expect(node.end, lessThanOrEqualTo(src.length));
  var previousEnd = node.start;
  for (final child in node.children) {
    expect(child.start, greaterThanOrEqualTo(node.start),
        reason: '${child.label} in ${node.label}\n$src');
    expect(child.end, lessThanOrEqualTo(node.end),
        reason: '${child.label} in ${node.label}\n$src');
    expect(child.start, greaterThanOrEqualTo(previousEnd),
        reason: 'order: ${child.label} in ${node.label}\n$src');
    previousEnd = child.end;
    _checkSpans(child, src);
  }
}
