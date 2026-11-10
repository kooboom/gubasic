import 'dart:math' as math;

import 'pictures.dart';

/// What `Hits` takes a Sprite for (docs/DESIGN.md D138): its whole
/// rectangle, the largest circle in it, or the opaque pixels of its frame.
enum SpriteShape {
  rectangle('Rectangle'),
  circle('Circle'),
  pixels('Pixels');

  const SpriteShape(this.text);

  /// The word as a program writes it.
  final String text;
}

/// The shape [text] names, in any case, or null for another word.
SpriteShape? spriteShapeNamed(String text) {
  final lower = text.trim().toLowerCase();
  for (final s in SpriteShape.values) {
    if (s.text.toLowerCase() == lower) return s;
  }
  return null;
}

/// A Sprite as `Hits` and `DistanceTo` see it (D138): where it is, with
/// fractions, its size, its shape, and the mask of its frame when the
/// shape is [SpriteShape.pixels] (null: no opaque pixel at all), read
/// mirrored left to right when [flipX] (D139).
class SpriteBox {
  const SpriteBox(this.x, this.y, this.width, this.height, this.shape,
      {this.mask, this.flipX = false});

  final double x;
  final double y;
  final int width;
  final int height;
  final SpriteShape shape;
  final PictureMask? mask;

  /// Drawn mirrored about its own vertical middle line (D139).
  final bool flipX;

  double get centerX => x + width / 2;
  double get centerY => y + height / 2;

  /// The radius of the largest circle in its rectangle.
  double get radius => math.min(width, height) / 2;

  /// Whether the screen pixel ([px], [py]) is inside it: its rectangle,
  /// its circle, or an opaque pixel of its frame scaled to its size.
  bool covers(int px, int py) {
    final cx = px + 0.5, cy = py + 0.5;
    if (cx < x || cy < y || cx >= x + width || cy >= y + height) return false;
    switch (shape) {
      case SpriteShape.rectangle:
        return true;
      case SpriteShape.circle:
        final dx = cx - centerX, dy = cy - centerY, r = radius;
        return dx * dx + dy * dy <= r * r;
      case SpriteShape.pixels:
        final m = mask;
        if (m == null || width == 0 || height == 0) return false;
        final mx = ((cx - x) * m.width / width).floor();
        return m.at(
          flipX ? m.width - 1 - mx : mx,
          ((cy - y) * m.height / height).floor(),
        );
    }
  }
}

/// Whether [a] and [b] touch (D138). Two rectangles, two circles and a
/// circle with a rectangle are computed; when either is pixels, every
/// screen pixel where their rectangles overlap is asked of both.
bool spritesHit(SpriteBox a, SpriteBox b) {
  if (a.width <= 0 || a.height <= 0 || b.width <= 0 || b.height <= 0) {
    return false;
  }
  final left = math.max(a.x, b.x), top = math.max(a.y, b.y);
  final right = math.min(a.x + a.width, b.x + b.width);
  final bottom = math.min(a.y + a.height, b.y + b.height);
  if (left >= right || top >= bottom) return false;
  switch ((a.shape, b.shape)) {
    case (SpriteShape.rectangle, SpriteShape.rectangle):
      return true;
    case (SpriteShape.circle, SpriteShape.circle):
      final dx = a.centerX - b.centerX, dy = a.centerY - b.centerY;
      final r = a.radius + b.radius;
      return dx * dx + dy * dy <= r * r;
    case (SpriteShape.circle, SpriteShape.rectangle):
      return _circleMeetsRectangle(a, b);
    case (SpriteShape.rectangle, SpriteShape.circle):
      return _circleMeetsRectangle(b, a);
    case (SpriteShape.pixels, _) || (_, SpriteShape.pixels):
      for (var py = top.floor(); py < bottom.ceil(); py++) {
        for (var px = left.floor(); px < right.ceil(); px++) {
          if (a.covers(px, py) && b.covers(px, py)) return true;
        }
      }
      return false;
  }
}

bool _circleMeetsRectangle(SpriteBox circle, SpriteBox rect) {
  // The nearest point of the rectangle to the circle's centre.
  final nx = circle.centerX.clamp(rect.x, rect.x + rect.width);
  final ny = circle.centerY.clamp(rect.y, rect.y + rect.height);
  final dx = circle.centerX - nx, dy = circle.centerY - ny, r = circle.radius;
  return dx * dx + dy * dy <= r * r;
}

/// The distance between the centres of [a] and [b] (D138).
double spriteDistance(SpriteBox a, SpriteBox b) {
  final dx = a.centerX - b.centerX, dy = a.centerY - b.centerY;
  return math.sqrt(dx * dx + dy * dy);
}
