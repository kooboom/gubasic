import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// What a stretch of code is, for its colour.
enum CodeKind { plain, keyword, string, comment, number, control }

/// The colour of each [CodeKind] but plain.
const codeColors = {
  CodeKind.keyword: Color(0xFF1F3FBF),
  CodeKind.string: Color(0xFFA31515),
  CodeKind.comment: Color(0xFF2E7D32),
  CodeKind.number: Color(0xFF0E7C7B),
  CodeKind.control: Color(0xFF7B3FA0),
};

/// The kind of each UTF-16 unit of [text], from the lexer (D36): the
/// same tokens the interpreter reads, so the colours never disagree with
/// the language. [controls] are the form's control names, in lower case.
Uint8List codeKinds(String text, Set<String> controls) {
  final kinds = Uint8List(text.length);
  void mark(int start, int length, CodeKind kind) {
    final end = (start + length).clamp(0, text.length);
    for (var i = start.clamp(0, text.length); i < end; i++) {
      kinds[i] = kind.index;
    }
  }

  final lexed = lex(text);
  for (final t in lexed.tokens) {
    final kind = switch (t.kind) {
      TokenKind.keyword => CodeKind.keyword,
      TokenKind.stringLiteral => CodeKind.string,
      TokenKind.integerLiteral || TokenKind.doubleLiteral => CodeKind.number,
      TokenKind.identifier when controls.contains(t.text.toLowerCase()) =>
        CodeKind.control,
      // A string not closed yet, being typed.
      TokenKind.error when t.text.startsWith('"') => CodeKind.string,
      _ => null,
    };
    if (kind != null) mark(t.offset, t.text.length, kind);
  }
  for (final c in lexed.comments) {
    mark(c.offset, c.text.length, CodeKind.comment);
  }
  return kinds;
}

/// The code editor's text: coloured as the lexer reads it, with the part
/// the input method is still composing underlined as usual.
class CodeController extends TextEditingController {
  CodeController({super.text});

  /// The form's control names, in lower case.
  Set<String> get controls => _controls;
  set controls(Set<String> names) {
    if (setEquals(names, _controls)) return;
    _controls = names;
    _span = null;
  }

  Set<String> _controls = const {};

  // The last span built, and what it was built from: a frame may ask
  // more than once, and the IDE redraws around the editor at each key.
  TextSpan? _span;
  TextEditingValue? _spanValue;
  TextStyle? _spanStyle;
  bool? _spanComposing;

  @override
  TextSpan buildTextSpan({
    required BuildContext context,
    TextStyle? style,
    required bool withComposing,
  }) {
    if (_span != null &&
        _spanValue!.text == value.text &&
        _spanValue!.composing == value.composing &&
        _spanStyle == style &&
        _spanComposing == withComposing) {
      return _span!;
    }
    _spanValue = value;
    _spanStyle = style;
    _spanComposing = withComposing;
    return _span = _build(style, withComposing);
  }

  TextSpan _build(TextStyle? style, bool withComposing) {
    final text = this.text;
    final kinds = codeKinds(text, controls);
    final composing = withComposing && value.isComposingRangeValid
        ? value.composing
        : TextRange.empty;
    bool composed(int i) =>
        composing.isValid && i >= composing.start && i < composing.end;
    final spans = <TextSpan>[];
    var start = 0;
    for (var i = 1; i <= text.length; i++) {
      if (i < text.length &&
          kinds[i] == kinds[start] &&
          composed(i) == composed(start)) {
        continue;
      }
      final kind = CodeKind.values[kinds[start]];
      spans.add(
        TextSpan(
          text: text.substring(start, i),
          style: TextStyle(
            color: codeColors[kind],
            decoration: composed(start) ? TextDecoration.underline : null,
          ),
        ),
      );
      start = i;
    }
    return TextSpan(style: style, children: spans);
  }
}
