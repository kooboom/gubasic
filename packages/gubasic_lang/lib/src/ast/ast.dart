import '../lexer/keyword.dart';

/// A node of the GuBASIC syntax tree.
///
/// Every node records where it came from: [start] and [end] are source
/// offsets (UTF-16 code units, end exclusive). Use `LineMap` to turn them
/// into lines and columns. A node created during error recovery may be
/// empty (`start == end`).
sealed class Node {
  const Node(this.start, this.end);

  final int start;
  final int end;

  /// A one-line description used by the AST printer and the playground.
  String get label;

  /// Child nodes, in source order.
  List<Node> get children;
}

/// A name as written in the source (spelling preserved).
class Identifier extends Node {
  const Identifier(this.name, super.start, super.end);

  final String name;

  @override
  String get label => name;

  @override
  List<Node> get children => const [];
}

// ---------------------------------------------------------------------------
// File level

/// One source file (a form's code or a module).
class CompilationUnit extends Node {
  const CompilationUnit(this.members, super.start, super.end);

  final List<Member> members;

  @override
  String get label => 'CompilationUnit';

  @override
  List<Node> get children => members;
}

sealed class Member extends Node {
  const Member(super.start, super.end);
}

/// `Dim`, `Private`, `Public` or `Const` outside a procedure.
class FieldDecl extends Member {
  const FieldDecl(
      this.modifier, this.isConst, this.declarator, super.start, super.end);

  /// `kwDim`, `kwPrivate`, `kwPublic`, or null for a bare `Const`.
  final Keyword? modifier;
  final bool isConst;
  final VariableDeclarator declarator;

  @override
  String get label => [
        'Field',
        if (modifier != null) modifier!.spelling,
        if (isConst) 'Const',
      ].join(' ');

  @override
  List<Node> get children => [declarator];
}

/// `Sub` or `Function`.
class ProcedureDecl extends Member {
  const ProcedureDecl({
    required this.modifier,
    required this.isFunction,
    required this.name,
    required this.parameters,
    required this.returnType,
    required this.handles,
    required this.body,
    required int start,
    required int end,
  }) : super(start, end);

  /// `kwPublic`, `kwPrivate`, or null.
  final Keyword? modifier;
  final bool isFunction;
  final Identifier name;
  final List<Parameter> parameters;
  final TypeRef? returnType;
  final HandlesClause? handles;
  final Block body;

  @override
  String get label => [
        if (modifier != null) modifier!.spelling,
        isFunction ? 'Function' : 'Sub',
        name.name,
      ].join(' ');

  @override
  List<Node> get children => [
        ...parameters,
        if (returnType != null) returnType!,
        if (handles != null) handles!,
        body,
      ];
}

/// A statement written outside any procedure (reported as P008). Kept so
/// that tools can still show it.
class InvalidMember extends Member {
  InvalidMember(this.statement) : super(statement.start, statement.end);

  final Stmt statement;

  @override
  String get label => 'InvalidMember';

  @override
  List<Node> get children => [statement];
}

class Parameter extends Node {
  const Parameter({
    required this.isOptional,
    required this.passing,
    required this.name,
    required this.isArray,
    required this.type,
    required this.defaultValue,
    required int start,
    required int end,
  }) : super(start, end);

  final bool isOptional;

  /// `kwByVal`, `kwByRef`, or null (by value).
  final Keyword? passing;
  final Identifier name;
  final bool isArray;
  final TypeRef? type;
  final Expr? defaultValue;

  @override
  String get label => [
        'Param',
        if (isOptional) 'Optional',
        if (passing != null) passing!.spelling,
        '${name.name}${isArray ? '()' : ''}',
      ].join(' ');

  @override
  List<Node> get children => [
        if (type != null) type!,
        if (defaultValue != null) defaultValue!,
      ];
}

/// A type name, with `(Of …)` arguments: `Integer`, `List(Of String)`.
class TypeRef extends Node {
  const TypeRef(this.name, this.typeArguments, super.start, super.end);

  final Identifier name;
  final List<TypeRef> typeArguments;

  @override
  String get label => 'Type ${name.name}';

  @override
  List<Node> get children => typeArguments;
}

/// `Handles btnSave.Click, mnuSave.Click` (stage 2).
class HandlesClause extends Node {
  const HandlesClause(this.events, super.start, super.end);

  final List<MemberExpr> events;

  @override
  String get label => 'Handles';

  @override
  List<Node> get children => events;
}

/// The part of a declaration after the keyword:
/// `name[(bound)] [As [New] Type[(args)]] [= initializer]`.
class VariableDeclarator extends Node {
  const VariableDeclarator({
    required this.name,
    required this.isArray,
    required this.arrayBound,
    required this.type,
    required this.isNew,
    required this.newArguments,
    required this.initializer,
    required int start,
    required int end,
  }) : super(start, end);

