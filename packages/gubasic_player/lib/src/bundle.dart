import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:yaml/yaml.dart';

/// The newest layout of a project bundle this GuBASIC reads (D83).
const bundleFormatVersion = 1;

/// A project bundle's file name: what the player looks for, next to the
/// web app's `index.html`, next to the Windows program, or in the macOS
/// app's `Contents/Resources`.
const bundleFileName = 'project.gbz';

/// This GuBASIC's version, written into the bundles it makes.
const gubasicVersion = '0.2.0';

/// A project as an exported app carries it (D83): a `.gbz` file, a zip
/// with `bundle.yaml` (the layout's version, the GuBASIC that made it, the
/// app ID and the project's name) and the project's files as they are on
/// disk under `project/`: its `.gbproj`, each form's `.form.yaml` and
/// `.gbas`, however many forms it has, and `project/pictures/`.
class ProjectBundle {
  const ProjectBundle({
    required this.id,
    required this.name,
    required this.files,
    this.pictures = const {},
    this.madeBy = gubasicVersion,
  });

  /// The app ID (`ProjectFile.id`): the app's settings are kept under it.
  final String id;
  final String name;

  /// File name → text.
  final Map<String, String> files;

  /// Picture name → bytes.
  final Map<String, Uint8List> pictures;

  /// The version of the GuBASIC that made the bundle.
  final String madeBy;

  /// The bundle as the bytes of a `.gbz` file.
  Uint8List encode() {
    final archive = Archive()
      ..add(
        ArchiveFile.bytes(
          'bundle.yaml',
          utf8.encode(
            'formatVersion: $bundleFormatVersion\n'
            'gubasic: ${jsonEncode(madeBy)}\n'
            'id: $id\n'
            'name: ${jsonEncode(name)}\n',
          ),
        ),
      );
    for (final MapEntry(:key, :value) in files.entries) {
      archive.add(ArchiveFile.bytes('project/$key', utf8.encode(value)));
    }
    for (final MapEntry(:key, :value) in pictures.entries) {
      archive.add(ArchiveFile.bytes('project/pictures/$key', value));
    }
    return Uint8List.fromList(ZipEncoder().encodeBytes(archive));
  }

  /// Reads a `.gbz` file. Throws a [BundleProblem]; never anything else.
  static ProjectBundle decode(List<int> bytes) {
    if (bytes.length < 4 || bytes[0] != 0x50 || bytes[1] != 0x4b) {
      throw const NotABundle();
    }
    final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(bytes);
    } catch (_) {
      throw const NotABundle();
    }
    final manifest = archive.findFile('bundle.yaml');
    if (manifest == null) throw const NotABundle();
    final Object? yaml;
    try {
      yaml = loadYaml(utf8.decode(manifest.content));
    } catch (_) {
      throw const NotABundle();
    }
    if (yaml is! YamlMap) throw const NotABundle();
    final version = yaml['formatVersion'];
    final madeBy = '${yaml['gubasic'] ?? ''}';
    if (version is! int) throw const NotABundle();
    if (version > bundleFormatVersion) throw BundleTooNew(madeBy);
    final id = '${yaml['id'] ?? ''}';
    if (!isProjectId(id)) throw const NotABundle();

    final files = <String, String>{};
    final pictures = <String, Uint8List>{};
    for (final entry in archive.files) {
      if (!entry.isFile) continue;
      final path = entry.name.replaceAll(r'\', '/');
      final parts = path.split('/');
      if (parts.contains('..') || parts.first != 'project') continue;
      if (parts.length == 2) {
        try {
          files[parts[1]] = utf8.decode(entry.content);
        } on FormatException {
          throw const NotABundle();
        }
      } else if (parts.length == 3 && parts[1] == 'pictures') {
        pictures[parts[2]] = Uint8List.fromList(entry.content);
      }
    }
    if (!files.keys.any((f) => f.endsWith('.gbproj'))) {
      throw const NotABundle();
    }
    return ProjectBundle(
      id: id,
      name: '${yaml['name'] ?? ''}',
      files: files,
      pictures: pictures,
      madeBy: madeBy,
    );
  }
}

/// Why a `.gbz` file could not be read.
sealed class BundleProblem implements Exception {
  const BundleProblem();
}

/// Not a project bundle, or a damaged one.
class NotABundle extends BundleProblem {
  const NotABundle();
}

/// Made by a newer GuBASIC ([madeBy]), in a layout this one does not know.
class BundleTooNew extends BundleProblem {
  const BundleTooNew(this.madeBy);

  final String madeBy;
}
