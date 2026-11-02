import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// With … End With (docs/DESIGN.md D134): what is reported, `With` as a
/// name, completion and the words written as GuBASIC writes them. How it
/// runs is in the parity program with_block.
const _s = 'Structure S\n    Name As String\n    Marks(2) As Integer\n'
    'End Structure\nFunction Make() As S\n    Dim s As S\n    Return s\n'
    'End Function\n';

List<String> _inMain(String body) =>
    diagnose('${_s}Sub Main()\n$body\nEnd Sub\n')
        .map((c) => c.split('@').first)
        .where((c) => c != 'A026')
        .toList();

void main() {
  test('members with a dot alone, read, written, called, nested', () {
    expect(
        _inMain('Dim g(2) As S\nWith g(1)\n    .Name = .Name & "!"\n'
            '    .Marks(0) = 1\nEnd With\nDim l As New List(Of String)\n'
            'With l\n    .Add("x")\n    Debug.Print(.Count)\nEnd With'),
        isEmpty);
  });

  test('P041: a dot alone outside a With block', () {
    expect(_inMain('.Name = "x"'), ['P041']);
  });

  test('A075: With on what is not a value', () {
    expect(_inMain('With Http\n    .Timeout = 1\nEnd With'), ['A075']);
  });

  test('A065 and A066: a field of a value kept nowhere, of a copy', () {
    expect(_inMain('With Make()\n    .Name = "x"\nEnd With'), ['A065']);
    expect(_inMain('With Make()\n    Debug.Print(.Name)\nEnd With'), isEmpty,
        reason: 'reading it is fine');
    expect(
        _inMain('Dim l As New List(Of S)\nFor Each one In l\n'
            '    With one\n        .Name = "z"\n    End With\nNext'),
        ['A066']);
  });

  test('P006 and P007: With and End With that do not match', () {
    expect(_inMain('Dim x As S\nWith x\n    .Name = "a"'), ['P006']);
    expect(_inMain('End With'), ['P007']);
  });

  test('With is still a name where it is used as one (D132)', () {
    expect(
        _inMain('Dim with As Integer = 1\nwith = with + 1\n'
            'Dim w(1) As Integer\nDebug.Print(with)'),
        isEmpty);
  });

  test('completion: the With value\'s members after a dot alone', () {
    const code = '${_s}Sub Main()\n    Dim x As S\n    With x\n        .\n'
        '    End With\nEnd Sub\n';
    final at = code.indexOf('        .\n') + 9;
    final c = completionsAt(code, at, program: compile(code))!;
    expect(c.items.map((i) => i.name), ['Marks', 'Name']);
  });

  test('case: with and end with are written With and End With', () {
    const code = 'Sub Main()\n    Dim l As New List(Of String)\n'
        '    with l\n        .add("x")\n    end with\nEnd Sub\n';
    expect(
        withCaseFixes(code, caseFixes(compile(code), 0, code.length)),
        'Sub Main()\n    Dim l As New List(Of String)\n'
        '    With l\n        .Add("x")\n    End With\nEnd Sub\n');
  });

  test('Enter after With puts in End With; after End With it is outdented', () {
    const code = 'Sub Main()\n    With lblA\n\nEnd Sub\n';
    final after = afterEnter(code, 2);
    expect(after.closer, 'End With');
    const done = 'Sub Main()\n    With x\n        .A = 1\n        End With\n'
        '\nEnd Sub\n';
    expect(afterEnter(done, 4).indentLine, 4);
    expect(
        afterEnter('Sub Main()\n    with = 1\n\nEnd Sub\n', 2).closer, isNull,
        reason: 'with is a name there');
  });
}
