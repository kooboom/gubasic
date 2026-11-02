import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The words the editor writes as GuBASIC writes them (docs/DESIGN.md
/// D133), checked on the whole code.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblTotal, type: Label }
  - { name: btnAdd, type: Button }
''', name: 'Form1').form;

String _fixed(String code, {FormFile? form}) {
  final program = compile(code, form: form);
  return withCaseFixes(code, caseFixes(program, 0, code.length));
}

void main() {
  test('keywords as spelled, names as declared', () {
    expect(
        _fixed(
            'dim total as integer\nsub btnAdd_Click()\n'
            '    TOTAL = total + 1\n    lbltotal.caption = cstr(Total)\n'
            '    debug.print(TOTAL)\nend sub\n',
            form: _form),
        'Dim total As Integer\nSub btnAdd_Click()\n'
        '    total = total + 1\n    lblTotal.Caption = CStr(total)\n'
        '    Debug.Print(total)\nEnd Sub\n');
  });

  test('strings, comments, undeclared names and declarations stay', () {
    const code = 'Sub Main()\n    Dim Count As Integer\n'
        '    debug.print("dim x as integer") \' dim y\n'
        '    nope = 1\nEnd Sub\n';
    expect(
        _fixed(code),
        'Sub Main()\n    Dim Count As Integer\n'
        '    Debug.Print("dim x as integer") \' dim y\n'
        '    nope = 1\nEnd Sub\n');
  });

  test('types, Structures, fields, With lists and events', () {
    expect(
        _fixed(
            'structure Student\n    name as string\n    marks(2) as integer\n'
            'end structure\nsub btnAdd_Click() handles btnadd.click\n'
            '    dim s as student = new STUDENT with {.NAME = "x"}\n'
            '    s.Name = s.NAME & "!"\n    dim l as new list(of student)\n'
            'end sub\n',
            form: _form),
        'Structure Student\n    name As String\n    marks(2) As Integer\n'
        'End Structure\nSub btnAdd_Click() Handles btnAdd.Click\n'
        '    Dim s As Student = New Student With {.name = "x"}\n'
        '    s.name = s.name & "!"\n    Dim l As New List(Of Student)\n'
        'End Sub\n');
  });

  test('only the range asked for, and only the case', () {
    const code = 'dim a as integer\ndim b as integer\n';
    final program = compile(code);
    expect(caseFixes(program, 17, code.length).map((f) => f.text),
        ['Dim', 'As', 'Integer']);
    expect(caseFixes(compile('Dim a As Integer\n'), 0, 17), isEmpty);
  });
}
