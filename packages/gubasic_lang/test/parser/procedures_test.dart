import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import 'helpers.dart';

ProcedureDecl _proc(String src) =>
    parseClean(src).unit.members.single as ProcedureDecl;

void main() {
  test('Sub with parameters', () {
    final p = _proc('Sub ShowScore(name As String, score As Integer)\n'
        '    MsgBox(name & ": " & score)\n'
        'End Sub');
    expect(p.isFunction, isFalse);
    expect(p.name.name, 'ShowScore');
    expect(p.parameters.map((x) => x.name.name), ['name', 'score']);
    expect(p.parameters.map((x) => x.type!.name.name), ['String', 'Integer']);
    expect(p.body.statements.single, isA<ExpressionStmt>());
  });

  test('Function with a return type and Return', () {
    final p = _proc('Function Average(a As Integer, b As Integer) As Double\n'
        '    Return (a + b) / 2\n'
        'End Function');
    expect(p.isFunction, isTrue);
    expect(p.returnType!.name.name, 'Double');
    final r = p.body.statements.single as ReturnStmt;
    expect(exprToSexp(r.value!), '(/ (+ a b) 2)');
  });

  test('Public and Private procedures', () {
    final r = parseClean('Public Sub A()\nEnd Sub\nPrivate Function B()\n'
        'End Function');
    expect(r.unit.members.map((m) => m.label),
        ['Public Sub A', 'Private Function B']);
  });

  test('parentheses after the name may be left out', () {
    expect(_proc('Sub Main\nEnd Sub').parameters, isEmpty);
  });

  test('ByVal is the default and may be written', () {
    final p = _proc('Sub F(ByVal a As Integer, b As Integer)\nEnd Sub');
    expect(p.parameters[0].passing, Keyword.kwByVal);
    expect(p.parameters[1].passing, isNull);
  });

  test('Optional parameters with defaults; array parameters', () {
    final p = _proc('Sub F(items() As String, '
        'Optional title As String = "Info")\nEnd Sub');
    expect(p.parameters[0].isArray, isTrue);
    expect(p.parameters[1].isOptional, isTrue);
    expect(exprToSexp(p.parameters[1].defaultValue!), '"Info"');
  });

  test('ByRef (P021) is read but reported; Handles is read (D98)', () {
    final r = parse('Sub F(ByRef a As Integer)\nEnd Sub\n'
        'Sub SaveData() Handles btnSave.Click, mnuSave.Click\nEnd Sub');
    expect(codesAndLines(r), ['P021@1']);
    final procs = r.unit.members.cast<ProcedureDecl>().toList();
    expect(procs[0].parameters.single.passing, Keyword.kwByRef);
    expect(procs[1].handles!.events.map(exprToSexp),
        ['btnSave.Click', 'mnuSave.Click']);
  });

  test('As on a Sub is reported', () {
    expect(codes(parse('Sub F() As Integer\nEnd Sub')), ['P005']);
  });

  test('End Function closing a Sub reports P002', () {
    final r = parse('Sub F()\nEnd Function');
    expect(codes(r), ['P002']);
    expect(r.diagnostics.single.args, ['End Sub']);
  });

  test('statements outside procedures report P008 and are kept', () {
    final r = parse('x = 1\nMsgBox("hi")\n');
    expect(codesAndLines(r), ['P008@1', 'P008@2']);
    expect(r.unit.members, everyElement(isA<InvalidMember>()));
  });

  test('a stray End Sub at file level reports P007', () {
    expect(codes(parse('End Sub')), ['P007']);
  });
}
