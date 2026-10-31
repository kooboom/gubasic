import 'dart:convert';
import 'dart:typed_data';

import 'cp949_table.dart';

/// How a text file's bytes are read and written (docs/DESIGN.md D113).
///
/// Read: UTF-8, with or without a byte order mark; bytes that are not
/// UTF-8 are code page 949, the "ANSI" text of Korean Windows, in which
/// Excel saves CSV files there. Written: UTF-8, with a byte order mark when
/// [bom] says so (for `.csv`, so that Excel reads Korean text as such).
String decodeText(List<int> bytes) {
  var start = 0;
  if (bytes.length >= 3 &&
      bytes[0] == 0xEF &&
      bytes[1] == 0xBB &&
      bytes[2] == 0xBF) {
    start = 3;
  }
  try {
    return utf8.decode(bytes.sublist(start));
  } on FormatException {
    return decodeCp949(bytes);
  }
}

/// [text] as UTF-8, after a byte order mark when [bom].
Uint8List encodeText(String text, {bool bom = false}) => Uint8List.fromList([
      if (bom) ...[0xEF, 0xBB, 0xBF],
      ...utf8.encode(text),
    ]);

/// Whether a file named [path] is written with a byte order mark: a CSV
/// file, for Excel (D113).
bool wantsBom(String path) => path.toLowerCase().endsWith('.csv');

/// [bytes] as code page 949: one byte below 0x80 is ASCII; a byte from
/// 0x81 to 0xFE starts a two-byte code; anything else, or a code that is
/// none, is U+FFFD.
String decodeCp949(List<int> bytes) {
  final out = StringBuffer();
  for (var i = 0; i < bytes.length; i++) {
    final b = bytes[i];
    if (b < 0x80) {
      out.writeCharCode(b);
    } else if (b >= 0x81 && b <= 0xFE && i + 1 < bytes.length) {
      final t = bytes[i + 1];
      if (t >= 0x41 && t <= 0xFE) {
        out.write(cp949Table[(b - 0x81) * 190 + (t - 0x41)]);
        i++;
      } else {
        out.writeCharCode(0xFFFD);
      }
    } else {
      out.writeCharCode(0xFFFD);
    }
  }
  return '$out';
}

/// [text]'s lines, as `File.ReadAllLines` gives them: split at `\r\n`,
/// `\n` or `\r`, the empty line after a last line break left out.
List<String> textLines(String text) {
  final lines = text.split(RegExp('\r\n|\n|\r'));
  if (lines.isNotEmpty && lines.last.isEmpty) lines.removeLast();
  return lines;
}
