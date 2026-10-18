import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('procedures', () {
    test('argument count and types, Optional parameters', () {
      const procs = 'Sub Show(name As String, Optional times As Integer = 1)\n'
          'End Sub\n';
      expect(diagnose('${procs}Sub Main()\nShow("a")\nShow("a", 2)\nEnd Sub'),
          isEmpty);
      expect(diagnose('${procs}Sub Main()\nShow()\nEnd Sub'), ['A015@4']);
      expect(
          diagnose('${procs}Sub Main()\nShow("a", 1, 2)\nEnd Sub'), ['A015@4']);
      expect(
          diagnose('${procs}Sub Main()\nShow("a", 1.5)\nEnd Sub'), ['A010@4']);
      final d =
          compile('${procs}Sub Main()\nShow()\nEnd Sub').diagnostics.single;
      expect(d.args, ['Show', '1–2', '0']);
    });

    test('a Function gives a value; a Sub does not (A017)', () {
      const procs = 'Function Twice(n As Integer) As Integer\nReturn n * 2\n'
          'End Function\nSub Hello()\nEnd Sub\n';
      expect(
          diagnose('${procs}Sub Main()\nDim a = Twice(2)\nDebug.Print(a)\n'
              'Twice(3)\nHello()\nEnd Sub'),
          isEmpty);
      expect(
          diagnose('${procs}Sub Main()\nDim a = Hello()\nDebug.Print(a)\n'
              'End Sub'),
          ['A017@7']);
    });

    test('calls without parentheses need no arguments (F4)', () {
      final r = compile('Sub Main()\nDoEvents\nDim t = Now\nDebug.Print(t)\n'
          'Randomize\nEnd Sub');
      expect(r.diagnostics, isEmpty);
      expect(r.analysis.implicitCalls, hasLength(3));
      expect(inMain('Len'), ['A015']);
    });

    test('a variable cannot be called (A016)', () {
      expect(inMain('Dim n As Integer = 1\nn'), ['A016']);
      expect(inMain('Dim a(3) As Integer\na(1)'), ['A016']);
    });
  });

  group('built-ins', () {
    test('typical calls', () {
      expect(
          inMain('Dim s As String = Mid("hello", 2, 3) & Left("ab", 1) & '
              'UCase("x")\nDim n As Integer = Len(s) + InStr(s, "l")\n'
              'Dim r As Double = Sqr(2) + Rnd() + Round(2.567, 2)\n'
              'Debug.Print(s & n & r & Abs(-3) & Max(1, 2.5) & UBound(Split(s, "l")))'),
          isEmpty);
    });

    test('conversion functions accept what they convert', () {
      expect(
          inMain('Debug.Print(CInt("12") + CInt(2.5) + Int(-2.5) + '
              'CDbl("1.5") + Val("3"))\nDebug.Print(CStr(True) & CBool("True"))'),
          isEmpty);
      expect(inMain('Debug.Print(CInt(True))'), ['A008']);
    });

    test('result types follow the arguments for Abs, Min and Max', () {
      expect(typeOf('Abs(-3)'), 'Integer');
      expect(typeOf('Abs(-3.5)'), 'Double');
      expect(typeOf('Max(1, 2)'), 'Integer');
      expect(typeOf('Min(1, 2.5)'), 'Double');
      expect(typeOf('Int(2.5)'), 'Integer', reason: 'Int gives an Integer');
    });

    test('Debug.Print takes any value', () {
      expect(inMain('Debug.Print(1)\nDebug.Print("a")\nDebug.Print(True)'),
          isEmpty);
      expect(inMain('Debug.Print()'), ['A015']);
      expect(inMain('Debug.Write("x")'), ['A019']);
    });

    test('MsgBox and InputBox', () {
      expect(
          inMain('Dim name As String = InputBox("Name?", "Title", "Kim")\n'
              'MsgBox("Hello, " & name, "Greeting")\nMsgBox(42)'),
          isEmpty,
          reason: 'numbers become text automatically');
    });
  });

  group('members and items', () {
    test('List members', () {
      expect(
          inMain('Dim l As New List(Of Integer)\nl.Add(1)\nl.Insert(0, 2)\n'
              'Debug.Print(l.Count & l.Contains(1) & l.IndexOf(2))\n'
              'l.RemoveAt(0)\nl.Clear()'),
          isEmpty);
      expect(inMain('Dim l As New List(Of Integer)\nl.Add("x")'), ['A009']);
      expect(inMain('Dim l As New List(Of Integer)\nl.Count = 3'), ['A034']);
    });

    test('String members count from 0', () {
      expect(
          inMain('Dim s As String = "Hello"\n'
              'Debug.Print(s.Length & s.Substring(1, 2) & s.ToUpper & '
              's.IndexOf("l") & s.Contains("e"))'),
          isEmpty);
      expect(inMain('Dim s As String = "a"\nDebug.Print(s.Size)'), ['A019']);
    });

    test('items of arrays and lists; text has none (A018)', () {
      final r = compile('Sub Main()\nDim a(2) As Integer\na(0) = 5\n'
          'Dim l As New List(Of String)\nl.Add("x")\nDebug.Print(a(0) & l(0))\n'
          'End Sub');
      expect(r.diagnostics, isEmpty);
      expect(r.analysis.invokeKinds.values,
          everyElement(anyOf(InvokeKind.item, InvokeKind.call)));
      expect(inMain('Dim a(2) As Integer\nDebug.Print(a(1.5))'), ['A010']);
      expect(inMain('Dim s As String = "abc"\nDebug.Print(s(0))'), ['A018']);
    });

    test('members of Object are not checked', () {
      expect(inMain('Dim o As Object = Nothing\nDebug.Print(o.Anything)'),
          isEmpty);
    });

    test('Exception.Message and New Exception', () {
      expect(
          inMain('Try\n  Throw New Exception("bad")\nCatch ex As Exception\n'
              '  Debug.Print(ex.Message)\nEnd Try'),
          isEmpty);
      expect(inMain('Throw "bad"'), ['A008']);
      expect(inMain('Throw New Exception(1, 2)'), ['A015']);
    });
  });
}
