import 'package:test/test.dart';

import 'helpers.dart';

void main() {
  test('arithmetic follows the usual order', () {
    expect(sexp('1 + 2 * 3 ^ 2'), '(+ 1 (* 2 (^ 3 2)))');
    expect(sexp('1 - 2 - 3'), '(- (- 1 2) 3)');
    expect(sexp('8 / 4 / 2'), '(/ (/ 8 4) 2)');
  });

  test('^ is left-associative, as in VB and Excel', () {
    expect(sexp('2 ^ 3 ^ 2'), '(^ (^ 2 3) 2)');
  });

  test('unary minus binds looser than ^ and tighter than *', () {
    expect(sexp('-2 ^ 2'), '(- (^ 2 2))');
    expect(sexp('-a * b'), '(* (- a) b)');
    expect(sexp('2 ^ -1'), '(^ 2 (- 1))');
    expect(sexp('a * -b'), '(* a (- b))');
    expect(sexp('+a'), '(+ a)');
  });

  test(r'* / then \ then Mod then + -', () {
    expect(sexp(r'a \ b * c'), r'(\ a (* b c))');
    expect(sexp(r'a Mod b \ c'), r'(Mod a (\ b c))');
    expect(sexp('a + b Mod c'), '(+ a (Mod b c))');
  });

  test('& binds looser than arithmetic', () {
    expect(sexp('a & b + c'), '(& a (+ b c))');
    expect(sexp('"n=" & n * 2 & "!"'), '(& (& "n=" (* n 2)) "!")');
  });

  test('comparisons and Is share one level, left to right', () {
    expect(sexp('a & b = c'), '(= (& a b) c)');
    expect(sexp('a < b = c'), '(= (< a b) c)');
    expect(sexp('x Is Nothing = y'), '(= (Is x Nothing) y)');
    for (final op in ['=', '<>', '<', '>', '<=', '>=']) {
      expect(sexp('a $op b + 1'), '($op a (+ b 1))');
    }
  });

  test('Not binds looser than comparisons, tighter than And', () {
    expect(sexp('Not a = b And c'), '(And (Not (= a b)) c)');
    expect(sexp('Not Not a'), '(Not (Not a))');
    expect(sexp('Not x Is Nothing'), '(Not (Is x Nothing))');
  });

  test('And, then Or, then Xor', () {
    expect(sexp('a Or b And c'), '(Or a (And b c))');
    expect(sexp('a Xor b Or c'), '(Xor a (Or b c))');
    expect(sexp('x Is Nothing Or y'), '(Or (Is x Nothing) y)');
  });

  test('parentheses override precedence', () {
    expect(sexp('(1 + 2) * 3'), '(* (+ 1 2) 3)');
    expect(sexp('2 ^ (3 ^ 2)'), '(^ 2 (^ 3 2))');
  });

  test('= at the start of a statement assigns; inside it compares', () {
    expect(sexp('y = z'), '(= y z)');
  });

  test('postfix: members, calls and New', () {
    expect(sexp('a.b.c'), 'a.b.c');
    expect(sexp('f(1, g(2))'), '(call f 1 (call g 2))');
    expect(sexp('Me.Controls.Count'), 'Me.Controls.Count');
    expect(sexp('items(0).Name'), '(call items 0).Name');
    expect(sexp('New List(Of String)'), '(new List(Of String))');
    expect(sexp('New Exception("x")'), '(new Exception "x")');
    expect(sexp('f()'), '(call f)');
  });

  test('literals', () {
    expect(sexp('1.5'), '1.5');
    expect(sexp('"a""b"'), '"a"b"');
    expect(sexp('True And False'), '(And True False)');
    expect(sexp('Nothing'), 'Nothing');
  });

  test('keywords are allowed as member names after a dot', () {
    expect(sexp('x.End + y.Next + z.Step'), '(+ (+ x.End y.Next) z.Step)');
  });
}
