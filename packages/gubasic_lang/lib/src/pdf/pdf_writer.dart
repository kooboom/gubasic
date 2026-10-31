import 'dart:convert';
import 'dart:typed_data';

import 'pdf_document.dart';
import 'truetype.dart';

/// A4, in points (1/72 inch), and the margin around what is written.
const pdfPageWidth = 595.0;
const pdfPageHeight = 842.0;
const pdfMargin = 56.0;

const _titleSize = 18.0;
const _textSize = 11.0;
const _tableSize = 10.0;
const _cellPadding = 4.0;

/// [document] as the bytes of a PDF file (docs/DESIGN.md D117), its text
/// in [font]: A4 pages, titles, paragraphs broken into lines, tables as
/// wide as the page whose header row is drawn again on each page they go
/// on to. The font goes in
/// with only the glyphs the text uses, and with what each one is as text,
/// so that a viewer can find and copy it. The same document and font give
/// the same bytes.
Uint8List pdfBytes(GbPdfDocument document, TrueTypeFont font) =>
    _Writer(font).write(document);

/// A run of text at a place on a page: x, and y of its baseline.
typedef _Run = ({double x, double y, double size, String text});

class _Page {
  final runs = <_Run>[];

  /// Cells: x, y of the bottom, width, height, and whether a header's.
  final boxes = <(double, double, double, double, bool)>[];
}

class _Writer {
  _Writer(this.font);

  final TrueTypeFont font;
  final pages = <_Page>[_Page()];

  /// Where the next block starts, from the bottom of the page.
  double y = pdfPageHeight - pdfMargin;
  bool pageEmpty = true;

  static const _width = pdfPageWidth - 2 * pdfMargin;

  double _em(double size) => size / font.unitsPerEm;
  double ascent(double size) => font.ascent * _em(size);
  double lineHeight(double size) => (font.ascent - font.descent) * _em(size);

  double measure(String text, double size) {
    var units = 0;
    for (final c in text.runes) {
      units += font.advance(font.glyphOf(c));
    }
    return units * _em(size);
  }

  void newPage() {
    pages.add(_Page());
    y = pdfPageHeight - pdfMargin;
    pageEmpty = true;
  }

  /// Makes room for [height] on this page, or goes on to the next one.
  void room(double height) {
    if (!pageEmpty && y - height < pdfMargin) newPage();
  }

  /// [text] broken into lines no wider than [width]: at its line breaks,
  /// then after the last space that fits, or else between characters.
  List<String> lines(String text, double size, double width) {
    final out = <String>[];
    for (final paragraph in text
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .replaceAll('\t', '    ')
        .split('\n')) {
      var line = <int>[];
      var lineWidth = 0.0;
      for (final c in paragraph.runes) {
        final w = font.advance(font.glyphOf(c)) * _em(size);
        if (line.isNotEmpty && lineWidth + w > width + 0.01 && c != 0x20) {
          final space = line.lastIndexOf(0x20);
          var rest = <int>[];
          if (space > 0) {
            rest = line.sublist(space + 1);
            line = line.sublist(0, space);
          }
          out.add(String.fromCharCodes(line).trimRight());
          line = rest;
          lineWidth = measure(String.fromCharCodes(line), size);
        }
        line.add(c);
        lineWidth += w;
      }
      out.add(String.fromCharCodes(line).trimRight());
    }
    return out;
  }

  void paragraph(String text, double size, {double after = 6}) {
    final h = lineHeight(size) * 1.25;
    for (final line in lines(text, size, _width)) {
      room(h);
      pages.last.runs
          .add((x: pdfMargin, y: y - ascent(size), size: size, text: line));
      y -= h;
      pageEmpty = false;
    }
    y -= after;
  }

