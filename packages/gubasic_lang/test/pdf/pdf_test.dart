import 'dart:convert';
import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// PDF files (docs/DESIGN.md D117), in the font the IDE and the apps
/// carry.
final _fontBytes =
    File('../../apps/ide/fonts/nanumgothic/NanumGothic-Regular.ttf')
        .readAsBytesSync();
final _font = TrueTypeFont.parse(_fontBytes);

String _latin(List<int> bytes) => latin1.decode(bytes);

GbPdfDocument _scores(int rows) => GbPdfDocument()
  ..blocks.addAll([
    const PdfTitle('2학기 성적표'),
    const PdfParagraph('합계 245, 평균 81.7'),
    PdfTable([
      '이름',
      '반',
      '점수'
    ], [
      for (var i = 0; i < rows; i++) ['학생 $i', '${i % 3 + 1}반', '${50 + i}'],
    ]),
  ]);

void main() {
  test('the font: its glyphs, widths and a copy of only some of them', () {
    final ga = _font.glyphOf('가'.runes.single);
    final a = _font.glyphOf(0x41);
    expect([ga, a], everyElement(greaterThan(0)));
    expect(_font.glyphOf(0x1F600), 0, reason: 'no emoji: the missing glyph');
    final (bytes, order) = _font.subset([ga, a]);
    expect(order.take(3), [0, ga, a]);
    final copy = TrueTypeFont.parse(bytes);
    expect(copy.glyphCount, order.length);
    expect([copy.advance(1), copy.advance(2)],
        [_font.advance(ga), _font.advance(a)]);
    expect(copy.unitsPerEm, _font.unitsPerEm);
    expect(bytes.length, lessThan(20000));
  });

  test(
      'a PDF file: pages, a font of only the glyphs used, text that can be '
      'found', () {
    final bytes = pdfBytes(_scores(3), _font);
    final text = _latin(bytes);
    expect(text, startsWith('%PDF-1.4\n'));
    expect(text, endsWith('%%EOF\n'));
    expect(RegExp(r'/Type /Page ').allMatches(text), hasLength(1));
    expect(text, contains('/Subtype /CIDFontType2'));
    expect(text, contains('/ToUnicode'));
    // The cross-reference table points at each object.
    final xref = int.parse(RegExp(r'startxref\n(\d+)').firstMatch(text)![1]!);
    final offsets = RegExp(r'(\d{10}) 00000 n ')
        .allMatches(text.substring(xref))
        .map((m) => int.parse(m[1]!))
        .toList();
    for (var i = 0; i < offsets.length; i++) {
      expect(text.substring(offsets[i]), startsWith('${i + 1} 0 obj\n'));
    }
    // 가 in the ToUnicode map, as UTF-16.
    expect(text, contains('<D559>'), reason: '학');
    expect(bytes.length, lessThan(40000),
        reason: 'the font holds only the glyphs used, not its 2 MB');
  });

  test('the same document gives the same bytes', () {
    expect(pdfBytes(_scores(5), _font), pdfBytes(_scores(5), _font));
  });

  test('a long table goes on to more pages; NewPage starts one', () {
    String file(GbPdfDocument d) => _latin(pdfBytes(d, _font));
    int pages(String text) => RegExp(r'/Type /Page ').allMatches(text).length;
    expect(pages(file(_scores(100))), greaterThan(2));
    expect(
        pages(file(GbPdfDocument()
          ..blocks.addAll(const [
            PdfParagraph('one'),
            PdfPageBreak(),
            PdfParagraph('two'),
          ]))),
        2);
    expect(pages(file(GbPdfDocument())), 1, reason: 'an empty page');
  });

  test('AddTable takes a Table or a Grid', () {
    final form = readFormFile(
            'formatVersion: 1\ncontrols:\n  - { name: grdScores, type: Grid }\n'
            '  - { name: lblTotal, type: Label }\n',
            name: 'Form1')
        .form;
    List<String> codes(String body) => [
          for (final d in compile(
                  'Sub F()\nDim pdf As New PdfDocument\n$body\nEnd Sub\n',
                  form: form)
              .diagnostics)
            '${d.code.code}@${d.line}',
        ];
    expect(
        codes('pdf.AddTitle("A")\npdf.AddText("B")\npdf.AddTable(grdScores)\n'
            'pdf.AddTable(Csv.Read("a.csv"))\npdf.NewPage()\n'
            'pdf.Save("a.pdf")'),
        isEmpty);
    expect(codes('pdf.AddTable(lblTotal)'), ['A008@3']);
    expect(codes('pdf.AddTable("names")'), ['A008@3']);
  });

  test('the transcript tells what is in it', () {
    expect(
        (_scores(1)..blocks.add(const PdfPageBreak())).describe(),
        '[title 2학기 성적표] [text 합계 245, 평균 81.7] '
        '[table 이름|반|점수; 학생 0|1반|50] [new page]');
  });

  test('Landscape turns the pages; the sizes change the letters (D118)', () {
    final wide = _latin(pdfBytes(_scores(3)..landscape = true, _font));
    expect(wide, contains('/MediaBox [0 0 842 595]'));
    final big = _latin(pdfBytes(_scores(3)..titleSize = 30, _font));
    expect(big, contains('/F1 30 Tf'));
    expect(_latin(pdfBytes(_scores(3), _font)), contains('/F1 18 Tf'));
  });

  test('the properties in a program: read, set, R035 out of range', () async {
    final form = readFormFile('formatVersion: 1\n', name: 'Form1').form;
    expect(
        await runEventScript(
            'Sub Form_Load()\nDim pdf As New PdfDocument\n'
                'Debug.Print(pdf.Landscape & " " & pdf.TitleSize & " " & '
                'pdf.TextSize & " " & pdf.TableSize)\n'
                'pdf.Landscape = True\npdf.TextSize = 12\npdf.TableSize = 9.5\n'
                'pdf.Save("a.pdf")\npdf.TitleSize = 80\nEnd Sub\n',
            form,
            'Close'),
        [
          'Debug.Print: False 18 11 10',
          'Wrote a.pdf: PDF (landscape, text 12, table 9.5)',
          'Script not finished: Close was not run',
          'Error R035 @ 8',
        ]);
  });
}
