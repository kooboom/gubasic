import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// The largest `.zip` file the IDE reads (D33): a project's text and the
/// most its pictures may take (D51), with room to spare.
const maxZipBytes = maxProjectPictureBytes + 2 * 1024 * 1024;

/// The most files a `.zip` may hold that the IDE takes.
const maxZipFiles = 100;

/// The largest size of all the GuBASIC files of a `.zip`, unpacked.
const maxUnpackedBytes = 2 * 1024 * 1024;

/// A project as a `.zip` file: its files in a folder of the project's
/// name, `NAME/NAME.gbproj`, the forms' files and `NAME/pictures/…`, so
/// that unpacking it gives a folder the desktop IDE opens (D33).
List<int> zipProject(
  String name,
  Map<String, String> files, {
  Map<String, Uint8List> pictures = const {},
}) {
  final archive = Archive();
  for (final MapEntry(key: file, value: text) in files.entries) {
    archive.add(ArchiveFile.bytes('$name/$file', utf8.encode(text)));
  }
  for (final MapEntry(key: picture, value: bytes) in pictures.entries) {
    archive.add(ArchiveFile.bytes('$name/$picturesFolder/$picture', bytes));
  }
  return ZipEncoder().encodeBytes(archive);
}

/// What a `.zip` file held: the project's name (its `.gbproj` file's
/// name), its GuBASIC files and pictures, the names of other files left
/// out, and of the pictures the `.gbproj` lists that were not there.
class UnzippedProject {
  const UnzippedProject(
    this.name,
    this.files,
    this.ignored, {
    this.pictures = const {},
    this.missing = const [],
  });

  final String name;
  final Map<String, String> files;

  /// Picture name, as the `.gbproj` file has it → bytes.
  final Map<String, Uint8List> pictures;
  final List<String> ignored;
  final List<String> missing;
}

/// Why a `.zip` file was refused.
sealed class ZipProblem implements Exception {
  const ZipProblem();
}

/// Not a `.zip` file, or a damaged one.
class NotAZip extends ZipProblem {
  const NotAZip();
}

/// Larger than [maxZipBytes], [maxZipFiles] or [maxUnpackedBytes].
class ZipTooLarge extends ZipProblem {
  const ZipTooLarge();
}

/// An entry whose path is absolute or goes up with `..`.
class UnsafeZipPath extends ZipProblem {
  const UnsafeZipPath(this.path);

  final String path;
}

/// The GuBASIC files are not at the top or in one folder there.
class ZipLayout extends ZipProblem {
  const ZipLayout();
}

/// No `.gbproj` file, or more than one: [found] lists them.
class ZipProjectFiles extends ZipProblem {
  const ZipProjectFiles(this.found);

  final List<String> found;
}

/// A GuBASIC file that is not UTF-8 text.
class ZipNotText extends ZipProblem {
  const ZipNotText(this.file);

  final String file;
}

/// Reads a project from the bytes of a `.zip` file. Only `.gbproj`,
/// `.form.yaml` and `.gbas` files are taken, and the pictures in
/// `pictures/` next to them that the `.gbproj` lists; others are left out
/// and named in [UnzippedProject.ignored], except the hidden files that
/// systems add (`.DS_Store`, `__MACOSX/`). Throws a [ZipProblem]; never
/// writes anything.
UnzippedProject unzipProject(List<int> bytes) {
  if (bytes.length > maxZipBytes) throw const ZipTooLarge();
  // Every .zip starts with "PK"; the decoder reads anything else as an
  // empty archive instead of failing.
  if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
    throw const NotAZip();
  }
  final Archive archive;
  try {
    archive = ZipDecoder().decodeBytes(bytes);
  } catch (_) {
    throw const NotAZip();
  }

  final kept = <(List<String>, ArchiveFile)>[];
  final pictureEntries = <(List<String>, ArchiveFile)>[];
  final ignored = <String>[];
  var unpacked = 0;
  for (final entry in archive.files) {
    final path = entry.name.replaceAll(r'\', '/');
    final parts = path.split('/')..removeWhere((p) => p.isEmpty);
    if (path.startsWith('/') ||
        RegExp(r'^[A-Za-z]:').hasMatch(path) ||
        parts.contains('..')) {
      throw UnsafeZipPath(entry.name);
    }
    if (!entry.isFile || parts.isEmpty) continue;
    if (parts.any((p) => p.startsWith('.') || p == '__MACOSX')) continue;
    if (parts.length >= 2 && parts[parts.length - 2] == picturesFolder) {
      pictureEntries.add((parts, entry));
      continue;
    }
    if (!_isGuBasicFile(parts.last)) {
      ignored.add(path);
      continue;
    }
    unpacked += entry.size;
    if (kept.length == maxZipFiles || unpacked > maxUnpackedBytes) {
      throw const ZipTooLarge();
    }
    kept.add((parts, entry));
  }

  // All at the top, or all in one folder there.
  final folders = {
    for (final (parts, _) in kept) parts.length == 2 ? parts.first : null,
  };
  if (kept.any((k) => k.$1.length > 2) || folders.length > 1) {
    throw const ZipLayout();
  }

  final projectFiles = [
    for (final (parts, _) in kept)
      if (parts.last.toLowerCase().endsWith('.gbproj')) parts.last,
  ];
  if (projectFiles.length != 1) throw ZipProjectFiles(projectFiles);

  final files = <String, String>{};
  var total = 0;
  for (final (parts, entry) in kept) {
    final data = entry.readBytes() ?? const <int>[];
    total += data.length;
    if (total > maxUnpackedBytes) throw const ZipTooLarge();
    try {
      files[parts.last] = utf8.decode(data);
    } on FormatException {
      throw ZipNotText(parts.last);
    }
  }
  final project = projectFiles.single;

  // The pictures the .gbproj lists, from pictures/ next to it.
  final top = folders.single;
  final listed = {
    for (final p in readProjectFile(files[project]!).project.pictures)
      pictureKey(p): p,
  };
  final pictures = <String, Uint8List>{};
  var pictureBytes = 0;
  for (final (parts, entry) in pictureEntries) {
    final name = listed[pictureKey(parts.last)];
    final inPlace = top == null
        ? parts.length == 2
        : parts.length == 3 && parts.first == top;
    if (name == null || !inPlace || pictures.containsKey(name)) {
      ignored.add(parts.join('/'));
      continue;
    }
    pictureBytes += entry.size;
    if (pictures.length + kept.length == maxZipFiles ||
        entry.size > maxPictureBytes ||
        pictureBytes > maxProjectPictureBytes) {
      throw const ZipTooLarge();
    }
    final data = Uint8List.fromList(entry.readBytes() ?? const <int>[]);
    // The size an entry gives may be false; what came out counts.
    if (data.length > maxPictureBytes) throw const ZipTooLarge();
    pictures[name] = data;
  }
  return UnzippedProject(
    project.substring(0, project.length - '.gbproj'.length),
    files,
    ignored,
    pictures: pictures,
    missing: [
      for (final name in listed.values)
        if (!pictures.containsKey(name)) '$picturesFolder/$name',
    ],
  );
}

bool _isGuBasicFile(String name) {
  final lower = name.toLowerCase();
  return lower.endsWith('.gbproj') ||
      lower.endsWith('.form.yaml') ||
      lower.endsWith('.gbas');
}
