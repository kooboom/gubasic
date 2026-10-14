import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

ProcedureDecl _sub(ParseResult r) => r.unit.members.single as ProcedureDecl;

ParseResult _inSub(String body) => parse('Sub T()\n$body\nEnd Sub');

void main() {
  test('On Error → P013, line skipped', () {
    final r = _inSub('On Error Resume Next\nx = 1');
    expect(codesAndLines(r), ['P013@2']);
    expect(_sub(r).body.statements.map((s) => s.runtimeType),
        [ErrorStmt, AssignmentStmt]);
  });

  test('GoTo and GoSub → P014 naming the keyword', () {
    final r = _inSub('GoTo Done\nGoSub Work');
    expect(codes(r), ['P014', 'P014']);
    expect(r.diagnostics.map((d) => d.args.single), ['GoTo', 'GoSub']);
  });

  test('Variant → P015, still read as a type', () {
    final r = _inSub('Dim v As Variant');
    expect(codes(r), ['P015']);
    final d = (_sub(r).body.statements.single as LocalDeclStmt).declarator;
    expect(d.type!.name.name, 'Variant');
  });

  test('Class … End Class → P016, skipped as a whole', () {
    final r = parse('Class Dog\n  Dim name As String\n  Sub Bark()\n'
        '  End Sub\nEnd Class\nSub Main()\nEnd Sub');
    expect(codesAndLines(r), ['P016@1']);
    expect(r.unit.members.single.label, 'Sub Main');
  });

  test('AndAlso / OrElse → P017, read as And / Or', () {
    final r = _inSub('If a AndAlso b OrElse c Then x = 1');
    expect(codes(r), ['P017', 'P017'], reason: 'each is its own finding');
    expect(r.diagnostics.map((d) => d.args), [
      ['AndAlso', 'And'],
      ['OrElse', 'Or']
    ]);
    final s = _sub(r).body.statements.single as IfStmt;
    expect(exprToSexp(s.branches.single.condition), '(Or (And a b) c)');
    expect(codes(_inSub('x = a OrElse b')).single, 'P017');
  });

  test('While … Wend and While … End While → P018, read as Do While', () {
    for (final end in ['Wend', 'End While']) {
      final r = _inSub('While n < 10\n  n = n + 1\n$end');
      expect(codesAndLines(r), ['P018@2'], reason: end);
      final d = _sub(r).body.statements.single as DoLoopStmt;
      expect(exprToSexp(d.preCondition!.condition), '(< n 10)');
      expect(d.body.statements, hasLength(1));
    }
  });

  test('Do While … Wend → P018 at Wend', () {
    expect(codesAndLines(_inSub('Do While a\nWend')), ['P018@3']);
  });

  test('Call → P019, read as a call', () {
    final r = _inSub('Call ShowScore("Kim", 90)');
    expect(codes(r), ['P019']);
    final s = _sub(r).body.statements.single as ExpressionStmt;
    expect(exprToSexp(s.expression), '(call ShowScore "Kim" 90)');
  });

  test('Set / Let → P020, read as an assignment', () {
    final r = _inSub('Set b = New Button\nLet x = 1');
    expect(codes(r), ['P020', 'P020']);
    expect(r.diagnostics.map((d) => d.args.single), ['Set', 'Let']);
    expect(_sub(r).body.statements, everyElement(isA<AssignmentStmt>()));
  });

  test('every unsupported keyword has a parser diagnostic', () {
    const samples = {
      Keyword.kwOn: 'On Error GoTo Fail',
      Keyword.kwGoTo: 'GoTo Fail',
      Keyword.kwGoSub: 'GoSub Fail',
      Keyword.kwVariant: 'Dim v As Variant',
      Keyword.kwClass: 'Class C\nEnd Class',
      Keyword.kwAndAlso: 'x = a AndAlso b',
      Keyword.kwOrElse: 'x = a OrElse b',
      Keyword.kwWend: 'Do\nWend',
      Keyword.kwCall: 'Call F()',
      Keyword.kwSet: 'Set x = y',
      Keyword.kwLet: 'Let x = y',
    };
    final unsupported = Keyword.values
        .where((k) => k.support == KeywordSupport.unsupported)
        .toSet();
    expect(samples.keys.toSet(), unsupported);
    samples.forEach((k, body) {
      final r = _inSub(body);
      expect(r.diagnostics, hasLength(1), reason: k.spelling);
      final n = int.parse(r.diagnostics.single.code.code.substring(1));
      expect(n, inInclusiveRange(13, 20), reason: k.spelling);
    });
  });

  test('VB guidance is not limited to one per statement', () {
    final r = parse('Sub F(ByRef a As Integer) Handles b.Click\n'
        'If x AndAlso y Then GoTo Done\nEnd Sub');
    expect(codesAndLines(r), ['P021@1', 'P021@1', 'P017@2', 'P014@2']);
  });

  test('but a syntax error still allows only one diagnostic', () {
    final r = _inSub('x = (1 + ) AndAlso )');
    expect(codes(r), ['P001', 'P017']);
  });
}
