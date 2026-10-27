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

  test('usesOfControl: the lines that use the control, and its handlers', () {
    const code = 'Sub btnOk_Click()\n'
        '    btnOk.Caption = "OK"\n'
        "    ' btnOk in a comment\n"
        '    lblNote.btnOk = 1\n'
        '    Me.btnOk.Left = 3\n'
        '    Dim btnOkay As Integer\n'
        'End Sub\n'
        'Sub BTNOK_Changed()\n'
        'End Sub\n';
    final uses = usesOfControl(code, 'btnOk');
    expect(uses.lines, [2, 5]);
    expect(uses.handlers, ['btnOk_Click', 'BTNOK_Changed']);
    final none = usesOfControl(code, 'lblOther');
    expect(none.lines, isEmpty);
    expect(none.handlers, isEmpty);
  });

  group('forms (D88)', () {
    const source = 'Sub btnGo_Click()\n'
        '    FORM2.Show\n'
        '    Debug.Print("Form2") \' Form2\n'
        '    lblX.Form2 = Form2.txtName.Text\n'
        '    Form_Load\n'
        'End Sub\n';

    test('formUses finds the form named, not strings, comments or members', () {
      expect(formUses(source, 'Form2'), [2, 4]);
      expect(formUses(source, 'Form3'), isEmpty);
    });

    test('renameFormInCode renames those uses only', () {
      expect(
          renameFormInCode(source, 'form2', 'Settings'),
          'Sub btnGo_Click()\n'
          '    Settings.Show\n'
          '    Debug.Print("Form2") \' Form2\n'
          '    lblX.Form2 = Settings.txtName.Text\n'
          '    Form_Load\n'
          'End Sub\n');
    });
  });
}
