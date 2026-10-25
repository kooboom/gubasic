import 'dart:typed_data';

/// The largest picture file a project takes (docs/DESIGN.md D51).
const maxPictureBytes = 2 * 1024 * 1024;

/// The longest side, in pixels, of a picture a project takes.
const maxPictureSide = 4096;

/// The most bytes all the pictures of a project may take together.
const maxProjectPictureBytes = 10 * 1024 * 1024;

/// The folder of a project that holds its pictures: `Quiz/pictures/`.
const picturesFolder = 'pictures';

/// [name] with Hangul written as syllables (Unicode NFC for Hangul): macOS
/// gives file names with each syllable split into its letters (NFD), so
/// `사과.png` from a Mac and the `"사과.png"` typed in code are made the
/// same. Other characters are left as they are.
String composeHangul(String name) {
  const sBase = 0xAC00, lBase = 0x1100, vBase = 0x1161, tBase = 0x11A7;
  const lCount = 19, vCount = 21, tCount = 28;
  final out = <int>[];
  for (final c in name.runes) {
    if (out.isNotEmpty) {
      final last = out.last;
      final l = last - lBase, v = c - vBase;
      if (l >= 0 && l < lCount && v >= 0 && v < vCount) {
        out[out.length - 1] = sBase + (l * vCount + v) * tCount;
        continue;
      }
      final s = last - sBase, t = c - tBase;
      if (s >= 0 &&
          s < lCount * vCount * tCount &&
          s % tCount == 0 &&
          t > 0 &&
          t < tCount) {
        out[out.length - 1] = last + t;
        continue;
      }
    }
    out.add(c);
  }
  return String.fromCharCodes(out);
}

/// How two picture names are compared: Hangul as syllables, English
/// letters without case, so that `"Triangle.png"` in code is the picture
/// `triangle.png` on every platform. Only A–Z are folded, the same on
/// the VM and the web.
String pictureKey(String name) {
  final units = composeHangul(name).codeUnits.toList();
  for (var i = 0; i < units.length; i++) {
    final c = units[i];
    if (c >= 0x41 && c <= 0x5A) units[i] = c + 0x20;
  }
  return String.fromCharCodes(units);
}

/// Why a picture name cannot be used.
enum PictureNameProblem {
  /// Empty, or longer than 100 characters.
  length,

  /// A character no file name may have on macOS or Windows (`/ \ : * ? "
  /// < > |`, control characters), or a dot or space at the start or end.
  character,

  /// Not `.png`, `.jpg`, `.jpeg` or `.gif`.
  extension,
}

final _badCharacters = RegExp(r'[/\\:*?"<>|\x00-\x1f]');
final _pictureExtension = RegExp(r'\.(png|jpe?g|gif)$', caseSensitive: false);

/// Why [name] cannot be a picture's name, or null when it can.
PictureNameProblem? pictureNameProblem(String name) {
  if (name.isEmpty || name.length > 100) return PictureNameProblem.length;
  if (_badCharacters.hasMatch(name) ||
      name.startsWith('.') ||
      name.startsWith(' ') ||
      name.endsWith('.') ||
      name.endsWith(' ')) {
    return PictureNameProblem.character;
  }
  if (!_pictureExtension.hasMatch(name)) return PictureNameProblem.extension;
  return null;
}

/// What a picture file holds, told from its first bytes.
enum PictureFormat {
  png,
  jpeg,
  gif,

  /// HEIC or HEIF (iPhone photos): only macOS reads them, so they are not
  /// taken.
  heic,

  /// Anything else.
  unknown,
}

/// The format of [bytes], from its signature, not its file name.
PictureFormat pictureFormat(Uint8List bytes) {
  bool starts(List<int> sig, [int at = 0]) {
    if (bytes.length < at + sig.length) return false;
    for (var i = 0; i < sig.length; i++) {
      if (bytes[at + i] != sig[i]) return false;
    }
    return true;
  }

  if (starts(const [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A])) {
    return PictureFormat.png;
  }
  if (starts(const [0xFF, 0xD8, 0xFF])) return PictureFormat.jpeg;
  if (starts('GIF87a'.codeUnits) || starts('GIF89a'.codeUnits)) {
    return PictureFormat.gif;
  }
  // ISO base media: "ftyp" at 4, then a HEIF brand.
  if (starts('ftyp'.codeUnits, 4) && bytes.length >= 12) {
    final brand = String.fromCharCodes(bytes.sublist(8, 12));
    if (const {'heic', 'heix', 'hevc', 'heim', 'heis', 'mif1', 'msf1'}
        .contains(brand)) {
      return PictureFormat.heic;
    }
  }
  return PictureFormat.unknown;
}

