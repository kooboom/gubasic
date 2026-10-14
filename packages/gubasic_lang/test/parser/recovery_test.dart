import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

List<String> _procedureNames(ParseResult r) => [
      for (final m in r.unit.members)
        if (m is ProcedureDecl) m.name.name,
    ];

void main() {
  test('missing End If: reported at the If, the Sub still closes', () {
    final r = parse('Sub A()\n'
        '    If x Then\n'
        '        y = 1\n'
        'End Sub\n'
        'Sub B()\n'
        'End Sub\n');
    expect(codesAndLines(r), ['P006@2']);
    expect(r.diagnostics.single.args, ['If', '2', 'End If']);
    expect(_procedureNames(r), ['A', 'B']);
  });

  test('missing End Sub: the next Sub starts a new procedure', () {
    final r = parse('Sub A()\n  x = 1\nSub B()\n  y = 2\nEnd Sub\n');
    expect(codesAndLines(r), ['P006@1']);
    expect(r.diagnostics.single.args, ['Sub', '1', 'End Sub']);
    expect(_procedureNames(r), ['A', 'B']);
  });

  test('unclosed blocks at end of file are all reported', () {
    final r = parse('Sub A()\n  For i = 1 To 3\n    Do\n      If x Then\n');
    expect(codesAndLines(r), ['P006@1', 'P006@2', 'P006@3', 'P006@4']);
  });

  test('Next while an If is open closes the For; the If is reported', () {
    final r = parse('Sub A()\nFor i = 1 To 3\nIf x Then\ny = 1\nNext\n'
        'End Sub');
    expect(codesAndLines(r), ['P006@3']);
    final f = (r.unit.members.single as ProcedureDecl).body.statements.single;
    expect(f, isA<ForStmt>());
  });

  test('closers with no open block are reported and skipped', () {
    final r = parse('Sub A()\nEnd If\nNext\nLoop\nCase 1\nElse\n'
        'Catch\nEnd Select\nEnd Try\nWend\nx = 1\nEnd Sub');
    expect(codes(r), List.filled(9, 'P007'));
    expect(r.diagnostics.first.args, ['End If', 'If']);
    expect(r.diagnostics[1].args, ['Next', 'For']);
    expect((r.unit.members.single as ProcedureDecl).body.statements.single,
        isA<AssignmentStmt>());
  });

  test('a missing operand becomes an Error node; parsing goes on', () {
    final r = parse('Sub A()\nx = 1 +\ny = 2\nEnd Sub');
    expect(codesAndLines(r), ['P001@2']);
    final s = (r.unit.members.single as ProcedureDecl).body.statements;
    expect(exprToSexp((s[0] as AssignmentStmt).value), '(+ 1 <error>)');
    expect(s[1], isA<AssignmentStmt>());
  });

  test('missing ) is P003; extra tokens are P005', () {
    expect(codes(parse('Sub A()\nMsgBox("a"\nEnd Sub')), ['P003']);
    expect(codes(parse('Sub A()\nx = 1 2\nEnd Sub')), ['P005']);
  });

  test('one diagnostic per statement', () {
    final r = parse('Sub A()\nx = (1 + ) * ) 3\nEnd Sub');
    expect(codes(r), ['P001']);
  });

  test('a line with a lexer error gets no parser diagnostic', () {
    final r = parse('Sub A()\nx = "open\ny = 1 @ 2\nz = 3 : w = 4\nEnd Sub');
    expect(codes(r), ['L001', 'L004', 'L003']);
  });

  test('Korean names (L002) still parse as names', () {
    final r = parse('Sub A()\nDim 점수 As Integer\n점수 = 10\nEnd Sub');
    expect(codes(r), ['L002', 'L002']);
    final s = (r.unit.members.single as ProcedureDecl).body.statements;
    expect((s[0] as LocalDeclStmt).declarator.name.name, '점수');
    expect(s[1], isA<AssignmentStmt>());
  });

  test('many errors: all collected, in order, and the last Sub is parsed', () {
    const src = 'Dim 점수 As Integer\n' // 1  L002
        'x = 1\n' // 2  P008
        'Sub A()\n' // 3
        '    If a Then\n' // 4  P006 (never closed)
        '        b = (1 +\n' // 5  P023
        '    c = "open\n' // 6  L001
        'End Sub\n' // 7
        'Next\n' // 8  P007
        'Sub B()\n' // 9
        '    GoTo Done\n' // 10 P014
        '    For i = 1 To 3\n' // 11
        '    Next j\n' // 12 P010
        '    Set d = e : f = g\n' // 13 L003
        'End Sub\n' // 14
        'Sub Last()\n' // 15
        '    MsgBox("끝")\n' // 16
        'End Sub\n';
    final r = parse(src);
    expect(codesAndLines(r), [
      'L002@1',
      'P008@2',
      'P006@4',
      'P023@5',
      'L001@6',
      'P007@8',
      'P014@10',
      'P010@12',
      'P020@13',
      'L003@13',
    ]);
    expect(_procedureNames(r), ['A', 'B', 'Last']);
    final last = r.unit.members.last as ProcedureDecl;
    expect(
        exprToSexp((last.body.statements.single as ExpressionStmt).expression),
        '(call MsgBox "끝")');
  });

  test('Catch or Finally after Finally is reported; lines kept in order', () {
    final r = parse('Sub A()\nTry\nFinally\nx = 1\nCatch\ny = 2\nEnd Try\n'
        'End Sub');
    expect(codesAndLines(r), ['P005@5']);
    final t = (r.unit.members.single as ProcedureDecl).body.statements.single
        as TryStmt;
    expect(t.finallyBlock!.statements, hasLength(2));
  });

  test('empty single-line If is reported without breaking positions', () {
    final r = parse('Sub A()\nIf x Then If y Then \nEnd Sub');
    expect(codes(r), ['P001']);
    final s = (r.unit.members.single as ProcedureDecl).body.statements.single;
    expect(s.end, lessThanOrEqualTo('Sub A()\nIf x Then If y Then'.length));
  });

  test('statements cannot start with -, + or Not', () {
    final r = parse('Sub A()\n- x\nNot y\nEnd Sub');
    expect(codes(r), ['P005', 'P005']);
  });

  group('P023: a value and ")" both missing', () {
    for (final body in [
      'x = (1 +',
      'x = (',
      'x = ((1 + 2) *',
      'MsgBox("a" &',
      'x = Max(1,',
      'x = f('
    ]) {
      test(body, () {
        final r = parse('Sub A()\n$body\nEnd Sub');
        expect(codes(r), ['P023']);
        expect(r.diagnostics.single.line, 2);
      });
    }

    test('only the value is missing when ")" is there: P001', () {
      expect(codes(parse('Sub A()\nx = (1 + )\nEnd Sub')), ['P001']);
      expect(codes(parse('Sub A()\nx = f(1, )\nEnd Sub')), ['P001']);
    });

    test('no parenthesis open: P001', () {
      expect(codes(parse('Sub A()\nx = 1 +\nEnd Sub')), ['P001']);
    });

    test('only ")" is missing: P003', () {
      expect(codes(parse('Sub A()\nx = (1 + 2\nEnd Sub')), ['P003']);
    });

    test('Korean message', () {
      final d = parse('Sub A()\nx = (1 +\nEnd Sub').diagnostics.single;
      expect(d.formatMessage(koreanMessages),
          '여기에는 값과 ) 기호가 필요합니다. 값을 쓰고 괄호를 닫아 주세요.');
    });
  });
}