  final Identifier name;

  /// True for `a()` and `a(5)`.
  final bool isArray;

  /// The upper bound in `Dim a(5)`; null for `Dim a()`.
  final Expr? arrayBound;
  final TypeRef? type;

  /// `As New Type`.
  final bool isNew;
  final List<Expr>? newArguments;
  final Expr? initializer;

  @override
  String get label => [
        'Declarator',
        '${name.name}${isArray ? '()' : ''}',
        if (isNew) 'New',
      ].join(' ');

  @override
  List<Node> get children => [
        if (arrayBound != null) arrayBound!,
        if (type != null) type!,
        ...?newArguments,
        if (initializer != null) initializer!,
      ];
}

// ---------------------------------------------------------------------------
// Statements

/// A sequence of statements. [kind] names its role for display
/// (`Body`, `Then`, `Else`, `Finally`, …).
class Block extends Node {
  const Block(this.kind, this.statements, super.start, super.end);

  final String kind;
  final List<Stmt> statements;

  @override
  String get label => kind;

  @override
  List<Node> get children => statements;
}

sealed class Stmt extends Node {
  const Stmt(super.start, super.end);
}

/// `Dim`, `Static` or `Const` inside a procedure.
class LocalDeclStmt extends Stmt {
  const LocalDeclStmt(this.kind, this.declarator, super.start, super.end);

  /// `kwDim`, `kwStatic` or `kwConst`.
  final Keyword kind;
  final VariableDeclarator declarator;

  @override
  String get label => kind.spelling;

  @override
  List<Node> get children => [declarator];
}

/// `target = value`.
class AssignmentStmt extends Stmt {
  const AssignmentStmt(this.target, this.value, super.start, super.end);

  final Expr target;
  final Expr value;

  @override
  String get label => 'Assign';

  @override
  List<Node> get children => [target, value];
}

/// A call used as a statement: `MsgBox("Hi")`, `Form2.Show`, `DoEvents`.
class ExpressionStmt extends Stmt {
  const ExpressionStmt(this.expression, super.start, super.end);

  final Expr expression;

  @override
  String get label => 'Call';

  @override
  List<Node> get children => [expression];
}

class IfStmt extends Stmt {
  const IfStmt(
      this.branches, this.elseBlock, this.isSingleLine, super.start, super.end);

  /// The `If` branch followed by any `ElseIf` branches.
  final List<IfBranch> branches;
  final Block? elseBlock;

  /// `If x Then y = 1 Else y = 2` on one line.
  final bool isSingleLine;

  @override
  String get label => isSingleLine ? 'If (single line)' : 'If';

  @override
  List<Node> get children => [...branches, if (elseBlock != null) elseBlock!];
}

class IfBranch extends Node {
  const IfBranch(this.condition, this.body, super.start, super.end);

  final Expr condition;
  final Block body;

  @override
  String get label => 'Branch';

  @override
  List<Node> get children => [condition, body];
}

class SelectStmt extends Stmt {
  const SelectStmt(this.subject, this.cases, super.start, super.end);

  final Expr subject;
  final List<CaseBlock> cases;

  @override
  String get label => 'Select Case';

  @override
  List<Node> get children => [subject, ...cases];
}

class CaseBlock extends Node {
  const CaseBlock(this.clauses, this.isElse, this.body, super.start, super.end);

  final List<CaseClause> clauses;
  final bool isElse;
  final Block body;

  @override
  String get label => isElse ? 'Case Else' : 'Case';

  @override
  List<Node> get children => [...clauses, body];
}

sealed class CaseClause extends Node {
  const CaseClause(super.start, super.end);
}

/// `Case 1, 7`: each value is one clause.
class ValueClause extends CaseClause {
  const ValueClause(this.value, super.start, super.end);

  final Expr value;

  @override
  String get label => 'Value';

  @override
  List<Node> get children => [value];
}

/// `Case 2 To 6`.
class RangeClause extends CaseClause {
  const RangeClause(this.low, this.high, super.start, super.end);

  final Expr low;
  final Expr high;

  @override
  String get label => 'Range';

  @override
  List<Node> get children => [low, high];
}

/// `Case Is > 5`.
class RelationalClause extends CaseClause {
  const RelationalClause(this.operator, this.value, super.start, super.end);

  final BinaryOp operator;
  final Expr value;

  @override
  String get label => 'Is ${operator.symbol}';

  @override
  List<Node> get children => [value];
}

