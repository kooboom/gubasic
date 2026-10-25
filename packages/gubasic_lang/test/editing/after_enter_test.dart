import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// [code] after Enter at its `|` (the end of a line), as the editor
/// leaves it: the ended line indented as [afterEnter] says, the new line
/// with its indentation and the caret (`|`), and any closing line.
String enter(String code, {bool closeBlock = true}) {
  final at = code.indexOf('|');
  final text = code.replaceFirst('|', '\n');
  final line = '\n'.allMatches(code.substring(0, at)).length + 1;
  final r = afterEnter(text, line, closeBlock: closeBlock);
  final lines = text.split('\n');
  if (r.indentLine case final indent?) {
    lines[line - 1] = '${' ' * indent}${lines[line - 1].trimLeft()}';
  }
  lines[line] = '${' ' * r.newIndent}|';
  if (r.closer case final closer?) {
    final own = lines[line - 1].length - lines[line - 1].trimLeft().length;
    lines.insert(line + 1, '${' ' * own}$closer');
  }
  return lines.join('\n');
}

void main() {
  group('closing lines are put in by counting the blocks', () {
    test('a nested If gets its End If, though one closes the outer If', () {
      expect(
        enter(
          'Sub W()\n    If a Then\n        If b Then|\n    End If\nEnd Sub\n',
        ),
        'Sub W()\n    If a Then\n        If b Then\n            |\n'
        '        End If\n    End If\nEnd Sub\n',
      );
    });

    test('an If inside a For, and a For inside an If', () {
      expect(
        enter(
            'Sub W()\n    For i = 1 To 3\n        If b Then|\n    Next\nEnd Sub\n'),
        'Sub W()\n    For i = 1 To 3\n        If b Then\n            |\n'
        '        End If\n    Next\nEnd Sub\n',
      );
      expect(
        enter(
            'Sub W()\n    If b Then\n        For i = 1 To 3|\n    End If\nEnd Sub\n'),
        'Sub W()\n    If b Then\n        For i = 1 To 3\n            |\n'
        '        Next\n    End If\nEnd Sub\n',
      );
    });

    test('a Select Case, and an If in one of its cases', () {
      expect(
        enter('Sub W()\n    Select Case x|\nEnd Sub\n'),
        'Sub W()\n    Select Case x\n        |\n    End Select\nEnd Sub\n',
      );
      expect(
        enter(
          'Sub W()\n    Select Case x\n        Case 1\n            If b Then|\n'
          '    End Select\nEnd Sub\n',
        ),
        'Sub W()\n    Select Case x\n        Case 1\n            If b Then\n'
        '                |\n            End If\n    End Select\nEnd Sub\n',
      );
    });

    test('two blocks open, the inner one is closed first', () {
      expect(
        enter('Sub W()\n    If a Then\n        If b Then|\nEnd Sub\n'),
        'Sub W()\n    If a Then\n        If b Then\n            |\n'
        '        End If\nEnd Sub\n',
      );
    });

    test(
        'nothing for a block already closed, a single-line If, or with '
        'closeBlock false', () {
      expect(
        enter('Sub W()\n    If a Then|\n    End If\nEnd Sub\n'),
        'Sub W()\n    If a Then\n        |\n    End If\nEnd Sub\n',
      );
      expect(
        enter('Sub W()\n    If a Then x = 1|\nEnd Sub\n'),
        'Sub W()\n    If a Then x = 1\n    |\nEnd Sub\n',
      );
      expect(
        enter('Sub W()\n    If a Then|\nEnd Sub\n', closeBlock: false),
        'Sub W()\n    If a Then\n    |\nEnd Sub\n',
      );
    });

    test('Sub and Function, before the next procedure', () {
      expect(
        enter('Function F() As Integer|\n\nSub A()\nEnd Sub\n'),
        'Function F() As Integer\n    |\nEnd Function\n\nSub A()\nEnd Sub\n',
      );
    });
  });

  group('lines that go on with or close a block are indented as the opener',
      () {
    test('Else, ElseIf and End If', () {
      expect(
        enter('Sub W()\n    If a Then\n        x = 1\n        Else|\n'
            '    End If\nEnd Sub\n'),
        'Sub W()\n    If a Then\n        x = 1\n    Else\n        |\n'
        '    End If\nEnd Sub\n',
      );
      expect(
        enter('Sub W()\n    If a Then\n        x = 1\n        ElseIf b Then|\n'
            '    End If\nEnd Sub\n'),
        'Sub W()\n    If a Then\n        x = 1\n    ElseIf b Then\n        |\n'
        '    End If\nEnd Sub\n',
      );
      // The line after End If starts where the If did, not at 0.
      expect(
        enter(
            'Sub W()\n    If a Then\n        x = 1\n        End If|\nEnd Sub\n'),
        'Sub W()\n    If a Then\n        x = 1\n    End If\n    |\nEnd Sub\n',
      );
    });

    test('in a nested If, End If follows its own If', () {
      expect(
        enter('Sub W()\n    If a Then\n        If b Then\n            x = 1\n'
            '            End If|\n    End If\nEnd Sub\n'),
        'Sub W()\n    If a Then\n        If b Then\n            x = 1\n'
        '        End If\n        |\n    End If\nEnd Sub\n',
      );
    });

    test('Next, Loop, Case, End Select, Catch, Finally', () {
      expect(
        enter(
            'Sub W()\n    For i = 1 To 3\n        x = i\n        Next|\nEnd Sub\n'),
        'Sub W()\n    For i = 1 To 3\n        x = i\n    Next\n    |\nEnd Sub\n',
      );
      expect(
        enter('Sub W()\n    Do\n        x = 1\n        Loop|\nEnd Sub\n'),
        'Sub W()\n    Do\n        x = 1\n    Loop\n    |\nEnd Sub\n',
      );
      expect(
        enter(
            'Sub W()\n    Select Case x\n    Case 1|\n    End Select\nEnd Sub\n'),
        'Sub W()\n    Select Case x\n    Case 1\n        |\n    End Select\nEnd Sub\n',
      );
      expect(
        enter(
            'Sub W()\n    Try\n        x = 1\n        Catch|\n    End Try\nEnd Sub\n'),
        'Sub W()\n    Try\n        x = 1\n    Catch\n        |\n    End Try\nEnd Sub\n',
      );
      expect(
        enter(
            'Sub W()\n    Try\n        x = 1\n        Finally|\n    End Try\nEnd Sub\n'),
        'Sub W()\n    Try\n        x = 1\n    Finally\n        |\n    End Try\nEnd Sub\n',
      );
      expect(
        enter(
            'Sub W()\n    Select Case x\n        Case 1\n            End Select|\nEnd Sub\n'),
        'Sub W()\n    Select Case x\n        Case 1\n    End Select\n    |\nEnd Sub\n',
      );
    });

    test('a closing line with no block, and other lines, keep their place', () {
      expect(
        enter('Sub W()\n        Next|\nEnd Sub\n'),
        'Sub W()\n        Next\n        |\nEnd Sub\n',
      );
      expect(
        enter('Sub W()\n      x = 1|\nEnd Sub\n'),
        'Sub W()\n      x = 1\n      |\nEnd Sub\n',
      );
    });
  });
}
