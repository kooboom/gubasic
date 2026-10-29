import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// MouseDown and MouseUp (docs/DESIGN.md D111). How they run is in the
/// parity program events_mouse.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblName, type: Label }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('every control seen on the form, and the form, has them', () {
    for (final c in builtinComponents.values) {
      expect(c.events.containsKey('mousedown'), c.visual, reason: c.name);
      expect(c.events.containsKey('mouseup'), c.visual, reason: c.name);
    }
    expect(
        mouseButtons, {'Left': 1048576, 'Right': 2097152, 'Middle': 4194304});
  });

  test('e.Button, e.X, e.Y and MouseButtons', () {
    expect(
        _codes('Sub lblName_MouseUp(e As MouseEventArgs)\n'
            'If e.Button = MouseButtons.Right Then Debug.Print(e.X + e.Y)\n'
            'End Sub\n'
            'Sub Form_MouseDown(e As MouseEventArgs)\nEnd Sub\n'),
        isEmpty);
    expect(_codes('Sub lblName_MouseUp()\nEnd Sub\n'), ['A032@1']);
  });

  test('A059: Visual Basic 6\'s (Button, Shift, X, Y)', () {
    final d = compile(
            'Sub Form_MouseDown(Button As Integer, Shift As Integer, '
            'X As Double, Y As Double)\nEnd Sub\n',
            form: _form)
        .diagnostics
        .single;
    expect(d.code.code, 'A059');
    expect(
        d.message,
        'GuBASIC tells a mouse event its button and place in one parameter: '
        'write Sub Form_MouseDown(e As MouseEventArgs), then read e.Button '
        '(as in e.Button = MouseButtons.Right), e.X and e.Y.');
  });
}
