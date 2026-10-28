import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('scopes', () {
    test('locals, parameters, Static, form variables, constants, built-ins',
        () {
      expect(
          diagnose('Dim formCount As Integer\n'
              'Const Limit As Integer = 3\n'
              'Sub Count(amount As Integer)\n'
              '    Static calls As Integer\n'
              '    Dim local As Integer = amount * Limit\n'
              '    calls = calls + 1\n'
              '    formCount = formCount + local + Len("abc")\n'
              'End Sub\n'),
          isEmpty);
    });

    test('names are case-insensitive', () {
      expect(inMain('Dim Total As Integer\nTOTAL = 1\ntotal = TotaL + 1'),
          isEmpty);
    });

    test('procedures can be used before they are written', () {
      expect(
          diagnose('Sub Main()\n    Greet()\nEnd Sub\n'
              'Sub Greet()\nEnd Sub\n'),
          isEmpty);
    });

    test('H1: a Dim inside a block is visible only in that block', () {
      expect(
          inMain(
              'If True Then\n  Dim t As Integer = 1\n  t = t + 1\nEnd If\nt = 2'),
          ['A001']);
    });

    test('H1: a block local may not reuse a name from its procedure', () {
      expect(
          inMain('Dim a As Integer = 1\nIf a > 0 Then\n  Dim a As Integer = 2\n'
              '  a = a + 1\nEnd If'),
          ['A005']);
    });

    test('H1: two sibling blocks may use the same name', () {
      expect(
          inMain('If True Then\n  Dim t As Integer = 1\n  t = t + 1\nElse\n'
              '  Dim t As Integer = 2\n  t = t + 1\nEnd If'),
          isEmpty);
    });

    test('H1: a local hiding a form variable is a warning (A028)', () {
      final r = compile('Dim count As Integer\nSub Main()\n'
          '    Dim count As Integer = 1\n    count = count + 1\nEnd Sub\n');
      expect(r.diagnostics.map((d) => d.code.code), ['A028']);
      expect(r.diagnostics.single.args, ['count', '1']);
      expect(r.hasErrors, isFalse);
    });
  });

  group('undeclared names', () {
    test('A001 with no similar name', () {
      expect(inMain('zebra = 1'), ['A001']);
    });

    test('A002 suggests a similar visible name', () {
      final r = compile('Sub Main()\nDim total As Integer\ntotl = 1\n'
          'total = total + 1\nEnd Sub');
      expect(r.diagnostics.map((d) => d.code.code), ['A002']);
      expect(r.diagnostics.single.args, ['totl', 'total']);
    });

    test('A002 also suggests built-ins', () {
      final d = compile('Sub Main()\nMsgBx("hi")\nEnd Sub').diagnostics.single;
      expect(d.args, ['MsgBx', 'MsgBox']);
    });

    test('no guesses for one- and two-letter names', () {
      expect(inMain('Dim x As Integer = 1\nx = x + y'), ['A001']);
    });

    test('short names need a closer match', () {
      expect(inMain('Dim ab As Integer = 1\nab = ab + q'), ['A001']);
    });

    test('A003: a name used with "." may be a control; Me too', () {
      expect(inMain('lblMessage.Caption = "Hi"'), ['A003']);
      expect(inMain('Me.Caption = "Hi"'), ['A003']);
    });

    test('A006: a local used above its declaration', () {
      final r = compile('Sub Main()\nx = 5\nDim x As Integer\nx = x + 1\n'
          'End Sub');
      expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), ['A006@2']);
      expect(r.diagnostics.single.args, ['x', '3']);
    });

    test('a local used above its declaration is not also "unused"', () {
      expect(inMain('x = 5\nDim x As Integer'), ['A006']);
    });

    test('undeclared names give no follow-up type errors', () {
      expect(inMain('Dim s As String = nope + 1 & nope2.Text\nDebug.Print(s)'),
          ['A001', 'A003']);
    });
  });

  group('declarations', () {
    test('A005: duplicate form variables, procedures and parameters', () {
      expect(
          diagnose('Dim a As Integer\nDim A As String\n'
              'Sub P(x As Integer, X As Integer)\nEnd Sub\n'
              'Sub p()\nEnd Sub\n'),
          ['A005@2', 'A005@3', 'A005@5']);
    });

    test('A007: Dim needs a type or a value; parameters and Functions a type',
        () {
      expect(
          diagnose('Dim a\nSub P(x)\nEnd Sub\nFunction F()\nReturn 1\n'
              'End Function\n'),
          ['A007@1', 'A007@2', 'A007@4']);
      expect(inMain('Dim n = Nothing\nDebug.Print(n)'), ['A007']);
    });

    test('A004: unknown type names', () {
      expect(inMain('Dim b As Buton'), ['A026', 'A004']);
    });

    test(
        'control types exist and are made with New; a form, and Control, '
        'are not (A047)', () {
      expect(inMain('Dim b As Button\nb = Nothing'), isEmpty);
      expect(inMain('Dim b As New Button\nb = Nothing'), isEmpty);
      expect(inMain('Dim b As Label = New Label\nb = Nothing'), isEmpty);
      expect(inMain('Dim f As New Form\nf = Nothing'), ['A047']);
      expect(inMain('Dim c As New Control\nc = Nothing'), ['A047']);
      expect(inMain('Dim b As New Button(1)\nb = Nothing'), ['A015']);
    });

    test('inferred types', () {
      expect(typeOf('a', declarations: 'Dim a = 1'), 'Integer');
      expect(typeOf('a', declarations: 'Dim a = 1.5'), 'Double');
      expect(typeOf('a', declarations: 'Dim a = "x" & 1'), 'String');
      expect(typeOf('a', declarations: 'Dim a = New List(Of Integer)'),
          'List(Of Integer)');
      expect(typeOf('a', declarations: 'Dim a(3) As String'), 'String()');
    });
  });

  group('For and For Each variables', () {
    test('an undeclared For variable exists only inside the loop', () {
      expect(inMain('For i = 1 To 3\n  Debug.Print(i)\nNext\nDebug.Print(i)'),
          ['A001']);
    });

    test('its type comes from the bounds', () {
      final r = compile('Sub Main()\nFor i = 1 To 3\nNext\n'
          'For j = 0 To 1 Step 0.5\nNext\nEnd Sub');
      final types = r.analysis.loopVariables.values.map((s) => s.type);
      expect(types, [GbType.integer, GbType.double_]);
      expect(r.diagnostics, isEmpty);
    });

    test('a declared variable is used as it is', () {
      final r = compile('Sub Main()\nDim i As Integer\nFor i = 1 To 3\nNext\n'
          'Debug.Print(i)\nEnd Sub');
      expect(r.diagnostics, isEmpty);
      expect(r.analysis.loopVariables.values.single.kind, SymbolKind.variable);
    });

    test('For i As Integer declares a new loop variable', () {
      expect(
          inMain(
              'Dim i As Integer = 0\nFor i As Integer = 1 To 3\nNext\nDebug.Print(i)'),
          ['A005']);
      expect(inMain('For i As Double = 0 To 1 Step 0.1\nNext'), isEmpty);
    });

    test('Double bounds for an Integer variable are refused', () {
      expect(inMain('Dim i As Integer\nFor i = 0 To 2.5\nNext'), ['A010']);
    });

    test('For Each takes the element type', () {
      final r = compile('Sub Main()\nDim names As New List(Of String)\n'
          'For Each n In names\n  Debug.Print(n.ToUpper())\nNext\nEnd Sub');
      expect(r.diagnostics, isEmpty);
      expect(r.analysis.loopVariables.values.single.type, GbType.string);
    });

    test('For Each over a value that is not a list (A025)', () {
      expect(
          inMain('Dim s As String = "abc"\nFor Each c In s\nNext'), ['A025']);
    });
  });
}
