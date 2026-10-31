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

/// A program's `PdfDocument`: what it has added so far.
class GbPdfDocument {
  final blocks = <PdfBlock>[];

  /// The document as a parity transcript tells it: each block in square
  /// brackets.
  String describe() => [
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
}
