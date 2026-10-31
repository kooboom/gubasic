/// What a program puts into a PDF file (docs/DESIGN.md D117): titles,
/// paragraphs and tables, page after page. [pdfBytes] lays it out.
library;

/// One thing on a page.
sealed class PdfBlock {
  const PdfBlock();
}

/// A title: larger text, a little space under it.
class PdfTitle extends PdfBlock {
  const PdfTitle(this.text);

  final String text;
}

/// A paragraph, broken into lines to fit the page; a line break in it
/// starts a new line.
class PdfParagraph extends PdfBlock {
  const PdfParagraph(this.text);

  final String text;
}

/// A table of text with its header row, which is drawn again at the top of
/// each page the table goes on to.
class PdfTable extends PdfBlock {
  PdfTable(List<String> headers, List<List<String>> rows)
      : headers = List.unmodifiable(headers),
        rows = List.unmodifiable(
            [for (final r in rows) List<String>.unmodifiable(r)]);

  final List<String> headers;
  final List<List<String>> rows;
}

/// The program's `NewPage()`: what follows starts on a new page.
class PdfPageBreak extends PdfBlock {
  const PdfPageBreak();
}

/// The letter sizes a PdfDocument starts with, in points (D117).
const pdfTitleSize = 18.0;
const pdfTextSize = 11.0;
const pdfTableSize = 10.0;

/// The smallest and largest letter size a PdfDocument takes (D118).
const pdfMinSize = 4.0;
const pdfMaxSize = 72.0;

/// A program's `PdfDocument`: what it has added so far, and how its pages
/// and letters are (D118): pages on their side when [landscape].
class GbPdfDocument {
  final blocks = <PdfBlock>[];
  var landscape = false;
  var titleSize = pdfTitleSize;
  var textSize = pdfTextSize;
  var tableSize = pdfTableSize;

  /// A copy of what it holds now.
  GbPdfDocument copy() => GbPdfDocument()
    ..blocks.addAll(blocks)
    ..landscape = landscape
    ..titleSize = titleSize
    ..textSize = textSize
    ..tableSize = tableSize;

  /// The document as a parity transcript tells it: what is not as at
  /// first in parentheses, then each block in square brackets.
  String describe() => [
        if (_settings() case final s?) '($s)',
        for (final b in blocks)
          switch (b) {
            PdfTitle(:final text) => '[title $text]',
            PdfParagraph(:final text) =>
              '[text ${text.replaceAll('\r', '\\r').replaceAll('\n', '\\n')}]',
            PdfTable(:final headers, :final rows) =>
              '[table ${headers.join('|')}; '
                  '${[for (final r in rows) r.join('|')].join('; ')}]',
            PdfPageBreak() => '[new page]',
          },
      ].join(' ');

  String? _settings() {
    String n(double v) => v == v.roundToDouble() ? '${v.toInt()}' : '$v';
    final s = [
      if (landscape) 'landscape',
      if (titleSize != pdfTitleSize) 'title ${n(titleSize)}',
      if (textSize != pdfTextSize) 'text ${n(textSize)}',
      if (tableSize != pdfTableSize) 'table ${n(tableSize)}',
    ];
    return s.isEmpty ? null : s.join(', ');
  }
}
