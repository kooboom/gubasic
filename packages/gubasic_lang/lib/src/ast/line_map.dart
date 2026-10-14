/// Converts source offsets to 1-based lines and columns, counting line
/// breaks and the byte order mark exactly as the lexer does.
class LineMap {
  LineMap(String source) : _lineStarts = _computeLineStarts(source);

  final List<int> _lineStarts;

  int get lineCount => _lineStarts.length;

  /// The 1-based line and column of [offset].
  (int line, int column) locate(int offset) {
    var low = 0;
    var high = _lineStarts.length - 1;
    while (low < high) {
      final mid = (low + high + 1) >> 1;
      if (_lineStarts[mid] <= offset) {
        low = mid;
      } else {
        high = mid - 1;
      }
    }
    return (low + 1, offset - _lineStarts[low] + 1);
  }

  /// The offset where 1-based [line] starts.
  int lineStart(int line) => _lineStarts[line - 1];

  static List<int> _computeLineStarts(String source) {
    final starts = [
      if (source.isNotEmpty && source.codeUnitAt(0) == 0xFEFF) 1 else 0,
    ];
    for (var i = 0; i < source.length; i++) {
      final c = source.codeUnitAt(i);
      if (c == 0x0D) {
        if (i + 1 < source.length && source.codeUnitAt(i + 1) == 0x0A) i++;
        starts.add(i + 1);
      } else if (c == 0x0A) {
        starts.add(i + 1);
      }
    }
    return starts;
  }
}
