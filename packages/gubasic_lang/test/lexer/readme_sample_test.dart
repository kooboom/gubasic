import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../helpers.dart';

/// The "A taste of the language" example from README.md.
const _sample = '''
Dim clickCount As Integer

Sub Form_Load()
    lblMessage.Caption = "Press the button"
End Sub

Sub btnHello_Click()
    clickCount = clickCount + 1
    Dim name = InputBox("What is your name?")
    MsgBox("Hello, " & name & "! (" & clickCount & ")")
End Sub
''';

void main() {
  test('README sample lexes without diagnostics into the expected tokens', () {
    final r = lexClean(_sample);
    expect(r.comments, isEmpty);

    final actual = [
      for (final t in r.tokens)
        switch (t.kind) {
          TokenKind.keyword => 'kw:${t.keyword!.spelling}',
          TokenKind.identifier => 'id:${t.text}',
          TokenKind.stringLiteral => 'str:${t.value}',
          TokenKind.integerLiteral => 'int:${t.value}',
          TokenKind.newline => 'NL',
          TokenKind.eof => 'EOF',
          _ => t.text,
        },
    ];

    expect(actual, [
      // Dim clickCount As Integer
      'kw:Dim', 'id:clickCount', 'kw:As', 'id:Integer', 'NL',
      // Sub Form_Load()
      'kw:Sub', 'id:Form_Load', '(', ')', 'NL',
      // lblMessage.Caption = "Press the button"
      'id:lblMessage', '.', 'id:Caption', '=', 'str:Press the button', 'NL',
      // End Sub
      'kw:End', 'kw:Sub', 'NL',
      // Sub btnHello_Click()
      'kw:Sub', 'id:btnHello_Click', '(', ')', 'NL',
      // clickCount = clickCount + 1
      'id:clickCount', '=', 'id:clickCount', '+', 'int:1', 'NL',
      // Dim name = InputBox("What is your name?")
      'kw:Dim', 'id:name', '=', 'id:InputBox', '(',
      'str:What is your name?', ')', 'NL',
      // MsgBox("Hello, " & name & "! (" & clickCount & ")")
      'id:MsgBox', '(', 'str:Hello, ', '&', 'id:name', '&', 'str:! (', '&',
      'id:clickCount', '&', 'str:)', ')', 'NL',
      // End Sub
      'kw:End', 'kw:Sub', 'NL',
      'EOF',
    ]);
  });

  test('README sample positions', () {
    final tokens = lexClean(_sample).tokens;
    final caption = tokens.firstWhere((t) => t.text == 'Caption');
    expect([caption.line, caption.column], [4, 16]);
    final lastEnd = tokens.lastWhere((t) => t.isKeyword(Keyword.kwEnd));
    expect([lastEnd.line, lastEnd.column], [11, 1]);
  });
}
