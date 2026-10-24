import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Draws the pictures of examples/quiz, so that they are the project's
/// own, free of anyone's copyright, and can be drawn again the same.
///
///     dart run tool/draw_quiz_pictures.dart
void main() {
  _draw('triangle.png', sides: 3, fill: 0xFF4F8EF7, line: 0xFF1F3F7A);
  _draw('pentagon.png', sides: 5, fill: 0xFFF2A93B, line: 0xFF8A5300);
}

const _size = 160;

/// Draws a regular polygon of [sides] with a point at the top, filled with
/// [fill] (0xAARRGGBB) and edged with [line], on a transparent square.
void _draw(
  String name, {
  required int sides,
  required int fill,
  required int line,
}) {
  const radius = 72.0, width = 6.0, samples = 4;
  // A triangle's centre is low in it: moved down, it fills the square.
  final centre = Point(_size / 2, _size / 2 + (sides == 3 ? 18.0 : 4.0));
  final outer = _polygon(sides, centre, radius);
  final inner = _polygon(sides, centre, radius - width / cos(pi / sides));
  final rgba = Uint8List(_size * _size * 4);
  for (var y = 0; y < _size; y++) {
    for (var x = 0; x < _size; x++) {
      var inFill = 0, inLine = 0;
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          final p = Point(x + (sx + 0.5) / samples, y + (sy + 0.5) / samples);
          if (_inside(inner, p)) {
            inFill++;
          } else if (_inside(outer, p)) {
            inLine++;
          }
        }
      }
      final covered = inFill + inLine;
      if (covered == 0) continue;
      // The colour of what covers the pixel, as much as it covers it.
      final i = (y * _size + x) * 4;
      for (var c = 0; c < 3; c++) {
        final shift = 16 - 8 * c;
        rgba[i + c] =
            (((fill >> shift) & 0xFF) * inFill +
                ((line >> shift) & 0xFF) * inLine) ~/
            covered;
      }
      rgba[i + 3] = 255 * covered ~/ (samples * samples);
    }
  }
  File('../../examples/quiz/pictures/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(_png(rgba));
}

List<Point<double>> _polygon(int sides, Point<double> centre, double r) => [
  for (var k = 0; k < sides; k++)
    Point(
      centre.x + r * sin(2 * pi * k / sides),
      centre.y - r * cos(2 * pi * k / sides),
    ),
];

/// Whether [p] is inside the convex [polygon], whose points go clockwise
/// on the screen.
bool _inside(List<Point<double>> polygon, Point<double> p) {
  for (var k = 0; k < polygon.length; k++) {
    final a = polygon[k], b = polygon[(k + 1) % polygon.length];
    if ((b.x - a.x) * (p.y - a.y) - (b.y - a.y) * (p.x - a.x) < 0) {
      return false;
    }
  }
  return true;
}

/// A PNG file of the [_size] square [rgba]: 8 bits a channel, no filter.
Uint8List _png(Uint8List rgba) {
  final rows = BytesBuilder();
  for (var y = 0; y < _size; y++) {
    rows
      ..addByte(0)
      ..add(rgba.sublist(y * _size * 4, (y + 1) * _size * 4));
  }
  final header = ByteData(13)
    ..setUint32(0, _size)
    ..setUint32(4, _size)
    ..setUint8(8, 8) // bits a channel
    ..setUint8(9, 6); // RGBA
  return (BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(_chunk('IDAT', ZLibEncoder(level: 9).convert(rows.takeBytes())))
        ..add(_chunk('IEND', const [])))
      .takeBytes();
}

List<int> _chunk(String type, List<int> data) {
  final body = [...type.codeUnits, ...data];
  final length = ByteData(4)..setUint32(0, data.length);
  final crc = ByteData(4)..setUint32(0, _crc32(body));
  return [...length.buffer.asUint8List(), ...body, ...crc.buffer.asUint8List()];
}

int _crc32(List<int> bytes) {
  var crc = 0xFFFFFFFF;
  for (final b in bytes) {
    crc ^= b;
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}
