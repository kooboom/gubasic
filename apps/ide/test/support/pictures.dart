import 'dart:convert';
import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';

/// A real 1 x 1 PNG picture, which Flutter can draw.
final Uint8List onePixelPng = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQDwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

/// A 40 x 20 JPEG whose EXIF says to turn it a quarter clockwise, as a
/// phone held upright writes a photo: shown 20 x 40.
final Uint8List turnedJpeg = base64Decode(
  '/9j/4AAQSkZJRgABAQAAAQABAAD/4QAiRXhpZgAATU0AKgAAAAgAAQESAAMAAAABAAYAAAAAAAD/2wBDAAYEBQYFBAYGBQYHBwYIChAKCgkJChQODwwQFxQYGBcUFhYaHSUfGhsjHBYWICwgIyYnKSopGR8tMC0oMCUoKSj/2wBDAQcHBwoIChMKChMoGhYaKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCgoKCj/wAARCAAUACgDASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwDgKKKK+eP2EKKKKACiiigAooooAKKKKACiiigD/9k=',
);

/// An 8 x 8 GIF of two frames, red then green.
final Uint8List animatedGif = base64Decode(
  'R0lGODlhCAAIAIEAAP8AAAAAAAAAAAAAACH/C05FVFNDQVBFMi4wAwEAAAAh+QQACgAAACwAAAAACAAIAAAIDwABCBxIsKDBgwgTKkwYEAAh+QQBCgABACwAAAAACAAIAIEA/wAAAAAAAAAAAAAIDwABCBxIsKDBgwgTKkwYEAA7',
);

/// [onePixelPng] made [length] bytes long with a private chunk before its
/// end, so that it is whole (its CRCs right) and takes that many bytes.
Uint8List paddedPng(int length) {
  final end = onePixelPng.length - 12; // IEND: 4 length, 4 type, 4 CRC
  final padding = length - onePixelPng.length - 12;
  final chunk = BytesBuilder()
    ..add((ByteData(4)..setUint32(0, padding)).buffer.asUint8List())
    ..add('gbPd'.codeUnits)
    ..add(Uint8List(padding));
  final body = chunk.takeBytes();
  final crc = ByteData(4)..setUint32(0, _crc32(body, 4));
  return (BytesBuilder()
        ..add(onePixelPng.sublist(0, end))
        ..add(body)
        ..add(crc.buffer.asUint8List())
        ..add(onePixelPng.sublist(end)))
      .takeBytes();
}

int _crc32(List<int> bytes, int from) {
  var crc = 0xFFFFFFFF;
  for (var i = from; i < bytes.length; i++) {
    crc ^= bytes[i];
    for (var k = 0; k < 8; k++) {
      crc = crc & 1 == 1 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
    }
  }
  return crc ^ 0xFFFFFFFF;
}

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
