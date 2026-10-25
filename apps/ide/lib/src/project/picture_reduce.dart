import 'dart:math';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

/// The longest side of a picture made smaller (D56).
const reducedPictureSide = 1024;

/// The shortest longest side made smaller to before giving up.
const _smallestSide = 64;

/// A picture made smaller: a PNG, with the size it has.
typedef ReducedPicture = ({
  String name,
  Uint8List bytes,
  int width,
  int height,
});

/// [name] with the extension `.png`.
String reducedPictureName(String name) {
  final dot = name.lastIndexOf('.');
  return '${dot > 0 ? name.substring(0, dot) : name}.png';
}

/// Whether [bytes] is a picture of more than one frame (an animated GIF),
/// of which a smaller picture keeps the first only.
Future<bool> isAnimatedPicture(Uint8List bytes) async {
  final codec = await _codec(bytes);
  try {
    return codec.frameCount > 1;
  } finally {
    codec.dispose();
  }
}

/// Picture [name] made smaller (D56): its first frame as a PNG, the
/// longest side at most [reducedPictureSide] pixels, and smaller again,
/// a quarter each time, until it takes at most [maxBytes]. Null when it
/// cannot be read, or would have to be smaller than 64 pixels. The size
/// is the picture's as it is shown, turned as a photo says it was taken.
Future<ReducedPicture?> reducePicture(
  String name,
  Uint8List bytes, {
  required int maxBytes,
}) async {
  final ui.Image source;
  try {
    source = await _firstFrame(bytes);
  } on Object {
    // Bytes that look like a picture but cannot be decoded.
    return null;
  }
  try {
    final longest = max(source.width, source.height);
    var side = min(reducedPictureSide, longest);
    while (true) {
      final scale = side / longest;
      final width = max(1, (source.width * scale).round());
      final height = max(1, (source.height * scale).round());
      final png = await _png(source, width, height);
      if (png.length <= maxBytes) {
        return (
          name: reducedPictureName(name),
          bytes: png,
          width: width,
          height: height,
        );
      }
      side = side * 3 ~/ 4;
      if (side < _smallestSide) return null;
    }
  } finally {
    source.dispose();
  }
}

Future<ui.Codec> _codec(Uint8List bytes, {int? targetSide}) async {
  final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
  // Decoded no larger than needed: a phone photo is 12 million pixels.
  // (ImageDescriptor would tell the size first, but not on the web.)
  return ui.instantiateImageCodecWithSize(
    buffer,
    getTargetSize: (width, height) {
      final longest = max(width, height);
      if (targetSide == null || longest <= targetSide) {
        return const ui.TargetImageSize();
      }
      final scale = targetSide / longest;
      return ui.TargetImageSize(
        width: max(1, (width * scale).round()),
        height: max(1, (height * scale).round()),
      );
    },
  );
}

Future<ui.Image> _firstFrame(Uint8List bytes) async {
  final codec = await _codec(bytes, targetSide: reducedPictureSide);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

/// [source] drawn [width] × [height], as a PNG. Drawn even when the size
/// is the same: an animated GIF is decoded at its own size, whatever size
/// is asked for.
Future<Uint8List> _png(ui.Image source, int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..filterQuality = FilterQuality.medium,
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  picture.dispose();
  try {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data!.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  } finally {
    image.dispose();
  }
}