  void table(PdfTable t) {
    final columns = t.headers.length;
    if (columns == 0) return;
    const size = _tableSize;
    final natural = List.filled(columns, 2 * _cellPadding);
    for (final row in [t.headers, ...t.rows]) {
      for (var c = 0; c < columns && c < row.length; c++) {
        final w = measure(row[c], size) + 2 * _cellPadding;
        if (w > natural[c]) natural[c] = w;
      }
    }
    final total = natural.fold(0.0, (a, b) => a + b);
    // As wide as the page, each column as much wider or narrower as its
    // widest text says.
    final widths = [for (final w in natural) w * _width / total];
    final h = lineHeight(size) * 1.2;

    (List<List<String>>, double) layout(List<String> row) {
      final cells = [
        for (var c = 0; c < columns; c++)
          lines(
              c < row.length ? row[c] : '', size, widths[c] - 2 * _cellPadding),
      ];
      final most = cells.fold(1, (m, l) => l.length > m ? l.length : m);
      return (cells, most * h + 2 * _cellPadding);
    }

    void draw(List<List<String>> cells, double height, bool header) {
      var x = pdfMargin;
      for (var c = 0; c < columns; c++) {
        pages.last.boxes.add((x, y - height, widths[c], height, header));
        var lineY = y - _cellPadding - ascent(size);
        for (final line in cells[c]) {
          pages.last.runs
              .add((x: x + _cellPadding, y: lineY, size: size, text: line));
          lineY -= h;
        }
        x += widths[c];
      }
      y -= height;
      pageEmpty = false;
    }

    final (headerCells, headerHeight) = layout(t.headers);
    room(headerHeight + (t.rows.isEmpty ? 0 : layout(t.rows.first).$2));
    draw(headerCells, headerHeight, true);
    for (final row in t.rows) {
      final (cells, height) = layout(row);
      if (y - height < pdfMargin) {
        newPage();
        draw(headerCells, headerHeight, true);
      }
      draw(cells, height, false);
    }
    y -= 10;
  }

  Uint8List write(GbPdfDocument document) {
    for (final block in document.blocks) {
      switch (block) {
        case PdfTitle(:final text):
          paragraph(text, _titleSize, after: 8);
        case PdfParagraph(:final text):
          paragraph(text, _textSize);
        case PdfTable():
          table(block);
        case PdfPageBreak():
          newPage();
      }
    }
    return _file();
  }

