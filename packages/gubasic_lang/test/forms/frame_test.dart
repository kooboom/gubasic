import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// Frames (docs/DESIGN.md D105): the controls inside one are written under
/// its own `controls:`. How their OptionButtons and Anchors behave is in
/// the parity program events_frame.
const _nested = '''
formatVersion: 2
controls:
  - name: fraSize
    type: Frame
    properties:
      Caption: Size
      Width: 180
    controls:
      - name: optSmall
        type: OptionButton
        properties:
          Checked: true
      - name: fraInner
        type: Frame
        controls:
          - name: lblDeep
            type: Label
  - name: btnOk
    type: Button
''';

void main() {
  test('a Frame in its component.yaml: it holds controls', () {
    final frame = builtinComponents['frame']!;
    expect(frame.container, isTrue);
    expect(frame.defaultEvent, 'Click');
    expect(frame.aliases, ['GroupBox']);
    expect(builtinComponents['button']!.container, isFalse);
  });

  test('the controls inside a Frame follow it, each with its Frame', () {
    final r = readFormFile(_nested, name: 'Form1');
    expect(r.diagnostics, isEmpty);
    expect([
      for (final c in r.form.controls) '${c.name} in ${c.container}'
    ], [
      'fraSize in null',
      'optSmall in fraSize',
      'fraInner in fraSize',
      'lblDeep in fraInner',
      'btnOk in null',
    ]);
    expect(r.form.inside(null).map((c) => c.name), ['fraSize', 'btnOk']);
    expect(
        r.form.inside('FRASIZE').map((c) => c.name), ['optSmall', 'fraInner']);
  });

  test(
      'written back the same, as version 2 only when a Frame holds '
      'controls', () {
    final form = readFormFile(_nested, name: 'Form1').form;
    expect(writeFormFile(form), _nested);
    final flat = readFormFile(
            'formatVersion: 1\ncontrols:\n  - { name: fraSize, type: Frame }\n',
            name: 'Form1')
        .form;
    expect(writeFormFile(flat),
        'formatVersion: 1\ncontrols:\n  - name: fraSize\n    type: Frame\n');
  });

  test('F021: only a Frame holds controls; names are unique across them', () {
    final r = readFormFile('''
formatVersion: 2
controls:
  - name: btnOk
    type: Button
    controls:
      - { name: lblIn, type: Label }
  - name: fraA
    type: Frame
    controls:
      - { name: btnOk, type: Button }
''', name: 'Form1');
    expect([for (final d in r.diagnostics) '${d.code.code}@${d.line}'],
        ['F021@6', 'F007@10']);
    expect(
        r.diagnostics.first.message,
        'btnOk is not a Frame, so it holds no controls: move them under the '
        'controls: of the form or of a Frame.');
    expect(r.form.controls.map((c) => c.name), ['btnOk', 'fraA']);
    expect(
        readFormFile(
                'formatVersion: 1\ncontrols:\n  - { name: g, type: GroupBox }\n',
                name: 'F')
            .diagnostics
            .single
            .code
            .code,
        'F020');
  });

  test('R023: a Frame that holds controls cannot be removed', () async {
    final form = readFormFile(_nested, name: 'Form1').form;
    final lines = await runEventScript(
        'Sub btnOk_Click()\nMe.Controls.Remove(lblDeep)\n'
            'Me.Controls.Remove(fraInner)\nDebug.Print("out")\n'
            'Me.Controls.Remove(fraSize)\nEnd Sub\n',
        form,
        'btnOk.Click');
    expect(lines, [
      '> btnOk.Click',
      'Remove lblDeep',
      'Remove fraInner',
      'Debug.Print: out',
      'Error R023 @ 5',
    ]);
  });
}
