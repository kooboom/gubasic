import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// DialogResult (docs/DESIGN.md D103). How it runs is in the parity
/// program forms_dialogresult.
void main() {
  final form1 = readFormFile('formatVersion: 1\n', name: 'Form1').form;
  final form2 = readFormFile('formatVersion: 1\n', name: 'Form2').form;

  List<String> codes(String code1, [String code2 = '']) => [
        for (final f in compileProject([
          (file: form1, source: code1),
          (file: form2, source: code2),
        ]).forms)
          for (final d in f.program.diagnostics) '${d.code.code}@${f.name}',
      ];

  test('ShowDialog gives an Integer to compare with DialogResult', () {
    expect(
        codes('Sub Form_Load()\n'
            'If Form2.ShowDialog() = DialogResult.OK Then Debug.Print(1)\n'
            'Form2.ShowDialog\nEnd Sub\n'),
        isEmpty);
    expect(dialogResults, {'None': 0, 'OK': 1, 'Cancel': 2, 'Yes': 6, 'No': 7});
  });

  test('Me.DialogResult is set in code, not in the form file', () {
    expect(
        codes(
            '',
            'Sub Form_Load()\nMe.DialogResult = DialogResult.Yes\n'
                'End Sub\n'),
        isEmpty);
    expect(formComponent.properties['dialogresult']!.designTime, isFalse);
    expect(codes('Sub Form_Load()\nDebug.Print(DialogResult.Abort)\nEnd Sub\n'),
        ['A019@Form1']);
  });
}
