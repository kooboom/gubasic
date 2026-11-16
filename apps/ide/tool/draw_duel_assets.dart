import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

/// Draws the pictures and makes the sounds of examples/duel (D139), so that
/// they are the project's own, free of anyone's copyright, and can be made
/// again the same: for each of the two fighters, in its colour, one set of
/// frames facing right (standing, a step, crouching, jumping,
/// a punch and a kick high and low, blocking, hurt, down); a blue and a red
/// see-through box for the training view; and three WAV files synthesised
/// here (a hit, a blocked hit, a knock-out).
///
/// The poses are drawn on a grid of 96 x 112 and kept at half that size,
/// so that the example's pictures stay small (D55); the Sprite stretches
/// them to its own size.
///
/// Every figure stands in the middle of its frame, its body on the frame's
/// vertical middle line, so that `FlipX` turns it round on the spot (D139):
/// only a fist or a foot reaches toward the edge.
///
///     dart run tool/draw_duel_assets.dart
void main() {
  for (final (prefix, colours) in [('p1', _blue), ('p2', _red)]) {
    for (final MapEntry(key: name, value: pose) in _poses.entries) {
      // Drawn at half size: the Sprite, 96 x 112, draws it twice as big.
      _picture(
        '${prefix}_$name.png',
        48,
        56,
        (p) => _figure(Point(p.x * 2, p.y * 2), pose, colours),
      );
    }
  }
  _picture('hurtbox.png', 8, 8, (_) => 0x664F8EF7);
  _picture('hitbox.png', 8, 8, (_) => 0x88F04A4A);
  final random = Random(11);
  _sound(
    'hit.wav',
    0.12,
    (t) => _decay(t, 0.12) * (random.nextDouble() * 2 - 1) * 0.8,
  );
  _sound('block.wav', 0.07, (t) => _decay(t, 0.07) * _square(t, 520));
  _sound('ko.wav', 0.6, (t) => _decay(t, 0.6) * _square(t, 330 - 250 * t));
}

/// A fighter's colours: its body, and its head and hands, lighter.
typedef _Colours = (int body, int light);

const _blue = (0xFF3D7BE0, 0xFFBFD6FF);
const _red = (0xFFD9465F, 0xFFFFC7D1);

/// A pose: where the head is, and the parts drawn as rounded strokes from
/// point to point, each with its half thickness.
typedef _Pose = ({
  Point<double> head,
  List<(Point<double>, Point<double>, double)> parts,
});

_Pose _pose(
  (double, double) head,
  List<(double, double, double, double, double)> parts,
) => (
  head: Point(head.$1, head.$2),
  parts: [
    for (final (x1, y1, x2, y2, r) in parts) (Point(x1, y1), Point(x2, y2), r),
  ],
);

/// The standing body: the trunk, from the neck to the hips on the middle
/// line x = 48.
const _trunk = (48.0, 30.0, 48.0, 66.0, 8.0);
const _crouchTrunk = (48.0, 60.0, 48.0, 86.0, 8.0);

/// A guard: the front arm bent up before the face, the back one at the
/// chest.
const _guard = [
  (48.0, 36.0, 60.0, 48.0, 4.0),
  (60.0, 48.0, 64.0, 34.0, 4.0),
  (48.0, 38.0, 54.0, 52.0, 4.0),
  (54.0, 52.0, 58.0, 44.0, 4.0),
];
const _crouchGuard = [
  (48.0, 64.0, 60.0, 76.0, 4.0),
  (60.0, 76.0, 64.0, 62.0, 4.0),
];
const _stance = [
  (48.0, 66.0, 40.0, 88.0, 5.0),
  (40.0, 88.0, 36.0, 110.0, 5.0),
  (48.0, 66.0, 58.0, 88.0, 5.0),
  (58.0, 88.0, 60.0, 110.0, 5.0),
];
const _crouchLegs = [
  (48.0, 86.0, 64.0, 94.0, 5.0),
  (64.0, 94.0, 60.0, 110.0, 5.0),
  (48.0, 86.0, 32.0, 96.0, 5.0),
  (32.0, 96.0, 36.0, 110.0, 5.0),
];

final Map<String, _Pose> _poses = {
  'stand': _pose((48, 16), [_trunk, ..._guard, ..._stance]),
  'walk': _pose(
    (49, 16),
    [
      _trunk,
      ..._guard,
      (48, 66, 36, 88, 5),
      (36, 88, 30, 110, 5),
      (48, 66, 62, 86, 5),
      (62, 86, 66, 110, 5),
    ],
  ),
  'crouch': _pose((48, 46), [_crouchTrunk, ..._crouchGuard, ..._crouchLegs]),
  'jump': _pose(
    (48, 16),
    [
      _trunk,
      (48, 36, 60, 26, 4),
      (60, 26, 64, 14, 4),
      (48, 38, 36, 28, 4),
      (36, 28, 34, 16, 4),
      (48, 66, 62, 74, 5),
      (62, 74, 52, 90, 5),
      (48, 66, 36, 78, 5),
      (36, 78, 38, 94, 5),
    ],
  ),
  'punch': _pose(
    (50, 16),
    [
      _trunk,
      (48, 36, 92, 36, 4.5),
      (48, 38, 54, 52, 4),
      (54, 52, 58, 44, 4),
      ..._stance,
    ],
  ),
  'kick': _pose(
    (44, 18),
    [
      (46, 32, 48, 66, 8),
      ..._guard,
      (48, 66, 92, 62, 5.5),
      (48, 66, 42, 88, 5),
      (42, 88, 40, 110, 5),
    ],
  ),
  'lowpunch': _pose(
    (50, 46),
    [_crouchTrunk, (48, 66, 92, 70, 4.5), ..._crouchLegs],
  ),
  'lowkick': _pose(
    (44, 50),
    [
      (46, 64, 48, 88, 8),
      ..._crouchGuard,
      (48, 88, 94, 106, 5.5),
      (48, 88, 32, 98, 5),
      (32, 98, 36, 110, 5),
    ],
  ),
  'block': _pose(
    (46, 17),
    [
      (47, 31, 48, 66, 8),
      (48, 34, 60, 30, 4),
      (60, 30, 62, 18, 4),
      (48, 38, 60, 42, 4),
      (60, 42, 62, 30, 4),
      ..._stance,
    ],
  ),
  'hurt': _pose(
    (40, 20),
    [
      (44, 33, 48, 66, 8),
      (44, 38, 30, 30, 4),
      (30, 30, 24, 40, 4),
      (46, 40, 34, 48, 4),
      ..._stance,
    ],
  ),
  'down': _pose(
    (14, 98),
    [
      (26, 100, 62, 100, 8),
      (30, 98, 40, 90, 4),
      (62, 100, 90, 104, 5),
      (62, 102, 84, 110, 5),
    ],
  ),
};

