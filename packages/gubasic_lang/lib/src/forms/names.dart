import '../lexer/keyword.dart';
import '../lexer/lexer.dart';
import '../lexer/token.dart';

final _namePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

/// Whether [name] can name a control or a form: an ASCII identifier
/// (docs/LANGUAGE.md §1), not a keyword, and not `Form`, which handlers
/// of the form's own events use (`Form_Load`).
bool isUsableName(String name) =>
    _namePattern.hasMatch(name) &&
    Keyword.lookup(name) == null &&
    name.toLowerCase() != 'form';

/// The lines of [source] where [name] is used, in any case: as a name
/// (`Button1.Caption`, `Me.Button1`) or at the start of one followed by
/// `_` (`Button1_Click`, the control's handlers). Comments and strings do
/// not count. Sorted, each line once.
///
/// The designer renames a control only when this is empty (D35): the code
/// would otherwise refer to a control that is no longer there, or a
/// handler would no longer run.
List<int> linesUsingName(String source, String name) {
  final lower = name.toLowerCase();
  final lines = <int>{
    for (final t in lex(source).tokens)
      if (t.kind == TokenKind.identifier &&
          (t.text.toLowerCase() == lower ||
              t.text.toLowerCase().startsWith('${lower}_')))
        t.line,
  };
  return lines.toList()..sort();
}
