import 'ast.dart';
import 'line_map.dart';

/// Renders [node] as an indented tree, one node per line. With [lineMap],
/// each line ends with the node's range as `[line:col-line:col]`.
String astToText(Node node, {LineMap? lineMap}) {
  final out = StringBuffer();
  void visit(Node n, int depth) {
    out
      ..write('  ' * depth)
      ..write(n.label);
    if (lineMap != null) {
      final (sl, sc) = lineMap.locate(n.start);
      final (el, ec) = lineMap.locate(n.end);
      out.write(' [$sl:$sc-$el:$ec]');
    }
    out.writeln();
    for (final child in n.children) {
      visit(child, depth + 1);
    }
  }

  visit(node, 0);
  return out.toString();
}

/// A compact, fully parenthesised form of an expression, for tests:
/// `1 + 2 * 3` → `(+ 1 (* 2 3))`.
String exprToSexp(Expr e) => switch (e) {
      IntegerLiteral(:final text) || DoubleLiteral(:final text) => text,
      StringLiteral(:final value) => '"$value"',
      DateLiteral(:final value) => '#$value#',
      BooleanLiteral(:final value) => value ? 'True' : 'False',
      NothingLiteral() => 'Nothing',
      MeExpr() => 'Me',
      NameExpr(:final name) => name,
      MemberExpr(:final target, :final name) =>
        '${exprToSexp(target)}.${name.name}',
      InvokeExpr(:final target, :final arguments) => '(call ${[
          exprToSexp(target),
          ...arguments.map(exprToSexp)
        ].join(' ')})',
      NewExpr(:final type, :final arguments) =>
        '(new ${[_type(type), ...?arguments?.map(exprToSexp)].join(' ')})',
      UnaryExpr(:final operator, :final operand) =>
        '(${operator.symbol} ${exprToSexp(operand)})',
      BinaryExpr(:final operator, :final left, :final right) =>
        '(${operator.symbol} ${exprToSexp(left)} ${exprToSexp(right)})',
      ParenExpr(:final inner) => exprToSexp(inner),
      TypeOfExpr(:final operand, :final type) =>
        '(typeof ${exprToSexp(operand)} ${_type(type)})',
      CastExpr(:final operand, :final type) =>
        '(ctype ${exprToSexp(operand)} ${_type(type)})',
      ErrorExpr() => '<error>',
    };

String _type(TypeRef t) => t.typeArguments.isEmpty
    ? t.name.name
    : '${t.name.name}(Of ${t.typeArguments.map(_type).join(', ')})';
