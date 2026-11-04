import 'dart:typed_data';
import 'dart:ui' as ui;

/// Which pixels of a picture have an alpha of 128 or more (docs/DESIGN.md
/// D138), one byte each, row by row: what a Sprite's pixel collision
/// asks. The language has the same as `PictureMask`; the runtime, which
/// does not depend on it, decodes into this and the host hands it over.
class GbPictureMask {
  const GbPictureMask(this.width, this.height, this.bits);

  final int width;
  final int height;
  final Uint8List bits;

  /// Whether the pixel ([x], [y]) is opaque; false outside the picture.
  bool at(int x, int y) =>
      x >= 0 && y >= 0 && x < width && y < height && bits[y * width + x] != 0;
}

/// The mask of [bytes] (PNG, JPEG or GIF: its first frame), decoded with
/// the engine; null when the bytes are not a picture.
Future<GbPictureMask?> gbDecodePictureMask(Uint8List bytes) async {
  final ui.Codec codec;
  try {
    codec = await ui.instantiateImageCodec(bytes);
  } catch (_) {
    return null;
  }
  try {
    final frame = await codec.getNextFrame();
    final image = frame.image;
    try {
      final data = await image.toByteData(
        format: ui.ImageByteFormat.rawStraightRgba,
      );
      if (data == null) return null;
      final width = image.width, height = image.height;
      final bits = Uint8List(width * height);
      for (var i = 0; i < bits.length; i++) {
        bits[i] = data.getUint8(i * 4 + 3) >= 128 ? 1 : 0;
      }
      return GbPictureMask(width, height, bits);
    } finally {
      image.dispose();
    }
  } catch (_) {
    return null;
  } finally {
    codec.dispose();
  }
}
