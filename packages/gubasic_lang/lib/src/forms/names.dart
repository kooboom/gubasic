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
/// The designer renames a control to a name only when this is empty for
/// it (D35): the code's own use of that name would otherwise turn into a
/// use of the control.
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

/// What deleting control [name] leaves in [source] (D64): the lines that
/// use the control itself (`btnOk.Caption = ""`, `Me.btnOk`), which would
/// be errors without it, and the names of its handlers (`btnOk_Click`),
/// which would stay but never run. A member after `.` other than `Me.` is
/// someone else's (`lblMessage.btnOk`), and is not counted.
({List<int> lines, List<String> handlers}) usesOfControl(
  String source,
  String name,
) {
  final lower = name.toLowerCase();
  final tokens = lex(source).tokens;
  final lines = <int>{};
  final handlers = <String>[];
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind != TokenKind.identifier) continue;
    final text = t.text.toLowerCase();
    if (text == lower) {
      if (i > 0 &&
          tokens[i - 1].kind == TokenKind.dot &&
          (i < 2 || tokens[i - 2].keyword != Keyword.kwMe)) {
        continue;
      }
      lines.add(t.line);
    } else if (text.startsWith('${lower}_') &&
        i > 0 &&
        tokens[i - 1].keyword == Keyword.kwSub) {
      handlers.add(t.text);
    }
  }
  return (lines: lines.toList()..sort(), handlers: handlers);
}

/// [source] with the control [name] renamed to [newName] (D39): every
/// identifier that is [name], in any case, or starts with it and `_` (the
/// control's handlers, `btnHello_Click`), gets [newName] in place of that
/// part. Comments, strings and other names, such as `btnHelloWorld`, stay
/// as they are, and so does a name after `.` other than `Me.`: there it is
/// a property or a member (`lblMessage.Caption`), not the control.
///
/// The designer renames only to a name the code does not use
/// ([linesUsingName] is empty), so renaming back gives the code again,
/// with [name] spelled one way.
String renameInCode(String source, String name, String newName) {
  final lower = name.toLowerCase();
  final tokens = lex(source).tokens;
  final out = StringBuffer();
  var at = 0;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind != TokenKind.identifier) continue;
    final text = t.text.toLowerCase();
    if (text != lower && !text.startsWith('${lower}_')) continue;
    if (i > 0 && tokens[i - 1].kind == TokenKind.dot) {
      if (i < 2 || tokens[i - 2].keyword != Keyword.kwMe) continue;
    }
    out
      ..write(source.substring(at, t.offset))
      ..write(newName);
    at = t.offset + name.length;
  }
  out.write(source.substring(at));
  return out.toString();
}

/// The lines of [source] that use form [name] (D88): the name, in any
/// case, not after a `.` (`Form2.Show`, `Form2.txtName.Text`). Comments,
/// strings and members of the same name (`lblForm2.Form2`) do not count.
/// Sorted, each line once. The IDE deletes a form only after saying where
/// the code uses it, and renames one only to a name the code does not use.
List<int> formUses(String source, String name) {
  final lower = name.toLowerCase();
  final tokens = lex(source).tokens;
  final lines = <int>{
    for (var i = 0; i < tokens.length; i++)
      if (tokens[i].kind == TokenKind.identifier &&
          tokens[i].text.toLowerCase() == lower &&
          (i == 0 || tokens[i - 1].kind != TokenKind.dot))
        tokens[i].line,
  };
  return lines.toList()..sort();
}

/// [source] with form [name] renamed to [newName] (D88): each use
/// [formUses] finds gets [newName]. Handlers of the form's own events are
/// named `Form_Load` whatever the form's name, so they stay.
String renameFormInCode(String source, String name, String newName) {
  final lower = name.toLowerCase();
  final tokens = lex(source).tokens;
  final out = StringBuffer();
  var at = 0;
  for (var i = 0; i < tokens.length; i++) {
    final t = tokens[i];
    if (t.kind != TokenKind.identifier || t.text.toLowerCase() != lower) {
      continue;
    }
    if (i > 0 && tokens[i - 1].kind == TokenKind.dot) continue;
    out
      ..write(source.substring(at, t.offset))
      ..write(newName);
    at = t.offset + t.text.length;
  }
  out.write(source.substring(at));
  return out.toString();
}
