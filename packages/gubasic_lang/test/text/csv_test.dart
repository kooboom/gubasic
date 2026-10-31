import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/src/text/csv.dart';
import 'package:test/test.dart';

/// CSV text and tables (docs/DESIGN.md D114).
void main() {
  test('cells, quotes, line breaks in quotes, any line break', () {
    expect(parseCsv('a,b\r\n"c, d","e ""f"""\n"g\nh",\r'), [
      ['a', 'b'],
      ['c, d', 'e "f"'],
      ['g\nh', ''],
    ]);
    expect(parseCsv(''), isEmpty);
    expect(parseCsv('a,,\n'), [
      ['a', '', ''],
    ]);
  });

  test('written as Excel writes it: quoted where needed, CRLF', () {
    expect(
      writeCsv([
        ['이름', '점수'],
        ['박, 둘', '8"5'],
        [' 앞', 'a\nb'],
      ]),
      '이름,점수\r\n"박, 둘","8""5"\r\n" 앞","a\nb"\r\n',
    );
    final rows = [
      ['x', 'y,z'],
      ['"', ''],
    ];
    expect(parseCsv(writeCsv(rows)), rows);
  });

  test('a table: the first line the header, rows as wide as the widest', () {
    final t = GbTable.fromCsv(parseCsv('이름,점수\n김,90,extra\n이\n'));
    expect(t.headers, ['이름', '점수', '']);
    expect(t.rows, [
      ['김', '90', 'extra'],
      ['이', '', ''],
    ]);
    expect(t.column('점수'), 1);
    expect(t.column('없음'), -1);
  });

  test('only Cell and Header can be assigned to', () {
    final form = readFormFile(
      'formatVersion: 1\ncontrols:\n  - { name: btnGo, type: Button }\n',
      name: 'Form1',
    ).form;
    List<String> codes(String line) => [
          for (final d in compile(
            'Sub btnGo_Click()\nDim t As New Table\n$line\nEnd Sub\n',
            form: form,
          ).diagnostics)
            d.code.code,
        ];
    expect(codes('t.Cell(0, "이름") = 3'), isEmpty);
    expect(codes('t.Header(0) = "x"'), isEmpty);
    expect(codes('t.Column("x") = 1'), ['A020']);
    expect(codes('t.RowCount = 3'), ['A034']);
  });
}
