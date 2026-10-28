import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// A project's forms see one another (docs/DESIGN.md D88): by name, with
/// their controls, Public variables and procedures that are not Private.
void main() {
  FormFile form(String name, String controls) => readFormFile(
        'formatVersion: 1\ncontrols:\n$controls',
        name: name,
      ).form;

  final form1 = form('Form1', '  - { name: lblResult, type: Label }\n');
  final form2 = form('Form2', '  - { name: txtName, type: TextBox }\n');

  const form2Code = '''
Public Score As Integer = 10
Public Const Most As Integer = 99
Dim hidden As Integer

Function Hello(name As String) As String
    Return "Hello, " & name
End Function

Sub Start()
End Sub

Private Sub Tidy()
End Sub
''';

  /// `code@line` of the diagnostics of [code] as Form1's, with Form2.
  List<String> diagnose(String code, {String other = form2Code}) {
    final project = compileProject([
      (file: form1, source: code),
      (file: form2, source: other),
    ]);
    return [
      for (final d in project.forms.first.program.diagnostics)
        '${d.code.code}@${d.line}',
    ];
  }

  String inSub(String body) =>
      diagnose('Sub Work()\n$body\nEnd Sub\n').join(' ');

  test(
      'another form is known by name, with its methods, controls, Public '
      'variables and procedures', () {
    expect(
        inSub('Form2.Show\nForm2.ShowDialog\nForm2.Hide\nForm2.Close()\n'
            'lblResult.Caption = Form2.txtName.Text & Form2.Score\n'
            'Form2.Score = Form2.Most\n'
            'lblResult.Caption = Form2.Hello("Kim")\n'
            'Form2.Start\nform2.START()\n'
            'Form2.Caption = "Hi"\nMe.Close\nForm1.Caption = "One"'),
        '');
  });

  test('its Dim variables and Private procedures are its own', () {
    expect(inSub('Debug.Print(Form2.hidden)'), 'A019@2');
    expect(inSub('Form2.Tidy'), 'A019@2');
  });

  test('a constant cannot be set, a Sub has no value', () {
    expect(inSub('Form2.Most = 1'), 'A034@2');
    expect(inSub('Debug.Print(Form2.Start)'), 'A017@2');
  });

  test('the types of its members are checked', () {
    expect(inSub('Form2.Score = "ten"'), contains('A009@2'));
    expect(inSub('Form2.Hello(1, 2)'), 'A015@2');
  });

  test('a form not in the project is not known', () {
    expect(inSub('Form3.Show'), 'A002@2'); // did you mean Form2
  });

  test("Visual Basic 6's statements and Show vbModal say what to write", () {
    expect(inSub('Unload Form2'), 'P024@2');
    expect(inSub('Unload Me'), 'P024@2');
    expect(inSub('Load Form2'), 'P025@2');
    expect(inSub('Form2.Show vbModal'), 'A039@2');
    expect(inSub('Form2.Show(1)'), 'A039@2');
  });

  test('Form_Closed handles the form closing', () {
    final project = compileProject([
      (file: form1, source: 'Sub Form_Closed()\nEnd Sub\n'),
      (file: form2, source: 'Sub Form_Closed(x As Integer)\nEnd Sub\n'),
    ]);
    expect(
        project.forms.first.program.analysis.handlers.values.single.single.event
            .name,
        'Closed');
    expect(project.forms.last.program.diagnostics.single.code.code, 'A032');
  });

  test('the startup form is the one named, or the first', () {
    final forms = <FormSource>[
      (file: form1, source: ''),
      (file: form2, source: ''),
    ];
    expect(compileProject(forms).startup.name, 'Form1');
    expect(compileProject(forms, startup: 'form2').startup.name, 'Form2');
    expect(compileProject(forms, startup: 'Form9').startup.name, 'Form1');
  });
}