/// The width and height of a PNG, JPEG or GIF picture, read from its
/// header; null when they cannot be read.
(int, int)? pictureSize(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  switch (pictureFormat(bytes)) {
    case PictureFormat.png:
      if (bytes.length < 24) return null;
      return (data.getUint32(16), data.getUint32(20));
    case PictureFormat.gif:
      if (bytes.length < 10) return null;
      return (
        data.getUint16(6, Endian.little),
        data.getUint16(8, Endian.little)
      );
    case PictureFormat.jpeg:
      // The first start-of-frame segment has the size.
      var i = 2;
      while (i + 9 < bytes.length) {
        if (bytes[i] != 0xFF) return null;
        final marker = bytes[i + 1];
        if (marker == 0xFF) {
          i++;
          continue;
        }
        final length = data.getUint16(i + 2);
        final isFrame = marker >= 0xC0 &&
            marker <= 0xCF &&
            marker != 0xC4 &&
            marker != 0xC8 &&
            marker != 0xCC;
        if (isFrame) return (data.getUint16(i + 7), data.getUint16(i + 5));
        i += 2 + length;
      }
      return null;
    case PictureFormat.heic || PictureFormat.unknown:
      return null;
  }
}

/// Whether [bytes], a PNG, JPEG or GIF by its signature, is whole as far
/// as its structure tells (D65): every PNG chunk is there with its CRC
/// right, up to `IEND`; a JPEG's segments lead to its image data and an
/// end marker follows; a GIF's blocks lead to its trailer. A file cut
/// short or damaged fails; this is not a full decode, so a picture can
/// pass and still not draw (then a broken picture shows).
bool pictureLooksWhole(Uint8List bytes) {
  try {
    return switch (pictureFormat(bytes)) {
      PictureFormat.png => _pngWhole(bytes),
      PictureFormat.jpeg => _jpegWhole(bytes),
      PictureFormat.gif => _gifWhole(bytes),
      PictureFormat.heic || PictureFormat.unknown => false,
    };
  } on RangeError {
    return false;
  }
}

bool _pngWhole(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var i = 8;
  while (true) {
    final length = data.getUint32(i);
    final end = i + 8 + length;
    if (end + 4 > bytes.length) return false;
    final type = String.fromCharCodes(bytes, i + 4, i + 8);
    if (_crc32(bytes, i + 4, end) != data.getUint32(end)) return false;
    if (type == 'IEND') return true;
    i = end + 4;
  }
}

final _crcTable = List<int>.generate(256, (n) {
  var c = n;
  for (var k = 0; k < 8; k++) {
    c = c & 1 == 1 ? 0xEDB88320 ^ (c >> 1) : c >> 1;
  }
  return c;
});

int _crc32(Uint8List bytes, int from, int to) {
  var crc = 0xFFFFFFFF;
  for (var i = from; i < to; i++) {
    crc = _crcTable[(crc ^ bytes[i]) & 0xFF] ^ (crc >> 8);
  }
  return crc ^ 0xFFFFFFFF;
}

bool _jpegWhole(Uint8List bytes) {
  final data = ByteData.sublistView(bytes);
  var i = 2;
  while (true) {
    if (bytes[i] != 0xFF) return false;
    final marker = bytes[i + 1];
    if (marker == 0xFF) {
      i++;
      continue;
    }
    if (marker == 0xD9) return false; // an end before any image data
    if (marker == 0x01 || (marker >= 0xD0 && marker <= 0xD7)) {
      i += 2;
      continue;
    }
    final length = data.getUint16(i + 2);
    if (length < 2) return false;
    final next = i + 2 + length;
    if (next > bytes.length) return false;
    if (marker == 0xDA) {
      // Image data, then the end marker; a little padding after it is
      // tolerated, as some cameras write.
      for (var j = bytes.length - 2;
          j >= next && j >= bytes.length - 1024;
          j--) {
        if (bytes[j] == 0xFF && bytes[j + 1] == 0xD9) return true;
      }
      return false;
    }
    i = next;
  }
}

bool _gifWhole(Uint8List bytes) {
  var i = 13;
  final flags = bytes[10];
  if (flags & 0x80 != 0) i += 3 * (1 << ((flags & 7) + 1));
  int subBlocks(int at) {
    var j = at;
    while (bytes[j] != 0) {
      j += bytes[j] + 1;
    }
    return j + 1;
  }

  while (true) {
    switch (bytes[i]) {
      case 0x3B:
        return true;
      case 0x21:
        i = subBlocks(i + 2);
      case 0x2C:
        final local = bytes[i + 9];
        i += 10;
        if (local & 0x80 != 0) i += 3 * (1 << ((local & 7) + 1));
        i = subBlocks(i + 1); // after the LZW minimum code size
      default:
        return false;
    }
    if (i >= bytes.length) return false;
  }
}
