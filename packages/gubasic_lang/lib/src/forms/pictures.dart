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
