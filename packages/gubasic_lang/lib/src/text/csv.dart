/// CSV text as rows of cells, and back (docs/DESIGN.md D114), as RFC 4180
/// writes it: cells split by commas, rows by line breaks; a cell in double
/// quotes may hold commas, line breaks and `""` for a quote.
///
/// [parseCsv] takes `\r\n`, `\n` or `\r` between rows, and leaves out
/// the empty row after a last line break. [writeCsv] quotes a cell that
/// holds a comma, a quote, a line break, or space at either end, and ends
/// each row with `\r\n`, as Excel does.
List<List<String>> parseCsv(String text) {
  final rows = <List<String>>[];
  var row = <String>[];
  final cell = StringBuffer();
  var quoted = false;
  var i = 0;
  void endCell() {
    row.add('$cell');
    cell.clear();
  }

  void endRow() {
    endCell();
    rows.add(row);
    row = <String>[];
  }

  while (i < text.length) {
    final c = text[i];
    if (quoted) {
      if (c == '"') {
        if (i + 1 < text.length && text[i + 1] == '"') {
          cell.write('"');
          i++;
        } else {
          quoted = false;
        }
      } else {
        cell.write(c);
      }
    } else if (c == '"' && cell.isEmpty) {
      quoted = true;
    } else if (c == ',') {
      endCell();
    } else if (c == '\r' || c == '\n') {
      endRow();
      if (c == '\r' && i + 1 < text.length && text[i + 1] == '\n') i++;
    } else {
      cell.write(c);
    }
    i++;
  }
  if (cell.isNotEmpty || row.isNotEmpty || quoted) endRow();
  return rows;
}

String writeCsv(List<List<String>> rows) {
  String cell(String s) => s.contains(RegExp('[",\r\n]')) || s != s.trim()
      ? '"${s.replaceAll('"', '""')}"'
      : s;
  return [for (final r in rows) '${r.map(cell).join(',')}\r\n'].join();
}
