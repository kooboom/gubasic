import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// OptionButton and ComboBox (docs/DESIGN.md D104), and the names other
/// versions of BASIC give control types. How they run is in the parity
/// programs events_option and events_combobox.
void main() {
  final form = readFormFile('''
formatVersion: 1
controls:
  - { name: optA, type: OptionButton }
  - { name: cmbCity, type: ComboBox }
''', name: 'Form1').form;

  List<String> codes(String source) => [
        for (final d in compile(source, form: form).diagnostics)
          '${d.code.code}@${d.line}',
      ];

  test('their members, as a CheckBox\'s and a ListBox\'s', () {
    expect(
        codes('Sub optA_Changed()\nIf optA.Checked Then cmbCity.AddItem("x")\n'
            'cmbCity.ListIndex = cmbCity.ListCount - 1\n'
            'Debug.Print(cmbCity.Text & cmbCity.List(0))\nEnd Sub\n'
            'Sub cmbCity_Changed()\nEnd Sub\n'),
        isEmpty);
    expect(codes('Sub P()\ncmbCity.Text = "x"\nEnd Sub\n'), ['A034@2']);
    expect(codes('Sub optA_Click()\nEnd Sub\n'), ['A051@1']);
    expect(codes('Sub cmbCity_SelectedIndexChanged()\nEnd Sub\n'), ['A051@1']);
    expect(codes('Sub P()\nDebug.Print(optA.Value)\nEnd Sub\n'), ['A036@2']);
  });

  test('a type under another version\'s name (A056, F020)', () {
    final r = compile(
        'Sub P()\nDim r As RadioButton = optA\nr.Checked = True\n'
        'Dim b As CommandButton\nb = Nothing\nEnd Sub\n',
        form: form);
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'),
        ['A056@2', 'A056@4']);
    expect(r.diagnostics.first.replacements, ['OptionButton']);
    expect(
        r.diagnostics.first.message,
        'GuBASIC calls the RadioButton type OptionButton: write '
        'OptionButton.');
    final file = readFormFile(
        'formatVersion: 1\ncontrols:\n'
        '  - { name: optB, type: RadioButton }\n'
        '  - { name: picA, type: PictureBox }\n',
        name: 'Form1');
    expect(file.diagnostics.map((d) => '${d.code.code} ${d.args}'), [
      'F020 [RadioButton, OptionButton]',
      'F020 [PictureBox, Image]',
    ]);
  });
}
