import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Grids (docs/DESIGN.md D116). How one runs is in the parity program
/// grid_scores.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: grdScores, type: Grid }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('Cell and Header take a value; RowCount and ColumnCount do not', () {
    expect(
        _codes('Sub grdScores_Changed()\n'
            'grdScores.Cell(grdScores.Row, "점수") = 0\n'
            'grdScores.Header(0) = "이름"\n'
            'Debug.Print(grdScores.RowCount * grdScores.ColumnCount)\n'
            'End Sub\n'),
        isEmpty);
    expect(_codes('Sub F()\ngrdScores.RowCount = 3\nEnd Sub\n'),
        [isA<String>().having((c) => c.endsWith('@2'), 'line', isTrue)]);
  });

  test('A036 and A051: Visual Basic\'s names for its members and events', () {
    final ds = compile(
            'Sub grdScores_CellValueChanged()\n'
            'Debug.Print(grdScores.TextMatrix(0, 0) & grdScores.Rows)\n'
            'End Sub\n',
            form: _form)
        .diagnostics;
    expect([for (final d in ds) d.code.code], containsAll(['A051', 'A036']));
    expect(ds.map((d) => d.message).join('\n'),
        allOf(contains('Changed'), contains('Cell'), contains('RowCount')));
  });

  test('A056 and F020: DataGridView and MSFlexGrid are Grid', () {
    expect(builtinComponents['grid']!.aliases, ['DataGridView', 'MSFlexGrid']);
    for (final name in ['DataGridView', 'MSFlexGrid']) {
      final a = compile('Dim g As $name\nSub F()\ng = Nothing\nEnd Sub\n',
              form: _form)
          .diagnostics
          .firstWhere((d) => d.code.code == 'A056');
      expect((a.code.code, a.message),
          ('A056', 'GuBASIC calls the $name type Grid: write Grid.'));
      final f = readFormFile(
              'formatVersion: 1\ncontrols:\n  - { name: g1, type: $name }\n',
              name: 'Form1')
          .diagnostics
          .single;
      expect((f.code.code, f.message),
          ('F020', 'GuBASIC calls the $name control Grid: write type: Grid.'));
    }
  });
}
