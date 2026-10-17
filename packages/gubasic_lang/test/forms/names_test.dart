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

  group('renameInCode', () {
    const source = '''Dim btnHelloWorld As Integer

Sub Form_Load()
    ' btnHello says hello
    btnHello.Caption = "btnHello"
    Me.BTNHELLO.Caption = lblMessage.btnHello
End Sub

Sub btnHello_Click()
    btnHelloWorld = btnHelloWorld + 1
End Sub
''';

    test('renames the uses and the handlers, nothing else', () {
      expect(renameInCode(source, 'btnHello', 'btnOk'),
          '''Dim btnHelloWorld As Integer

Sub Form_Load()
    ' btnHello says hello
    btnOk.Caption = "btnHello"
    Me.btnOk.Caption = lblMessage.btnHello
End Sub

Sub btnOk_Click()
    btnHelloWorld = btnHelloWorld + 1
End Sub
''');
    });

    test('renaming back gives the code again, in any case', () {
      final renamed = renameInCode(source, 'btnHello', 'btnOk');
      expect(linesUsingName(source, 'btnOk'), isEmpty);
      expect(
        renameInCode(renamed, 'btnOk', 'btnHello'),
        equalsIgnoringCase(source),
      );
    });

    test('a name with no uses leaves the code as it is', () {
      expect(renameInCode(source, 'Button1', 'Button2'), source);
      expect(renameInCode('', 'a', 'b'), '');
    });

    test('code that does not parse is renamed too', () {
      expect(
        renameInCode('Sub x(\n  Label1.Caption = \n', 'label1', 'lblName'),
        'Sub x(\n  lblName.Caption = \n',
      );
    });
  });
}