  Uint8List _file() {
    // The glyphs, in the order they first come, and the text each shows.
    final used = <int>[];
    final shows = <int, int>{};
    for (final page in pages) {
      for (final run in page.runs) {
        for (final c in run.text.runes) {
          final g = font.glyphOf(c);
          if (g != 0 && !shows.containsKey(g)) {
            used.add(g);
            shows[g] = c;
          }
        }
      }
    }
    final (subset, order) = font.subset(used);
    final number = {for (var i = 0; i < order.length; i++) order[i]: i};

    final objects = <List<int>>[];
    int add(List<int> bytes) {
      objects.add(bytes);
      return objects.length;
    }

    List<int> text(String s) => latin1.encode(s);
    List<int> stream(String dictionary, List<int> data) => [
          ...text('<< $dictionary /Length ${data.length} >>\nstream\n'),
          ...data,
          ...text('\nendstream'),
        ];
    String hex(int v) => v.toRadixString(16).toUpperCase().padLeft(4, '0');

    // 1 and 2: the catalog and the page tree, written last.
    add(const []);
    add(const []);
    final tag = _tag(order);
    final file = add(stream('/Length1 ${subset.length}', subset));
    final b = [for (final v in font.bbox) (v * 1000 / font.unitsPerEm).round()];
    final descriptor = add(text('<< /Type /FontDescriptor '
        '/FontName /$tag+NanumGothic /Flags 4 '
        '/FontBBox [${b.join(' ')}] /ItalicAngle 0 '
        '/Ascent ${(font.ascent * 1000 / font.unitsPerEm).round()} '
        '/Descent ${(font.descent * 1000 / font.unitsPerEm).round()} '
        '/CapHeight ${(font.ascent * 700 / font.unitsPerEm).round()} '
        '/StemV 80 /FontFile2 $file 0 R >>'));
    final widths = [
      for (final g in order) (font.advance(g) * 1000 / font.unitsPerEm).round(),
    ];
    final cid = add(text('<< /Type /Font /Subtype /CIDFontType2 '
        '/BaseFont /$tag+NanumGothic '
        '/CIDSystemInfo << /Registry (Adobe) /Ordering (Identity) '
        '/Supplement 0 >> /FontDescriptor $descriptor 0 R '
        '/W [0 [${widths.join(' ')}]] /CIDToGIDMap /Identity >>'));
    final map = StringBuffer('/CIDInit /ProcSet findresource begin\n'
        '12 dict begin\nbegincmap\n'
        '/CIDSystemInfo << /Registry (Adobe) /Ordering (UCS) '
        '/Supplement 0 >> def\n/CMapName /Adobe-Identity-UCS def\n'
        '/CMapType 2 def\n1 begincodespacerange\n<0000> <FFFF>\n'
        'endcodespacerange\n');
    final pairs = [
      for (var i = 1; i < order.length; i++)
        if (shows[order[i]] case final c?) (i, c),
    ];
    for (var at = 0; at < pairs.length; at += 100) {
      final chunk = pairs.skip(at).take(100).toList();
      map.write('${chunk.length} beginbfchar\n');
      for (final (i, c) in chunk) {
        final units = String.fromCharCode(c).codeUnits.map(hex).join();
        map.write('<${hex(i)}> <$units>\n');
      }
      map.write('endbfchar\n');
    }
    map.write('endcmap\nCMapName currentdict /CMap defineresource pop\n'
        'end\nend');
    final unicode = add(stream('', text('$map')));
    final type0 = add(text('<< /Type /Font /Subtype /Type0 '
        '/BaseFont /$tag+NanumGothic /Encoding /Identity-H '
        '/DescendantFonts [$cid 0 R] /ToUnicode $unicode 0 R >>'));

    String n(double v) {
      final s = v.toStringAsFixed(2);
      return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
    }

    final kids = <int>[];
    for (final page in pages) {
      final content = StringBuffer();
      for (final (x, y, w, h, header) in page.boxes) {
        if (header) {
          content.write('0.92 g ${n(x)} ${n(y)} ${n(w)} ${n(h)} re f\n');
        }
      }
      if (page.boxes.isNotEmpty) content.write('0.5 w 0.6 G\n');
      for (final (x, y, w, h, _) in page.boxes) {
        content.write('${n(x)} ${n(y)} ${n(w)} ${n(h)} re S\n');
      }
      content.write('0 g\n');
      for (final run in page.runs) {
        if (run.text.isEmpty) continue;
        final glyphs = [
          for (final c in run.text.runes) hex(number[font.glyphOf(c)] ?? 0),
        ].join();
        content.write('BT /F1 ${n(run.size)} Tf ${n(run.x)} ${n(run.y)} Td '
            '<$glyphs> Tj ET\n');
      }
      final contents = add(stream('', text('$content')));
      kids.add(add(text('<< /Type /Page /Parent 2 0 R '
          '/MediaBox [0 0 ${n(pdfPageWidth)} ${n(pdfPageHeight)}] '
          '/Resources << /Font << /F1 $type0 0 R >> >> '
          '/Contents $contents 0 R >>')));
    }
    objects[0] = text('<< /Type /Catalog /Pages 2 0 R >>');
    objects[1] =
        text('<< /Type /Pages /Kids [${kids.map((k) => '$k 0 R').join(' ')}] '
            '/Count ${kids.length} >>');
    final info = add(text('<< /Producer (GuBASIC) >>'));

    final out = BytesBuilder()
      ..add(text('%PDF-1.4\n'))
      ..add(const [0x25, 0xE2, 0xE3, 0xCF, 0xD3, 0x0A]);
    final offsets = <int>[];
    for (var i = 0; i < objects.length; i++) {
      offsets.add(out.length);
      out
        ..add(text('${i + 1} 0 obj\n'))
        ..add(objects[i])
        ..add(text('\nendobj\n'));
    }
    final xref = out.length;
    out.add(text('xref\n0 ${objects.length + 1}\n0000000000 65535 f \n'));
    for (final o in offsets) {
      out.add(text('${'$o'.padLeft(10, '0')} 00000 n \n'));
    }
    out.add(text('trailer\n<< /Size ${objects.length + 1} /Root 1 0 R '
        '/Info $info 0 R >>\nstartxref\n$xref\n%%EOF\n'));
    return out.toBytes();
  }

  /// Six capital letters for the subset's name, from its glyphs, as PDF
  /// names a font that holds only some of its glyphs.
  static String _tag(List<int> glyphs) {
    // Small enough numbers to come out the same in a browser.
    var h = 17;
    for (final g in glyphs) {
      h = (h * 31 + g) % 308915776; // 26^6
    }
    return String.fromCharCodes([
      for (var i = 0; i < 6; i++, h ~/= 26) 65 + h % 26,
    ]);
  }
}
