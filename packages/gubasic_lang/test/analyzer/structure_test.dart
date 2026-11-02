import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// Structures (docs/DESIGN.md D131, LANGUAGE §4.1): how they are declared,
/// what is reported, and how a project's modules and forms share them.
/// How they run is in the parity programs structure_basics, structure_copy,
/// structure_collections and structure_module.
const _student = 'Structure Student\n    Name As String\n    Score As Integer\n'
    '    Marks(2) As Integer\nEnd Structure\n';

/// Diagnostic codes of [body] in `Sub Main()`, after [_student].
List<String> _inMain(String body) =>
    diagnose('${_student}Sub Main()\n$body\nEnd Sub\n')
        .map((c) => c.split('@').first)
        .toList();

final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblName, type: Label }
''', name: 'Form1').form;

final _form2 = readFormFile('formatVersion: 1\n', name: 'Form2').form;

List<String> _project(Map<String, String> forms, Map<String, String> modules) {
  final p = compileProject([
    for (final MapEntry(:key, :value) in forms.entries)
      (file: key == 'Form1' ? _form : _form2, source: value),
  ], modules: [
    for (final MapEntry(:key, :value) in modules.entries)
      (name: key, source: value),
  ]);
  return [
    for (final (file, program) in [
      for (final f in p.forms) (f.codeFile, f.program),
      for (final m in p.modules) (m.codeFile, m.program),
    ])
      for (final d in program.diagnostics) '${d.code.code}@$file:${d.line}',
  ];
}

void main() {
  group('declaring', () {
    test('the three ways of writing a field mean the same', () {
      expect(
          diagnose('Structure P\n    X As Integer\n    Public Y As Integer\n'
              '    Dim Z As Integer\nEnd Structure\nSub Main()\nDim p As P\n'
              'p.X = p.Y + p.Z\nEnd Sub\n'),
          isEmpty);
    });

    test('P031: Visual Basic 6\'s Type … End Type is read as a Structure', () {
      expect(
          diagnose('Type P\n    X As Integer\nEnd Type\nSub Main()\n'
              'Dim p As P\np.X = 1\nEnd Sub\n'),
          ['P031@1']);
    });

    test(
        'P032–P036: values, Private, no fields, inside a procedure, '
        'other than fields', () {
      expect(diagnose('Structure S\n    A As Integer = 1\nEnd Structure\n'),
          ['P032@2']);
      expect(diagnose('Structure S\n    Private A As Integer\nEnd Structure\n'),
          ['P033@2']);
      expect(diagnose('Structure S\nEnd Structure\n'), ['P034@1']);
      expect(
          diagnose('Sub Main()\nStructure S\n    A As Integer\n'
              'End Structure\nEnd Sub\n'),
          ['P035@2']);
      expect(
          diagnose('Structure S\n    A As Integer\n    Const B As Integer = 1\n'
              '    Sub F()\n    End Sub\nEnd Structure\nSub Main()\nEnd Sub\n'),
          ['P036@3', 'P036@4'],
          reason: 'a procedure inside is skipped whole, and the file goes on');
    });

    test('a missing End Structure ends at the next procedure', () {
      expect(
          diagnose('Structure S\n    A As Integer\nSub Main()\nDim s As S\n'
              's.A = 1\nEnd Sub\n'),
          ['P006@1']);
    });

    test('A005: a field, or a Structure, declared twice', () {
      expect(
          diagnose('Structure S\n    A As Integer\n    a As String\n'
              'End Structure\n'),
          ['A005@3']);
      expect(
          diagnose('Structure S\n    A As Integer\nEnd Structure\n'
              'Structure S\n    B As Integer\nEnd Structure\n'),
          ['A005@4']);
    });

    test('A061: a Structure that contains itself; a List of it is fine', () {
      expect(
          diagnose('Structure A\n    Other As B\nEnd Structure\n'
              'Structure B\n    Back As A\nEnd Structure\n'),
          ['A061@1', 'A061@4']);
      expect(
          diagnose('Structure Node\n    Kids As List(Of Node)\n'
              '    Later() As Node\nEnd Structure\n'),
          isEmpty);
      expect(diagnose('Structure Node\n    Pair(1) As Node\nEnd Structure\n'),
          ['A061@1'],
          reason: 'an array with a size holds its values from the start');
    });

    test(
        'A068: the name of a GuBASIC type; A069: a size that is not a '
        'whole number', () {
      expect(diagnose('Structure Table\n    A As Integer\nEnd Structure\n'),
          ['A068@1']);
      expect(
          diagnose('Const N As Integer = 3\nStructure S\n'
              '    A(N) As Integer\nEnd Structure\n'),
          ['A069@3']);
    });
  });

  group('using', () {
    test('fields are read and written; a Structure is a value', () {
      expect(
          _inMain('Dim s As Student\ns.Name = "Kim"\ns.Marks(1) = 3\n'
              'Dim t As Student = s\nDim u As New Student\nu = t\n'
              'Debug.Print(u.Name & u.Marks(1))'),
          isEmpty);
      expect(_inMain('Dim s As Student\ns.Nme = "x"'), ['A035']);
      expect(_inMain('Dim s As Student = Nothing'), ['A026', 'A008']);
    });

    test('A063, A064, A067: compared, text, Object', () {
      expect(
          _inMain('Dim a As Student\nDim b As Student\n'
              'Debug.Print(a = b)'),
          ['A063']);
      expect(_inMain('Dim a As Student\nDebug.Print(a Is Nothing)'), ['A063']);
      expect(
          _inMain('Dim l As New List(Of Student)\nDim a As Student\n'
              'Debug.Print(l.Contains(a))'),
          ['A063']);
      expect(_inMain('Dim a As Student\nDebug.Print(a)'), ['A064']);
      expect(_inMain('Dim a As Student\nDebug.Print("x" & a)'), ['A064']);
      expect(
          _inMain('Dim a As Student\nDim t As String = a\nt = ""'), ['A064']);
      expect(_inMain('Dim a As Student\nDim o As Object = a\no = Nothing'),
          ['A067']);
    });

    test('A065: a field of a value kept nowhere', () {
      expect(
          diagnose('${_student}Function F() As Student\nDim s As Student\n'
              'Return s\nEnd Function\nSub Main()\nF().Score = 1\n'
              'F().Marks(0) = 1\nEnd Sub\n'),
          ['A065@11', 'A065@12']);
      expect(
          _inMain('Dim l As New List(Of Student)\nl.Add(New Student)\n'
              'l(0).Score = 1\nDim g(2) As Student\ng(1).Marks(2) = 4'),
          isEmpty,
          reason: 'an item is where the value is kept');
    });

    test('A066: a field of a For Each variable changes the copy (warning)', () {
      expect(
          _inMain('Dim l As New List(Of Student)\nFor Each s In l\n'
              's.Score = 1\nNext'),
          ['A066']);
      expect(
          _inMain('Dim l As New List(Of Student)\nFor i = 0 To l.Count - 1\n'
              'l(i).Score = 1\nNext'),
          isEmpty);
      final r = compile('${_student}Sub Main()\nDim l As New List(Of Student)\n'
          'For Each s In l\ns.Score = 1\nNext\nEnd Sub\n');
      expect(r.hasErrors, isFalse, reason: 'the program can still run');
    });

    test('ReDim of an array field', () {
      expect(
          diagnose('Structure S\n    Extra() As Integer\nEnd Structure\n'
              'Sub Main()\nDim s As S\nReDim s.Extra(3)\n'
              'ReDim Preserve s.Extra(5)\nEnd Sub\n'),
          isEmpty);
    });
  });

  group('in a project', () {
    const module = 'Public Structure Student\n    Name As String\n'
        '    Score As Integer\nEnd Structure\n'
        'Public Current As Student\n';

    test(
        'a module\'s Structure in every form, and a form\'s other forms\' '
        'variables of it', () {
      expect(
          _project({
            'Form1': 'Sub Form_Load()\nDim s As Student\ns.Name = "Kim"\n'
                'Current = s\nForm2.Picked = s\nForm2.Picked.Score = 5\n'
                'lblName.Caption = Form2.Picked.Name & Current.Name\nEnd Sub\n',
            'Form2': 'Public Picked As Student\n',
          }, {
            'Module1': module
          }),
          isEmpty);
    });

    test(
        'a form\'s Structure is its own: A062 for Public, A068 for a '
        'module\'s name', () {
      expect(
          _project({
            'Form1': 'Public Structure Pair\n    A As Integer\nEnd Structure\n'
                'Structure Student\n    B As Integer\nEnd Structure\n',
          }, {
            'Module1': module
          }),
          ['A062@Form1.gbas:1', 'A068@Form1.gbas:4']);
    });

    test('A068: two modules give one name to two Structures', () {
      expect(
          _project({
            'Form1': ''
          }, {
            'Module1': module,
            'Module2': 'Structure Student\n    X As Integer\nEnd Structure\n',
          }),
          ['A068@Module1.gbas:1', 'A068@Module2.gbas:1']);
    });

    test('a Private Structure stays its module\'s', () {
      expect(
          _project({
            'Form1': 'Sub Form_Load()\nDim s As Secret\nEnd Sub\n'
          }, {
            'Module1': 'Private Structure Secret\n    X As Integer\n'
                'End Structure\n',
          }),
          ['A026@Form1.gbas:2', 'A004@Form1.gbas:2']);
    });
  });

  test('the debugger shows a Structure with its fields', () {
    final t = StructureType('Student')
      ..fields.addAll(const [
        StructureFieldType('Name', GbType.string),
        StructureFieldType('Marks', ArrayType(GbType.integer), size: 1),
      ]);
    final s = GbStruct.empty(t)..values[0] = 'Kim';
    expect(debugValueText(s), 'Student { Name = "Kim", Marks = (0, 0) }');
  });

  test('completion: Structure names after As, fields after a dot', () {
    const code = '${_student}Sub Main()\n    Dim s As Student\n'
        '    Dim t As Stu\n    s.\nEnd Sub\n';
    final program = compile(code);
    final afterAs =
        completionsAt(code, code.indexOf('Stu\n') + 3, program: program)!;
    expect(afterAs.items.map((c) => c.name), contains('Student'));
    final afterDot =
        completionsAt(code, code.indexOf('s.\n') + 2, program: program)!;
    expect(afterDot.items.map((c) => c.name), ['Marks', 'Name', 'Score']);
  });
}
