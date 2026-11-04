import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The geometry of a Sprite's Hits and DistanceTo (docs/DESIGN.md D138),
/// and the masks of a test's NAME.masks.
void main() {
  SpriteBox box(double x, double y, int w, int h, SpriteShape shape,
          {PictureMask? mask}) =>
      SpriteBox(x, y, w, h, shape, mask: mask);

  test('shapes by name, in any case', () {
    expect(spriteShapeNamed('circle'), SpriteShape.circle);
    expect(spriteShapeNamed(' PIXELS '), SpriteShape.pixels);
    expect(spriteShapeNamed('Rectangle')!.text, 'Rectangle');
    expect(spriteShapeNamed('Triangle'), isNull);
  });

  test('masks from rows of # and .', () {
    final masks = parsePictureMasks('Blob.png\n.##.\n####\n\n\ndot.png\n#\n');
    final blob = masks['blob.png']!;
    expect([blob.width, blob.height], [4, 2]);
    expect(blob.at(0, 0), isFalse);
    expect(blob.at(1, 0), isTrue);
    expect(blob.at(0, 1), isTrue);
    expect(blob.at(4, 0), isFalse, reason: 'outside');
    expect(blob.at(-1, 0), isFalse);
    expect(masks['dot.png']!.at(0, 0), isTrue);
  });

  test('rectangles overlap, or only touch', () {
    const r = SpriteShape.rectangle;
    expect(spritesHit(box(0, 0, 20, 20, r), box(10, 10, 20, 20, r)), isTrue);
    expect(spritesHit(box(0, 0, 20, 20, r), box(20, 0, 20, 20, r)), isFalse);
    expect(spritesHit(box(0, 0, 20, 20, r), box(19.5, 0, 20, 20, r)), isTrue);
    expect(spritesHit(box(0, 0, 0, 20, r), box(0, 0, 20, 20, r)), isFalse,
        reason: 'no size');
  });

  test('circles: the largest in each rectangle', () {
    const c = SpriteShape.circle;
    // Centres 10 apart on each axis, radii 10: 14.1 < 20.
    expect(spritesHit(box(0, 0, 20, 20, c), box(10, 10, 20, 20, c)), isTrue);
    // Rectangles overlap at the corners, the circles do not: 24 > 20.
    expect(spritesHit(box(0, 0, 20, 20, c), box(17, 17, 20, 20, c)), isFalse);
    // A tall rectangle's circle is as wide as it.
    expect(spritesHit(box(0, 0, 10, 40, c), box(9, 0, 10, 40, c)), isTrue);
    expect(spritesHit(box(0, 0, 10, 40, c), box(11, 0, 10, 40, c)), isFalse);
  });

  test('a circle and a rectangle', () {
    const r = SpriteShape.rectangle, c = SpriteShape.circle;
    expect(spritesHit(box(0, 0, 20, 20, r), box(18, 18, 20, 20, c)), isFalse,
        reason: 'the corner is outside the circle');
    expect(spritesHit(box(0, 0, 20, 20, r), box(15, 0, 20, 20, c)), isTrue);
    expect(spritesHit(box(18, 18, 20, 20, c), box(0, 0, 20, 20, r)), isFalse,
        reason: 'the same the other way round');
  });

  test('pixels: the mask scaled to the sprite, asked where they overlap', () {
    final blob = PictureMask.rows(['.##.', '####', '####', '.##.']);
    const r = SpriteShape.rectangle, p = SpriteShape.pixels;
    SpriteBox blobAt(double x, double y) => box(x, y, 20, 20, p, mask: blob);
    // The blob's clear corner is 5 x 5 screen pixels.
    expect(spritesHit(box(0, 0, 20, 20, r), blobAt(18, 18)), isFalse);
    expect(spritesHit(box(0, 0, 20, 20, r), blobAt(13, 18)), isTrue);
    expect(spritesHit(blobAt(13, 18), box(0, 0, 20, 20, r)), isTrue);
    // Two blobs, corner to corner, miss; moved in, they touch.
    expect(spritesHit(blobAt(0, 0), blobAt(16, 16)), isFalse);
    expect(spritesHit(blobAt(0, 0), blobAt(14, 14)), isTrue);
    // Without a mask no pixel is opaque.
    expect(spritesHit(box(0, 0, 20, 20, p), box(0, 0, 20, 20, r)), isFalse);
    // A circle and pixels.
    expect(spritesHit(box(0, 0, 20, 20, SpriteShape.circle), blobAt(10, 10)),
        isTrue);
  });

  test('the distance between centres', () {
    const r = SpriteShape.rectangle;
    expect(spriteDistance(box(0, 0, 20, 20, r), box(30, 40, 20, 20, r)), 50);
    expect(spriteDistance(box(0, 0, 20, 20, r), box(0, 0, 20, 20, r)), 0);
  });
}
