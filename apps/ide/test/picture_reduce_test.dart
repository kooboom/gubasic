import 'dart:async';
import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/picture_reduce.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import 'support/pictures.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// A PNG of [width] x [height] pixels of noise, which does not compress:
  /// about 4 bytes a pixel.
  Future<Uint8List> noisePng(int width, int height) async {
    final random = Random(1);
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i++) {
      pixels[i] = i % 4 == 3 ? 255 : random.nextInt(256);
    }
    final done = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      pixels,
      width,
      height,
      ui.PixelFormat.rgba8888,
      done.complete,
    );
    final image = await done.future;
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  test('the name of the smaller copy ends in .png', () {
    expect(reducedPictureName('사진.jpg'), '사진.png');
    expect(reducedPictureName('cat.photo.JPEG'), 'cat.photo.png');
    expect(reducedPictureName('a.png'), 'a.png');
  });

  test('a large picture becomes 1024 pixels on its longest side, and '
      'smaller again while it takes too much', () async {
    final big = await noisePng(1600, 1200);
    expect(big.length, greaterThan(maxPictureBytes));

    final roomy = (await reducePicture('noise.png', big, maxBytes: 1 << 30))!;
    expect((roomy.width, roomy.height), (1024, 768));
    expect(pictureSize(roomy.bytes), (1024, 768));
    expect(pictureFormat(roomy.bytes), PictureFormat.png);

    // 1024 x 768 of noise takes about 3 MB: a quarter smaller, 768 x 576.
    final small = (await reducePicture(
      'noise.png',
      big,
      maxBytes: maxPictureBytes,
    ))!;
    expect((small.width, small.height), (768, 576));
    expect(small.bytes.length, lessThanOrEqualTo(maxPictureBytes));
  });

  test("a photo is turned as its EXIF says, and a small one keeps its "
      "size", () async {
    final reduced = (await reducePicture(
      'upright.jpg',
      turnedJpeg,
      maxBytes: maxPictureBytes,
    ))!;
    expect(reduced.name, 'upright.png');
    expect((reduced.width, reduced.height), (20, 40));
    expect(pictureSize(reduced.bytes), (20, 40));
  });

  test('an animated GIF is told apart, and keeps its first frame', () async {
    expect(await isAnimatedPicture(animatedGif), isTrue);
    expect(await isAnimatedPicture(onePixelPng), isFalse);
    final reduced = (await reducePicture(
      'moving.gif',
      animatedGif,
      maxBytes: maxPictureBytes,
    ))!;
    expect(reduced.name, 'moving.png');
    expect(pictureSize(reduced.bytes), (8, 8));
    expect(await isAnimatedPicture(reduced.bytes), isFalse);
  });

  test('null when it cannot be read, or cannot be made small enough', () async {
    expect(
      await reducePicture('broken.png', pngHeader(100, 100), maxBytes: 1000),
      isNull,
    );
    expect(
      await reducePicture('noise.png', await noisePng(200, 200), maxBytes: 100),
      isNull,
    );
  });
}
