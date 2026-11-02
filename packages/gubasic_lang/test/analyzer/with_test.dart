import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

/// With lists and lists of items (docs/DESIGN.md D132, LANGUAGE §4,
/// §4.1): what is reported. How they run is in the parity programs
/// structure_with and controls_new_with.
const _q = 'Structure Q\n    Text As String\n    Choices(3) As String\n'
    '    Extra() As Integer\n    Home As A\nEnd Structure\n'
    'Structure A\n    City As String\nEnd Structure\n';

/// Diagnostic codes of [body] in `Sub Main()`, after [_q], without the
/// unused-variable warnings the short examples make.
List<String> _inMain(String body) =>
    diagnose('${_q}Sub Main()\n$body\nEnd Sub\n')
        .map((c) => c.split('@').first)
        .where((c) => c != 'A026')
        .toList();

void main() {
  group('With lists', () {
    test('fields in any order, on several lines, nested', () {
      expect(
          _inMain('Dim q As Q = New Q With {\n    .Choices = {"a", "b", "c", '
              '"d"},\n    .Text = "x",\n    .Home = New A With {.City = "s"}\n'
              '}\nDebug.Print(q.Text)'),
          isEmpty);
      expect(_inMain('Dim q As New Q With {.Text = "x"}\nDebug.Print(q.Text)'),
          isEmpty);
    });

    test('P037–P040: no dot, a field\'s field, a field read, nothing', () {
      expect(_inMain('Dim q = New Q With {Text = "x"}'), ['P037']);
      expect(_inMain('Dim q = New Q With {.Home.City = "x"}'), ['P038']);
      expect(_inMain('Dim q = New Q With {.Text = .Text & "!"}'), ['P039']);
      expect(_inMain('Dim q = New Q With {}'), ['P040']);
    });

    test('A071: a field twice; A019 and A035: no such field', () {
      expect(
          _inMain('Dim q = New Q With {.Text = "a", .Text = "b"}'), ['A071']);
      expect(_inMain('Dim q = New Q With {.Tex = "a"}'), ['A035']);
    });

    test('A070: a type with nothing to set; controls and PdfDocument can', () {
      expect(
          _inMain('Dim l = New List(Of String) With {.Count = 1}'), ['A070']);
      expect(
          _inMain('Dim b = New Button With {.Caption = "OK", .Top = 40}\n'
              'Dim d = New PdfDocument With {.Landscape = True}'),
          isEmpty);
      expect(_inMain('Dim b = New Button With {.Clear = 1}'), ['A019']);
    });

    test('a missing } ends at the line that cannot continue the list', () {
      expect(
          diagnose('${_q}Sub Main()\nDim q = New Q With {.Text = "a"\n'
                  'Debug.Print(q.Text)\nEnd Sub\n')
              .map((c) => c.split('@').first),
          ['P003']);
    });

    test('With is still a name elsewhere', () {
      expect(_inMain('Dim with As Integer = 1\nwith = with + 1'), isEmpty);
    });
  });

  group('lists of items', () {
    test('take the array type they go to, or their items\'', () {
      expect(
          _inMain('Dim a() As String = {"x", "y"}\nDim b = {1, 2.5}\n'
              'Dim c() As Double = {1, 2}\na = {}\n'
              'Debug.Print(UBound({3, 4}))'),
          isEmpty);
      expect(
          diagnose('Sub Main()\nShow({1, 2})\nEnd Sub\n'
              'Sub Show(values() As Integer)\nEnd Sub\n'),
          isEmpty);
    });

    test('A073: a type that cannot be told; A008: an item of another type', () {
      expect(_inMain('Dim a = {}'), ['A073']);
      expect(_inMain('Dim a = {1, "x"}'), ['A073']);
      expect(_inMain('Dim a() As Integer = {1, "x"}'), ['A009']);
    });

    test('A072: a list for an array field of a size; A074: Dim a(2) = list',
        () {
      expect(_inMain('Dim q = New Q With {.Choices = {"a", "b"}}'), ['A072']);
      expect(_inMain('Dim q As Q\nq.Choices = {"a"}'), ['A072']);
      expect(_inMain('Dim q = New Q With {.Extra = {1, 2, 3, 4, 5}}'), isEmpty,
          reason: 'a field without a size takes any number');
      expect(_inMain('Dim a(2) As Integer = {1, 2, 3}'), ['A074']);
    });
  });

  test('completion: the fields after a dot in a With list', () {
    const code = '${_q}Sub Main()\n    Dim q = New Q With {.Text = "x",\n'
        '        .\nEnd Sub\n';
    final at = code.indexOf('        .\n') + 9;
    final c = completionsAt(code, at, program: compile(code))!;
    expect(c.items.map((i) => i.name), ['Choices', 'Extra', 'Home', 'Text']);
  });
}
