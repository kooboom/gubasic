import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

const _decl = 'Dim i As Integer = 1\nDim d As Double = 1.5\n'
    'Dim s As String = "a"\nDim b As Boolean = True\n'
    'Dim o As Object = Nothing\nDim l As New List(Of String)\n'
    'Debug.Print(i & d & s & b & l.Count)\nDebug.Print(o)';

String _t(String e) => typeOf(e, declarations: _decl);

List<String> _codes(String e) => inMain('$_decl\nDim x As Object\nx = $e');

void main() {
  group('operator result types', () {
    test('arithmetic', () {
      expect(_t('i + i'), 'Integer');
      expect(_t('i + d'), 'Double');
      expect(_t('i * i'), 'Integer');
      expect(_t('i - d'), 'Double');
      expect(_t('i / i'), 'Double', reason: '/ always gives a Double');
      expect(_t('i ^ i'), 'Double');
      expect(_t(r'i \ i'), 'Integer');
      expect(_t('i Mod i'), 'Integer');
      expect(_t('d Mod i'), 'Double');
      expect(_t('-i'), 'Integer');
      expect(_t('-d'), 'Double');
    });

    test('text', () {
      expect(_t('s + s'), 'String');
      expect(_t('s & i'), 'String');
      expect(_t('i & d & b'), 'String', reason: 'H7: & takes any value');
    });

    test('comparisons and logic', () {
      expect(_t('i < d'), 'Boolean');
      expect(_t('s = s'), 'Boolean');
      expect(_t('b = b'), 'Boolean');
      expect(_t('o Is Nothing'), 'Boolean');
      expect(_t('l Is Nothing'), 'Boolean');
      expect(_t('Not b'), 'Boolean');
      expect(_t('b And b Or b Xor b'), 'Boolean');
    });
  });

  group('refused operators', () {
    test('H4: "+" between text and a number is A011', () {
      expect(_codes('s + i'), ['A011']);
      expect(_codes('"1" + 1'), ['A011']);
    });

    test(r'H5: \ needs whole numbers (A010)', () {
      expect(_codes(r'd \ i'), ['A010']);
      expect(_codes(r'i \ 2.0'), ['A010']);
    });

    test('H3: And, Or, Xor and Not need True/False (A013, A014)', () {
      expect(_codes('5 And 3'), ['A013']);
      expect(_codes('i Or b'), ['A013']);
      expect(_codes('Not i'), ['A014']);
    });

    test('other mismatches', () {
      expect(_codes('-s'), ['A014']);
      expect(_codes('s * 2'), ['A013']);
      expect(_codes('s < i'), ['A013']);
      expect(_codes('b < b'), ['A013'], reason: 'Booleans only = and <>');
      expect(_codes('i Is Nothing'), ['A013'], reason: 'Is compares objects');
      expect(_codes('o + 1'), ['A013'], reason: 'Object needs a conversion');
      expect(_codes('l & "x"'), ['A013'], reason: 'a list is not a value');
    });
  });

  group('assignments use the conversion table', () {
    test('allowed automatically', () {
      expect(inMain('Dim d As Double = 3'), ['A026']);
      expect(inMain('Dim s As String = 3.5\nDebug.Print(s)'), isEmpty);
      expect(inMain('Dim s As String = True\nDebug.Print(s)'), isEmpty);
      expect(inMain('Dim o As Object = "x"\nDebug.Print(o)'), isEmpty);
    });

    test('refused, with the matching hint', () {
      expect(inMain('Dim i As Integer = 2.5\nDebug.Print(i)'), ['A010']);
      expect(inMain('Dim i As Integer = "2"\nDebug.Print(i)'), ['A009']);
      expect(inMain('Dim b As Boolean = 1\nDebug.Print(b)'), ['A008']);
      expect(inMain('Dim s As String = Nothing\nDebug.Print(s)'), ['A008'],
          reason: 'H8');
    });

    test('conversions are recorded for the interpreter', () {
      final r = compile('Sub Main()\nDim d As Double = 3\nDim s As String = d\n'
          'Debug.Print(s)\nEnd Sub');
      final types = r.analysis.conversions.values.toList();
      expect(types, [GbType.double_, GbType.string]);
    });

    test('H2: conditions must be True/False (A012)', () {
      expect(inMain('Dim n As Integer = 1\nIf n Then\nEnd If'), ['A012']);
      expect(inMain('Dim n As Integer = 1\nDo While n\nLoop'), ['A012']);
      expect(inMain('Dim n As Integer = 1\nIf n <> 0 Then\nEnd If'), isEmpty);
    });
  });
}
