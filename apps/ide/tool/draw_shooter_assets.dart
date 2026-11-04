import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Draws the pictures and makes the sounds of examples/shooter (D138), so
/// that they are the project's own, free of anyone's copyright, and can be
/// made again the same: the ship, its shot, the two frames of an enemy,
/// the three frames of an explosion, and three WAV files synthesised here
/// (a shot, a hit, a short loop of music).
///
///     dart run tool/draw_shooter_assets.dart
void main() {
  _picture('ship.png', 32, 32, _shipAt);
  _picture('shot.png', 6, 14, _shot);
  _picture('enemy1.png', 32, 32, (p) => _enemy(p, 0));
  _picture('enemy2.png', 32, 32, (p) => _enemy(p, 1));
  for (var k = 1; k <= 3; k++) {
    _picture('boom$k.png', 32, 32, (p) => _boom(p, k));
  }
  _sound('shot.wav', 0.06, (t) => _decay(t, 0.06) * _square(t, 880));
  final random = Random(7);
  _sound(
    'hit.wav',
    0.12,
    (t) => _decay(t, 0.12) * (random.nextDouble() * 2 - 1) * 0.7,
  );
  _sound('music.wav', 1.8, _music);
}

const _ship = (0xFF4F8EF7, 0xFFDDE9FF);
const _enemyColours = (0xFFE5578E, 0xFF7A2347);
const _boomColours = (0xFFF2A93B, 0xFFFFF0A0);

/// The colour (0xAARRGGBB) at [p] of the ship, a triangle pointing up
/// with a lighter window; 0 where it is clear.
int _shipAt(Point<double> p) {
  const tip = Point(16.0, 1.0),
      left = Point(1.0, 31.0),
      right = Point(31.0, 31.0);
  if (!_inTriangle(p, tip, left, right)) return 0;
  if (p.distanceTo(const Point(16.0, 20.0)) < 4) return _ship.$2;
  return _ship.$1;
}

int _shot(Point<double> p) => p.x >= 0.5 && p.x <= 5.5 ? 0xFFFFE066 : 0;

int _enemy(Point<double> p, int frame) {
  const centre = Point(16.0, 16.0);
  final d = p.distanceTo(centre);
  // The second frame has its eyes narrowed: the picture blinks as it flies.
  final eyeHeight = frame == 0 ? 3.0 : 1.2;
  for (final eye in const [Point(11.0, 14.0), Point(21.0, 14.0)]) {
    if ((p.x - eye.x).abs() < 3 && (p.y - eye.y).abs() < eyeHeight) {
      return 0xFFFFFFFF;
    }
  }
  if (d < 14) return _enemyColours.$1;
  if (d < 15.5) return _enemyColours.$2;
  return 0;
}

int _boom(Point<double> p, int frame) {
  const centre = Point(16.0, 16.0);
  final d = p.distanceTo(centre);
  final outer = 5.0 + frame * 4.5, inner = frame == 3 ? outer - 3 : 0.0;
  if (d < inner) return 0;
  if (d < outer - 2) return _boomColours.$2;
  if (d < outer) return _boomColours.$1;
  return 0;
}

bool _inTriangle(
  Point<double> p,
  Point<double> a,
  Point<double> b,
  Point<double> c,
) {
  double side(Point<double> u, Point<double> v) =>
      (v.x - u.x) * (p.y - u.y) - (v.y - u.y) * (p.x - u.x);
  final s1 = side(a, b), s2 = side(b, c), s3 = side(c, a);
  return (s1 >= 0 && s2 >= 0 && s3 >= 0) || (s1 <= 0 && s2 <= 0 && s3 <= 0);
}

/// Writes [name], a picture of [width] x [height] whose colour at each
/// point [colourAt] gives, sampled four by four for soft edges.
void _picture(
  String name,
  int width,
  int height,
  int Function(Point<double>) colourAt,
) {
  const samples = 4;
  final rgba = Uint8List(width * height * 4);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      var covered = 0;
      final sum = [0, 0, 0];
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          final colour = colourAt(
            Point(x + (sx + 0.5) / samples, y + (sy + 0.5) / samples),
          );
          if (colour == 0) continue;
          covered++;
          for (var c = 0; c < 3; c++) {
            sum[c] += (colour >> (16 - 8 * c)) & 0xFF;
          }
        }
      }
      if (covered == 0) continue;
      final i = (y * width + x) * 4;
      for (var c = 0; c < 3; c++) {
        rgba[i + c] = sum[c] ~/ covered;
      }
      rgba[i + 3] = 255 * covered ~/ (samples * samples);
    }
  }
  File('../../examples/shooter/pictures/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(_png(rgba, width, height));
}

double _decay(double t, double length) => (1 - t / length).clamp(0, 1);
double _square(double t, double hz) => sin(t * hz * 2 * pi) > 0 ? 0.5 : -0.5;

/// A short loop: a bass note and an arpeggio over it, quiet, so that the
/// effects are heard over it.
double _music(double t) {
  const notes = [262.0, 330.0, 392.0, 330.0, 294.0, 370.0, 440.0, 370.0];
  final step = (t * 10 / 3).floor() % notes.length; // 0.3 s a note
  final within = (t * 10 / 3) - (t * 10 / 3).floor();
  final melody = sin(t * notes[step] * 2 * pi) * (1 - within) * 0.18;
  final bass =
      (sin(t * 131 * 2 * pi) > 0 ? 0.08 : -0.08) * (t % 0.6 < 0.3 ? 1 : 0.4);
  return melody + bass;
}

/// Writes [name], an 8-bit mono WAV of [seconds] at 11.025 kHz, [sample]
/// giving each moment's value from -1 to 1: small enough to go into the
/// IDE with the example (D55), and enough for a game's sounds.
void _sound(String name, double seconds, double Function(double t) sample) {
  const rate = 11025;
  final frames = (seconds * rate).round();
  final data = ByteData(44 + frames);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate, Endian.little);
  data.setUint16(32, 1, Endian.little);
  data.setUint16(34, 8, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames, Endian.little);
  for (var i = 0; i < frames; i++) {
    final v = sample(i / rate).clamp(-1.0, 1.0);
    data.setUint8(44 + i, (128 + v * 127).round());
  }
  File('../../examples/shooter/sounds/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

/// A PNG file of [rgba], [width] x [height]: 8 bits a channel, no filter.
Uint8List _png(Uint8List rgba, int width, int height) {
  final rows = BytesBuilder();
  for (var y = 0; y < height; y++) {
    rows
      ..addByte(0)
      ..add(rgba.sublist(y * width * 4, (y + 1) * width * 4));
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 8)
    ..setUint8(9, 6);
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
