import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  group('assignment and calls', () {
    test('assignment targets: name, member, element', () {
      final s = statements('x = 1\nlbl.Caption = "a"\na(i) = 2');
      expect(s.cast<AssignmentStmt>().map((a) => exprToSexp(a.target)),
          ['x', 'lbl.Caption', '(call a i)']);
    });

    test('x = y = z assigns the comparison', () {
      final a = statement('x = y = z') as AssignmentStmt;
      expect(exprToSexp(a.target), 'x');
      expect(exprToSexp(a.value), '(= y z)');
    });

    test('calls with and without arguments (F4)', () {
      final s = statements('MsgBox("Hi")\nForm2.Show\nDoEvents\n'
          'Me.Controls.Add(b)');
      expect(s.cast<ExpressionStmt>().map((e) => exprToSexp(e.expression)), [
        '(call MsgBox "Hi")',
        'Form2.Show',
        'DoEvents',
        '(call Me.Controls.Add b)',
      ]);
    });

    test('a call with arguments but no parentheses reports P011', () {
      final r = parse('Sub T()\nMsgBox "Hi", 1\nEnd Sub');
      expect(codes(r), ['P011']);
      final e = (r.unit.members.single as ProcedureDecl).body.statements.single
          as ExpressionStmt;
      expect(exprToSexp(e.expression), '(call MsgBox "Hi" 1)');
    });

    test('End on its own ends the program', () {
      expect(statement('End'), isA<EndStmt>());
    });
  });

  group('If', () {
    test('If / ElseIf / Else / End If', () {
      final s = statement('If score >= 90 Then\n  grade = "A"\n'
          'ElseIf score >= 80 Then\n  grade = "B"\n'
          'Else\n  grade = "C"\nEnd If') as IfStmt;
      expect(s.isSingleLine, isFalse);
      expect(s.branches.map((b) => exprToSexp(b.condition)),
          ['(>= score 90)', '(>= score 80)']);
      expect(s.elseBlock!.statements, hasLength(1));
    });

    test('F1: single-line If, with and without Else', () {
      final a = statement('If x > 0 Then y = 1') as IfStmt;
      expect(a.isSingleLine, isTrue);
      expect(a.elseBlock, isNull);
      final b = statement('If x > 0 Then y = 1 Else y = 2') as IfStmt;
      expect(b.isSingleLine, isTrue);
      expect(b.branches.single.body.statements.single, isA<AssignmentStmt>());
      expect(b.elseBlock!.statements.single, isA<AssignmentStmt>());
      final c = statement('If done Then Exit Sub') as IfStmt;
      expect(c.branches.single.body.statements.single, isA<ExitStmt>());
    });

    test('single-line If followed by more statements', () {
      final s = statements('If a Then b = 1\nc = 2');
      expect(s.map((x) => x.runtimeType), [IfStmt, AssignmentStmt]);
    });

    test('nested single-line If', () {
      final s = statement('If a Then If b Then c = 1 Else c = 2') as IfStmt;
      final inner = s.branches.single.body.statements.single as IfStmt;
      expect(inner.isSingleLine, isTrue);
      expect(inner.elseBlock, isNotNull, reason: 'Else binds to the inner If');
      expect(s.elseBlock, isNull);
    });

    test('a block statement in a single-line If is reported', () {
      final r = parse('Sub T()\nIf a Then For i = 1 To 2\nEnd Sub');
      expect(codes(r), ['P005']);
    });

    test('missing Then reports P002', () {
      final r = parse('Sub T()\nIf a\nEnd If\nEnd Sub');
      expect(codes(r), ['P002']);
      expect(r.diagnostics.single.args, ['Then']);
    });
  });

  group('Select Case', () {
    test('values, ranges, Is and Else', () {
      final s = statement('Select Case day\n'
          '  Case 1, 7\n    kind = "Weekend"\n'
          '  Case 2 To 6\n    kind = "Weekday"\n'
          '  Case Is > 7\n    kind = "Invalid"\n'
          '  Case Else\n    kind = "?"\n'
          'End Select') as SelectStmt;
      expect(exprToSexp(s.subject), 'day');
      expect(
          s.cases.map((c) => c.label), ['Case', 'Case', 'Case', 'Case Else']);
      expect(s.cases[0].clauses.map((c) => c.runtimeType),
          [ValueClause, ValueClause]);
      expect(s.cases[1].clauses.single, isA<RangeClause>());
      final rel = s.cases[2].clauses.single as RelationalClause;
      expect(rel.operator, BinaryOp.greater);
      expect(s.cases.map((c) => c.body.statements.length), [1, 1, 1, 1]);
    });

    test('a statement before the first Case reports P002', () {
      final r = parse('Sub T()\nSelect Case x\ny = 1\nCase 1\nEnd Select\n'
          'End Sub');
      expect(codesAndLines(r), ['P002@3']);
    });

    test('nested Select inside a Case', () {
      final s = statement('Select Case a\nCase 1\n'
          'Select Case b\nCase 2\nx = 1\nEnd Select\n'
          'Case 3\nEnd Select') as SelectStmt;
      expect(s.cases, hasLength(2));
      expect(s.cases[0].body.statements.single, isA<SelectStmt>());
    });
  });

  group('loops', () {
    test('For with Step and Next name', () {
      final s = statement('For i = 1 To 10 Step 2\n  x = i\nNext i') as ForStmt;
      expect(s.variable.name, 'i');
      expect(exprToSexp(s.from), '1');
      expect(exprToSexp(s.to), '10');
      expect(exprToSexp(s.step!), '2');
      expect(s.nextName!.name, 'i');
    });

    test('F3: For with As Type', () {
      final s = statement('For i As Integer = 0 To 9\nNext') as ForStmt;
      expect(s.variableType!.name.name, 'Integer');
      expect(s.nextName, isNull);
    });

    test('For Each, with and without As', () {
      final a = statement('For Each n In names\n  lst.AddItem(n)\nNext')
          as ForEachStmt;
      expect(a.variable.name, 'n');
      expect(exprToSexp(a.collection), 'names');
      final b =
          statement('For Each n As String In names\nNext n') as ForEachStmt;
      expect(b.variableType!.name.name, 'String');
    });

    test('Next with another name reports P010 (case-insensitive match ok)', () {
      expect(statements('For i = 1 To 2\nNext I'), hasLength(1));
      final r = parse('Sub T()\nFor i = 1 To 2\nNext j\nEnd Sub');
      expect(codes(r), ['P010']);
      expect(r.diagnostics.single.args, ['j', 'i']);
    });

    test('the four Do forms', () {
      final s = statements('Do While a\nLoop\nDo Until a\nLoop\n'
              'Do\nLoop While a\nDo\nLoop Until a\nDo\n  DoEvents\nLoop')
          .cast<DoLoopStmt>()
          .toList();
      expect(s.map((d) => d.preCondition?.label),
          ['While', 'Until', null, null, null]);
      expect(s.map((d) => d.postCondition?.label),
          [null, null, 'While', 'Until', null]);
    });

    test('a condition on both ends reports P005', () {
      expect(
          codes(parse('Sub T()\nDo While a\nLoop Until b\nEnd Sub')), ['P005']);
    });

    test('Exit For / Do / Sub / Function', () {
      final s = statements('Exit For\nExit Do\nExit Sub\nExit Function');
      expect(s.cast<ExitStmt>().map((e) => e.kind),
          [Keyword.kwFor, Keyword.kwDo, Keyword.kwSub, Keyword.kwFunction]);
      expect(codes(parse('Sub T()\nExit While\nEnd Sub')), ['P002']);
    });
  });

  group('errors and arrays', () {
    test('Try / Catch / Finally', () {
      final s = statement('Try\n  x = 1\nCatch ex As Exception\n'
          '  MsgBox(ex.Message)\nFinally\n  y = 2\nEnd Try') as TryStmt;
      expect(s.body.statements, hasLength(1));
      final c = s.catches.single;
      expect(c.name!.name, 'ex');
      expect(c.type!.name.name, 'Exception');
      expect(s.finallyBlock!.statements, hasLength(1));
    });

    test('Catch without a variable; Try without Catch', () {
      final a = statement('Try\nCatch\nEnd Try') as TryStmt;
      expect(a.catches.single.name, isNull);
      final b = statement('Try\nFinally\nEnd Try') as TryStmt;
      expect(b.catches, isEmpty);
      expect(b.finallyBlock, isNotNull);
    });

    test('Throw New Exception', () {
      final s = statement('Throw New Exception("message")') as ThrowStmt;
      expect(exprToSexp(s.value), '(new Exception "message")');
    });

    test('ReDim and ReDim Preserve', () {
      final s = statements('ReDim a(9)\nReDim Preserve a(19)')
          .cast<ReDimStmt>()
          .toList();
      expect(s.map((r) => r.preserve), [false, true]);
      expect(s.map((r) => exprToSexp(r.bound)), ['9', '19']);
    });

    test('Return without a value', () {
      expect((statement('Return') as ReturnStmt).value, isNull);
    });
  });
}