/// The colour (0xAARRGGBB) of [pose] at [p]; 0 where it is clear.
int _figure(Point<double> p, _Pose pose, _Colours colours) {
  if (p.distanceTo(pose.head) < 10) return colours.$2;
  for (final (a, b, r) in pose.parts) {
    if (_toSegment(p, a, b) < r) return colours.$1;
  }
  return 0;
}

double _toSegment(Point<double> p, Point<double> a, Point<double> b) {
  final ab = b - a;
  final length = ab.x * ab.x + ab.y * ab.y;
  final t = length == 0
      ? 0.0
      : (((p.x - a.x) * ab.x + (p.y - a.y) * ab.y) / length).clamp(0.0, 1.0);
  return p.distanceTo(Point(a.x + ab.x * t, a.y + ab.y * t));
}

/// Writes [name], a picture of [width] x [height] whose colour at each
/// point [colourAt] gives, with its alpha, sampled four by four for soft
/// edges. Each pixel takes the colour most of its samples have and an
/// alpha of two steps, so that the picture has a few colours and is kept
/// as a PNG of 16 colours, 4 bits a pixel: the examples' pictures must stay
/// small (D55).
void _picture(
  String name,
  int width,
  int height,
  int Function(Point<double>) colourAt,
) {
  const samples = 4;
  final palette = <int>[0]; // 0xAARRGGBB; the first is clear
  final pixels = Uint8List(width * height);
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final counts = <int, int>{};
      var covered = 0;
      for (var sy = 0; sy < samples; sy++) {
        for (var sx = 0; sx < samples; sx++) {
          final colour = colourAt(
            Point(x + (sx + 0.5) / samples, y + (sy + 0.5) / samples),
          );
          if (colour == 0) continue;
          covered++;
          counts[colour] = (counts[colour] ?? 0) + 1;
        }
      }
      if (covered == 0) continue;
      final colour = counts.entries
          .reduce((a, b) => b.value > a.value ? b : a)
          .key;
      // Coverage in two steps, half and whole, times the colour's own
      // alpha.
      final step = (covered * 2 / (samples * samples)).round();
      if (step == 0) continue;
      final alpha = ((colour >> 24) & 0xFF) * step ~/ 2;
      final entry = (alpha << 24) | (colour & 0xFFFFFF);
      var index = palette.indexOf(entry);
      if (index < 0) {
        palette.add(entry);
        index = palette.length - 1;
      }
      pixels[y * width + x] = index;
    }
  }
  if (palette.length > 16) throw StateError('$name: ${palette.length} colours');
  File('../../examples/duel/pictures/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(_png(pixels, palette, width, height));
}

double _decay(double t, double length) => (1 - t / length).clamp(0, 1);
double _square(double t, double hz) => sin(t * hz * 2 * pi) > 0 ? 0.5 : -0.5;

/// Writes [name], an 8-bit mono WAV of [seconds] at 11.025 kHz, [sample]
/// giving each moment's value from -1 to 1, as the Shooter's are.
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
  File('../../examples/duel/sounds/$name')
    ..createSync(recursive: true)
    ..writeAsBytesSync(data.buffer.asUint8List());
}

/// A PNG file of [pixels], indexes into [palette], [width] x [height]: 4
/// bits a pixel, no filter, the alphas in a tRNS chunk.
Uint8List _png(Uint8List pixels, List<int> palette, int width, int height) {
  final rows = BytesBuilder();
  final rowBytes = (width + 1) ~/ 2;
  for (var y = 0; y < height; y++) {
    final row = Uint8List(rowBytes);
    for (var x = 0; x < width; x++) {
      row[x ~/ 2] |= pixels[y * width + x] << (x.isEven ? 4 : 0);
    }
    rows
      ..addByte(0)
      ..add(row);
  }
  final header = ByteData(13)
    ..setUint32(0, width)
    ..setUint32(4, height)
    ..setUint8(8, 4)
    ..setUint8(9, 3);
  return (BytesBuilder()
        ..add([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])
        ..add(_chunk('IHDR', header.buffer.asUint8List()))
        ..add(
          _chunk('PLTE', [
            for (final c in palette) ...[
              (c >> 16) & 0xFF,
              (c >> 8) & 0xFF,
              c & 0xFF,
            ],
          ]),
        )
        ..add(_chunk('tRNS', [for (final c in palette) (c >> 24) & 0xFF]))
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
