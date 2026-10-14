import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('A020: constants, procedures and call results cannot be assigned', () {
    expect(diagnose('Const K As Integer = 1\nSub Main()\nK = 2\nEnd Sub'),
        ['A020@3']);
    expect(diagnose('Sub Main()\nHelper = 1\nEnd Sub\nSub Helper()\nEnd Sub'),
        ['A020@2']);
    expect(inMain('Len("a") = 1'), ['A020']);
  });

  test('A021: VB6 style FunctionName = value', () {
    final r =
        diagnose('Function Average(a As Integer, b As Integer) As Double\n'
            '    Average = (a + b) / 2\nEnd Function');
    expect(r, ['A021@2'], reason: 'and no A027 on top');
  });

  test('A022 / A023: Return in Sub and Function', () {
    expect(diagnose('Sub S()\nReturn 1\nEnd Sub'), ['A022@2']);
    expect(
        diagnose('Function F() As Integer\nReturn\nEnd Function'), ['A023@2']);
    expect(diagnose('Sub S()\nReturn\nEnd Sub'), isEmpty);
    expect(diagnose('Function F() As Integer\nReturn 2.5\nEnd Function'),
        ['A010@2']);
  });

  test('A024: Exit outside its loop or procedure', () {
    expect(inMain('Exit For'), ['A024']);
    expect(inMain('Exit Do'), ['A024']);
    expect(inMain('Exit Function'), ['A024']);
    expect(inMain('Exit Sub'), isEmpty);
    expect(inMain('For i = 1 To 2\n  Do\n    Exit For\n  Loop\nNext'), isEmpty);
  });

  test('Select Case values must be comparable with the subject', () {
    expect(
        inMain('Dim d As Integer = 3\nSelect Case d\nCase 1, 7\n'
            'Case 2 To 6\nCase Is > 7\nCase Else\nEnd Select'),
        isEmpty);
    expect(inMain('Dim d As Integer = 3\nSelect Case d\nCase "x"\nEnd Select'),
        ['A013']);
  });

  test('ReDim needs an array and a whole-number bound', () {
    expect(inMain('Dim a() As Integer\nReDim Preserve a(9)'), isEmpty);
    expect(inMain('Dim n As Integer = 1\nReDim n(3)'), ['A018']);
  });

  group('warnings', () {
    test('A026: unused locals, but not parameters or loop variables', () {
      expect(
          diagnose(
              'Sub S(p As Integer)\nDim a As Integer\nStatic b As Integer\n'
              'Const C As Integer = 1\nFor i = 1 To 2\nNext\nEnd Sub'),
          ['A026@2', 'A026@3', 'A026@4']);
    });

    test('assigning counts as using (H6)', () {
      expect(inMain('Dim a As Integer\na = 1'), isEmpty);
    });

    test('A027: a Function with no Return', () {
      expect(diagnose('Function F() As Integer\nEnd Function'), ['A027@1']);
    });

    test('warnings alone are not errors', () {
      final r = compile('Sub S()\nDim a As Integer\nEnd Sub');
      expect(r.diagnostics.single.isWarning, isTrue);
      expect(r.hasErrors, isFalse);
    });
  });

  test('statements outside procedures are left to the parser (P008)', () {
    expect(diagnose('x = 1'), ['P008@1']);
  });
}