/// `For i = a To b [Step c] … Next [i]`.
class ForStmt extends Stmt {
  const ForStmt({
    required this.variable,
    required this.variableType,
    required this.from,
    required this.to,
    required this.step,
    required this.body,
    required this.nextName,
    required int start,
    required int end,
  }) : super(start, end);

  final Identifier variable;

  /// `For i As Integer = …`.
  final TypeRef? variableType;
  final Expr from;
  final Expr to;
  final Expr? step;
  final Block body;
  final Identifier? nextName;

  @override
  String get label => 'For ${variable.name}';

  @override
  List<Node> get children => [
        if (variableType != null) variableType!,
        from,
        to,
        if (step != null) step!,
        body,
      ];
}

/// `For Each item In items … Next [item]`.
class ForEachStmt extends Stmt {
  const ForEachStmt({
    required this.variable,
    required this.variableType,
    required this.collection,
    required this.body,
    required this.nextName,
    required int start,
    required int end,
  }) : super(start, end);

  final Identifier variable;
  final TypeRef? variableType;
  final Expr collection;
  final Block body;
  final Identifier? nextName;

  @override
  String get label => 'For Each ${variable.name}';

  @override
  List<Node> get children => [
        if (variableType != null) variableType!,
        collection,
        body,
      ];
}

/// `Do [While|Until c] … Loop [While|Until c]`. A `While … Wend` written
/// by a VB6 user is read as `Do While … Loop` (reported as P018).
class DoLoopStmt extends Stmt {
  const DoLoopStmt(
      this.preCondition, this.postCondition, this.body, super.start, super.end);

  final LoopCondition? preCondition;
  final LoopCondition? postCondition;
  final Block body;

  @override
  String get label => 'Do';

  @override
  List<Node> get children => [
        if (preCondition != null) preCondition!,
        body,
        if (postCondition != null) postCondition!,
      ];
}

class LoopCondition extends Node {
  const LoopCondition(this.isUntil, this.condition, super.start, super.end);

  final bool isUntil;
  final Expr condition;

  @override
  String get label => isUntil ? 'Until' : 'While';

  @override
  List<Node> get children => [condition];
}

/// `Exit For`, `Exit Do`, `Exit Sub`, `Exit Function`.
class ExitStmt extends Stmt {
  const ExitStmt(this.kind, super.start, super.end);

  /// `kwFor`, `kwDo`, `kwSub` or `kwFunction`.
  final Keyword kind;

  @override
  String get label => 'Exit ${kind.spelling}';

  @override
  List<Node> get children => const [];
}

class ReturnStmt extends Stmt {
  const ReturnStmt(this.value, super.start, super.end);

  final Expr? value;

  @override
  String get label => 'Return';

  @override
  List<Node> get children => [if (value != null) value!];
}

/// `End` on its own: ends the program.
class EndStmt extends Stmt {
  const EndStmt(super.start, super.end);

  @override
  String get label => 'End';

  @override
  List<Node> get children => const [];
}

class TryStmt extends Stmt {
  const TryStmt(
      this.body, this.catches, this.finallyBlock, super.start, super.end);

  final Block body;
  final List<CatchClause> catches;
  final Block? finallyBlock;

  @override
  String get label => 'Try';

  @override
  List<Node> get children =>
      [body, ...catches, if (finallyBlock != null) finallyBlock!];
}

/// `Catch [ex As Exception]`.
class CatchClause extends Node {
  const CatchClause(this.name, this.type, this.body, super.start, super.end);

  final Identifier? name;
  final TypeRef? type;
  final Block body;

  @override
  String get label => name == null ? 'Catch' : 'Catch ${name!.name}';

  @override
  List<Node> get children => [if (type != null) type!, body];
}

class ThrowStmt extends Stmt {
  const ThrowStmt(this.value, super.start, super.end);

  final Expr value;

  @override
  String get label => 'Throw';

  @override
  List<Node> get children => [value];
}

/// `ReDim [Preserve] a(bound)`.
class ReDimStmt extends Stmt {
  const ReDimStmt(this.preserve, this.name, this.bound, super.start, super.end);

  final bool preserve;
  final Identifier name;
  final Expr bound;

  @override
  String get label => 'ReDim${preserve ? ' Preserve' : ''} ${name.name}';

  @override
  List<Node> get children => [bound];
}

/// Source the parser skipped while recovering from an error.
class ErrorStmt extends Stmt {
  const ErrorStmt(super.start, super.end);

  @override
  String get label => 'Error';

  @override
  List<Node> get children => const [];
}

// ---------------------------------------------------------------------------
// Expressions

sealed class Expr extends Node {
  const Expr(super.start, super.end);
}

