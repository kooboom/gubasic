import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// A form's KeyDown and KeyUp (docs/DESIGN.md D101). How they run is in
/// the parity programs keys_move and keys_preview.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: txtName, type: TextBox }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('Form_KeyDown and Form_KeyUp take a KeyEventArgs', () {
    expect(
        _codes('Sub Form_KeyDown(e As KeyEventArgs)\n'
            'If e.KeyCode = Keys.Left And Not e.Shift Then Debug.Print(1)\n'
            'Debug.Print(e.Control Or e.Alt)\nEnd Sub\n'
            'Sub Form_KeyUp(e As KeyEventArgs)\nEnd Sub\n'),
        isEmpty);
    expect(_codes('Sub Keyed(e As KeyEventArgs) Handles Me.KeyDown\nEnd Sub\n'),
        isEmpty);
    expect(formComponent.properties['keypreview']!.defaultValue, false);
  });

  test('written otherwise (A032), as in Visual Basic 6 (A053)', () {
    final none = compile('Sub Form_KeyDown()\nEnd Sub\n', form: _form)
        .diagnostics
        .single;
    expect(none.code.code, 'A032');
    expect(none.args.last, 'Sub Form_KeyDown(e As KeyEventArgs)');
    final vb6 = compile(
            'Sub Form_KeyDown(KeyCode As Integer, Shift As Integer)\n'
            'End Sub\n',
            form: _form)
        .diagnostics
        .single;
    expect(vb6.code.code, 'A053');
    expect(vb6.args.last, 'Sub Form_KeyDown(e As KeyEventArgs)');
    expect(
        _codes('Sub Form_KeyUp(sender As Object, e As KeyEventArgs)\n'
            'End Sub\n'),
        ['A032@1']);
  });

  test('Keys has the keys\' numbers; KeyEventArgs can only be read', () {
    expect(keyCodes['Left'], 37);
    expect(keyCodes['A'], 65);
    expect(keyCodes['D0'], 48);
    expect(keyCodes['F12'], 123);
    expect(keyCodes.containsKey('ShiftKey'), isFalse);
    expect(
        _codes('Sub Form_KeyDown(e As KeyEventArgs)\ne.KeyCode = 3\n'
            'End Sub\n'),
        ['A034@2']);
    expect(
        _codes('Sub P()\nDim n As Integer = Keys.Lefft\nDebug.Print(n)\n'
            'End Sub\n'),
        ['A035@2']);
  });
}
