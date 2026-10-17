import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/code/handlers.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';

void main() {
  final hello = exampleProjects['hello']!['Form1.gbas']!;

  test("the procedures of hello's code", () {
    final procs = proceduresOf(hello);
    expect(procs.map((p) => p.name), ['Form_Load', 'btnHello_Click']);
    final load = procs.first;
    expect(hello.substring(load.start, load.bodyStart), 'Sub Form_Load()\n');
    expect(hello.substring(load.end).startsWith('End Sub'), isTrue);
  });

  test('a handler is found in any case; comments and strings do not count', () {
    const code =
        "' Sub btnOk_Click() in a comment\n"
        'x = "Sub btnOk_Click()"\n'
        'Private Sub BTNOK_CLICK()\n'
        '    x = 1\n'
        'End Sub\n';
    final p = procedureNamed(code, 'btnOk_Click')!;
    expect(code.substring(p.start, p.bodyStart), 'Private Sub BTNOK_CLICK()\n');
    expect(code.substring(caretIn(code, p) - 9, caretIn(code, p)), '    x = 1');
    expect(procedureNamed(code, 'btnCancel_Click'), isNull);
  });

  test('a new handler goes at the end, after an empty line', () {
    final added = withHandler(hello, 'Button1_Click()');
    expect(added.text, '$hello\nSub Button1_Click()\n    \nEnd Sub\n');
    expect(
      added.text.substring(0, added.caret).endsWith('Click()\n    '),
      isTrue,
    );
    expect(procedureNamed(added.text, 'button1_click'), isNotNull);

    expect(
      withHandler('', 'Form_Load()').text,
      'Sub Form_Load()\n    \nEnd Sub\n',
    );
    expect(
      withHandler('x = 1', 'Form_Load()').text,
      'x = 1\n\nSub Form_Load()\n    \nEnd Sub\n',
    );
  });

  test('a procedure being written has no End yet', () {
    const code = 'Sub a()\n    x = 1\n';
    final p = procedureNamed(code, 'a')!;
    expect(p.end, code.length);
    expect(p.contains(code.length), isTrue);
  });
}
