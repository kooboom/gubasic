import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Enabled, Visible, FontSize, FontBold, ForeColor, BackColor and Color
/// (docs/DESIGN.md D137). How they run is in the parity program
/// control_look.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblName, type: Label }
  - { name: imgLogo, type: Image }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('every control seen on the form has them; an Image has no text', () {
    for (final c in [
      'button', 'label', 'textbox', 'checkbox', 'optionbutton', 'listbox', //
      'combobox', 'frame', 'grid',
    ]) {
      final props = builtinComponents[c]!.properties;
      for (final p in [
        'enabled', 'visible', 'fontsize', 'fontbold', 'forecolor', //
        'backcolor',
      ]) {
        expect(props, contains(p), reason: '$c.$p');
      }
      expect(props['fontsize']!.ambient, isTrue);
      expect(props['enabled']!.ambient, isFalse);
    }
    final image = builtinComponents['image']!.properties;
    expect(image.keys, containsAll(['enabled', 'visible', 'backcolor']));
    expect(image.keys, isNot(contains('fontsize')));
    final form = formComponent.properties;
    expect(form.keys, containsAll(['fontsize', 'fontbold', 'forecolor']));
    expect(form.keys, isNot(contains('enabled')));
    expect(form.keys, isNot(contains('visible')));
  });

  test('Color as Visual Basic .NET has it', () {
    expect(
        _codes('Sub F()\n'
            'Dim c As Color = Color.FromArgb(255, 136, 0)\n'
            'lblName.ForeColor = Color.SkyBlue\n'
            'lblName.BackColor = Color.Empty\n'
            'If c = Color.Red Or c <> lblName.ForeColor Then Debug.Print(c.R)\n'
            'imgLogo.BackColor = c\n'
            'lblName.FontSize = 12\nlblName.FontBold = True\n'
            'lblName.Enabled = False\nimgLogo.Visible = False\n'
            'Me.FontSize = 10.5\nMe.ForeColor = Color.Navy\n'
            'Debug.Print(c.Name & c.IsEmpty)\nEnd Sub\n'),
        isEmpty);
    // A colour is not a number, nor text.
    expect(_codes('Sub F()\nlblName.ForeColor = 255\nEnd Sub\n'), ['A008@2']);
    expect(_codes('Sub F()\nDebug.Print(Color.Red < Color.Blue)\nEnd Sub\n'),
        ['A013@2']);
  });

  test("Visual Basic 6's colours point to Color (A079)", () {
    final d =
        compile('Sub F()\nlblName.ForeColor = vbRed\nEnd Sub\n', form: _form)
            .diagnostics
            .single;
    expect(d.code.code, 'A079');
    expect(
        d.message,
        "vbRed is Visual Basic 6's colour. GuBASIC uses Visual Basic .NET's "
        'Color: write Color.Red.');
    expect(d.replacements, ['Color.Red']);
    expect(_codes('Sub F()\nlblName.ForeColor = RGB(1, 2, 3)\nEnd Sub\n'),
        contains('A079@2'));
  });

  test('a colour in a form file: a name or #RRGGBB (F023)', () {
    final r = readFormFile('''
formatVersion: 1
properties: { ForeColor: navy, BackColor: "#ffeecc", FontSize: 12 }
controls:
  - { name: a, type: Label, properties: { ForeColor: reddish } }
  - { name: b, type: Label, properties: { FontSize: 500 } }
''', name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'),
        ['F023@4', 'F012@5']);
    expect(r.form.valueOf('ForeColor'), 'Navy');
    expect(r.form.valueOf('BackColor'), '#FFEECC');
    expect(r.form.valueOf('FontSize'), 12.0);
    expect(r.form.valueOf('FontBold'), unset);
    expect(writeFormFile(r.form), contains('BackColor: "#FFEECC"'));
  });
}
