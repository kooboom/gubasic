import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

void main() {
  test('usable names', () {
    for (final ok in ['Button1', 'lblTitle', 'a_b2']) {
      expect(isUsableName(ok), isTrue, reason: ok);
    }
    for (final bad in [
      '',
      '1abc',
      '_x',
      'If',
      'dim',
      'Form',
      'FORM',
      '점수',
      'a b',
      'a-b'
    ]) {
      expect(isUsableName(bad), isFalse, reason: bad);
    }
  });

  group('linesUsingName', () {
    const source = '''Dim clickCount As Integer

Sub Form_Load()
    lblMessage.Caption = "Press the button"
End Sub

' btnHello in a comment does not count
Sub BTNHELLO_Click()
    clickCount = clickCount + 1
    Me.btnHello.Caption = "btnHello in a string does not count"
End Sub
''';

    test('uses and handlers, in any case', () {
      expect(linesUsingName(source, 'btnHello'), [8, 10]);
      expect(linesUsingName(source, 'lblMessage'), [4]);
      expect(linesUsingName(source, 'clickcount'), [1, 9]);
    });

    test('comments, strings and other names do not count', () {
      expect(linesUsingName(source, 'Button1'), isEmpty);
      expect(linesUsingName(source, 'btn'), isEmpty, reason: 'not btn_');
      expect(linesUsingName(source, 'Press'), isEmpty);
    });

    test('code that does not parse still counts its names', () {
      expect(linesUsingName('Sub x(\n  Label1.Caption = \n', 'label1'), [2]);
    });
  });
}
