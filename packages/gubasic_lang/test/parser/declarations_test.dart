import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

VariableDeclarator _local(String src) =>
    (statement(src) as LocalDeclStmt).declarator;

void main() {
  group('Dim inside a procedure', () {
    test('with a type', () {
      final d = _local('Dim score As Integer');
      expect(d.name.name, 'score');
      expect(d.type!.name.name, 'Integer');
      expect(d.initializer, isNull);
    });

    test('with an inferred type', () {
      final d = _local('Dim name = "Jekyll"');
      expect(d.type, isNull);
      expect(exprToSexp(d.initializer!), '"Jekyll"');
    });

    test('with a type and a value', () {
      final d = _local('Dim total As Integer = 100');
      expect(d.type!.name.name, 'Integer');
      expect(exprToSexp(d.initializer!), '100');
    });

    test('arrays: fixed upper bound and dynamic', () {
      final fixed = _local('Dim a(5) As Integer');
      expect(fixed.isArray, isTrue);
      expect(exprToSexp(fixed.arrayBound!), '5');
      final dynamic_ = _local('Dim b() As Integer');
      expect(dynamic_.isArray, isTrue);
      expect(dynamic_.arrayBound, isNull);
    });

    test('As New with generic type and arguments', () {
      final list = _local('Dim names As New List(Of String)');
      expect(list.isNew, isTrue);
      expect(list.type!.name.name, 'List');
      expect(list.type!.typeArguments.single.name.name, 'String');
      expect(list.newArguments, isNull);
      final button = _local('Dim b As New Button("OK")');
      expect(button.newArguments!.map(exprToSexp), ['"OK"']);
    });

    test('Static and Const', () {
      final s = statement('Static count As Integer') as LocalDeclStmt;
      expect(s.kind, Keyword.kwStatic);
      final c = statement('Const MaxScore As Integer = 100') as LocalDeclStmt;
      expect(c.kind, Keyword.kwConst);
      expect(exprToSexp(c.declarator.initializer!), '100');
    });

    test('names keep their spelling', () {
      expect(_local('Dim clickCount As Integer').name.name, 'clickCount');
    });
  });

  group('declarations outside procedures', () {
    test('Dim, Private, Public, Const, Public Const', () {
      final r = parseClean('Dim a As Integer\n'
          'Private b As String\n'
          'Public c As Double\n'
          'Const D = 1\n'
          'Public Const E As Integer = 2\n');
      final fields = r.unit.members.cast<FieldDecl>();
      expect(fields.map((f) => f.label), [
        'Field Dim',
        'Field Private',
        'Field Public',
        'Field Const',
        'Field Public Const',
      ]);
      expect(
          fields.map((f) => f.declarator.name.name), ['a', 'b', 'c', 'D', 'E']);
    });
  });

  group('F2: one variable per declaration', () {
    test('Dim a, b reports P012 and keeps the first variable', () {
      final r = parse('Sub T()\nDim a, b As Integer\nEnd Sub');
      expect(codesAndLines(r), ['P012@2']);
      final s = (r.unit.members.single as ProcedureDecl).body.statements.single
          as LocalDeclStmt;
      expect(s.declarator.name.name, 'a');
    });

    test('also outside procedures', () {
      expect(codes(parse('Dim a As Integer, b As Integer')), ['P012']);
    });
  });

  test('Const without a value reports P003', () {
    final r = parse('Const X As Integer');
    expect(codes(r), ['P003']);
    expect(r.diagnostics.single.args, ['=']);
  });

  test('Static outside a procedure and Public inside one report P009', () {
    expect(codes(parse('Static x As Integer')), ['P009']);
    expect(codes(parse('Sub T()\nPublic x As Integer\nEnd Sub')), ['P009']);
  });
}