/// An integer literal. [text] is exact on every platform; [value] is
/// approximate on the web above 2⁵³ and null when the literal does not
/// fit in 64 bits (L006). Tools that need the exact number use [text].
class IntegerLiteral extends Expr {
  const IntegerLiteral(this.text, this.value, super.start, super.end);

  final String text;
  final int? value;

  @override
  String get label => 'Integer $text';

  @override
  List<Node> get children => const [];
}

class DoubleLiteral extends Expr {
  const DoubleLiteral(this.text, this.value, super.start, super.end);

  final String text;
  final double value;

  @override
  String get label => 'Double $text';

  @override
  List<Node> get children => const [];
}

class StringLiteral extends Expr {
  const StringLiteral(this.value, super.start, super.end);

  /// The string's content, with `""` already turned into `"`.
  final String value;

  @override
  String get label => 'String "${value.replaceAll('"', '""')}"';

  @override
  List<Node> get children => const [];
}

class BooleanLiteral extends Expr {
  const BooleanLiteral(this.value, super.start, super.end);

  final bool value;

  @override
  String get label => value ? 'True' : 'False';

  @override
  List<Node> get children => const [];
}

class NothingLiteral extends Expr {
  const NothingLiteral(super.start, super.end);

  @override
  String get label => 'Nothing';

  @override
  List<Node> get children => const [];
}

class MeExpr extends Expr {
  const MeExpr(super.start, super.end);

  @override
  String get label => 'Me';

  @override
  List<Node> get children => const [];
}

class NameExpr extends Expr {
  const NameExpr(this.name, super.start, super.end);

  final String name;

  @override
  String get label => 'Name $name';

  @override
  List<Node> get children => const [];
}

/// `target.name`.
class MemberExpr extends Expr {
  const MemberExpr(this.target, this.name, super.start, super.end);

  final Expr target;
  final Identifier name;

  @override
  String get label => 'Member .${name.name}';

  @override
  List<Node> get children => [target];
}

/// `target(arguments)`: a call or an array element. Which one is decided
/// by the analyzer, which knows what `target` is.
class InvokeExpr extends Expr {
  const InvokeExpr(this.target, this.arguments, super.start, super.end);

  final Expr target;
  final List<Expr> arguments;

  @override
  String get label => 'Invoke';

  @override
  List<Node> get children => [target, ...arguments];
}

/// `New Type[(arguments)]`.
class NewExpr extends Expr {
  const NewExpr(this.type, this.arguments, super.start, super.end);

  final TypeRef type;
  final List<Expr>? arguments;

  @override
  String get label => 'New';

  @override
  List<Node> get children => [type, ...?arguments];
}

enum UnaryOp {
  negate('-'),
  plus('+'),
  not('Not');

  const UnaryOp(this.symbol);
  final String symbol;
}

class UnaryExpr extends Expr {
  const UnaryExpr(this.operator, this.operand, super.start, super.end);

  final UnaryOp operator;
  final Expr operand;

  @override
  String get label => 'Unary ${operator.symbol}';

  @override
  List<Node> get children => [operand];
}

/// Binary operators with their precedence (higher binds tighter), as in
/// VB.NET. All are left-associative, including `^`.
enum BinaryOp {
  power('^', 12),
  multiply('*', 10),
  divide('/', 10),
  integerDivide(r'\', 9),
  modulo('Mod', 8),
  add('+', 7),
  subtract('-', 7),
  concat('&', 6),
  equal('=', 5),
  notEqual('<>', 5),
  less('<', 5),
  greater('>', 5),
  lessEqual('<=', 5),
  greaterEqual('>=', 5),
  identity('Is', 5),
  and('And', 3),
  or('Or', 2),
  xor('Xor', 1);

  const BinaryOp(this.symbol, this.precedence);
  final String symbol;
  final int precedence;

  /// Unary `-` and `+` sit between `^` and `*`; `Not` between the
  /// comparisons and `And`.
  static const unaryMinusPrecedence = 11;
  static const notPrecedence = 4;
}

class BinaryExpr extends Expr {
  const BinaryExpr(
      this.operator, this.left, this.right, super.start, super.end);

  final BinaryOp operator;
  final Expr left;
  final Expr right;

  @override
  String get label => 'Binary ${operator.symbol}';

  @override
  List<Node> get children => [left, right];
}

/// `(inner)`. Kept so that tools can reproduce the source.
class ParenExpr extends Expr {
  const ParenExpr(this.inner, super.start, super.end);

  final Expr inner;

  @override
  String get label => 'Paren';

  @override
  List<Node> get children => [inner];
}

/// A missing or unreadable expression (a diagnostic explains it).
class ErrorExpr extends Expr {
  const ErrorExpr(super.start, super.end);

  @override
  String get label => 'Error';

  @override
  List<Node> get children => const [];
}
