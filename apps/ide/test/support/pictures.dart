import 'dart:convert';
import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';

/// A real 1 x 1 PNG picture, which Flutter can draw.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// The start of a PNG of [width] x [height] pixels, padded to [length]
/// bytes: enough for the checks that read the header.
Uint8List pngHeader(int width, int height, {int length = 64}) {
  final bytes = Uint8List(length < 24 ? 24 : length);
  bytes.setAll(0, const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
  bytes.setAll(12, 'IHDR'.codeUnits);
  ByteData.sublistView(bytes)
    ..setUint32(16, width)
    ..setUint32(20, height);
  return bytes;
}

/// The hello example's .gbproj with [pictures], as the IDE writes it.
String helloWithPictures(List<String> pictures) => writeProjectFile(
  ProjectFile(
    name: 'Hello',
    forms: const ['Form1'],
    startup: 'Form1',
    pictures: pictures,
  ),
);
