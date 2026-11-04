import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The mask of a picture for a Sprite's pixel collision (docs/DESIGN.md
/// D138): decoded with the engine, the pixels whose alpha is 128 or more.
void main() {
  /// A real PNG of 4 x 3 pixels: opaque, except the top left corner, which
  /// is clear, and the top right, which is faint (alpha 64).
  Future<Uint8List> png(WidgetTester tester) async =>
      (await tester.runAsync(() async {
        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 4, 3),
          Paint()..color = const Color(0xFF3366CC),
        );
        canvas.drawRect(
          const Rect.fromLTWH(0, 0, 1, 1),
          Paint()
            ..color = const Color(0x00000000)
            ..blendMode = BlendMode.src,
        );
        canvas.drawRect(
          const Rect.fromLTWH(3, 0, 1, 1),
          Paint()
            ..color = const Color(0x40000000)
            ..blendMode = BlendMode.src,
        );
        final image = await recorder.endRecording().toImage(4, 3);
        final data = await image.toByteData(format: ui.ImageByteFormat.png);
        return data!.buffer.asUint8List();
      }))!;

  testWidgets('the opaque pixels of a PNG, alpha 128 or more', (tester) async {
    final bytes = await png(tester);
    final mask = (await tester.runAsync(() => gbDecodePictureMask(bytes)))!;
    expect([mask.width, mask.height], [4, 3]);
    expect(mask.at(0, 0), isFalse, reason: 'clear');
    expect(mask.at(3, 0), isFalse, reason: 'faint');
    expect(mask.at(1, 0), isTrue);
    expect(mask.at(0, 2), isTrue);
    expect(mask.bits.where((b) => b == 1).length, 10);
  });

  testWidgets('bytes that are no picture give nothing', (tester) async {
    final mask = await tester.runAsync(
      () => gbDecodePictureMask(Uint8List.fromList([1, 2, 3])),
    );
    expect(mask, isNull);
  });
}
