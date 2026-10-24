import 'dart:typed_data';

import 'package:gubasic_ide/src/project/folders.dart';

/// Folders in memory: path → text for files, path → bytes for pictures,
/// and a set of folders.
class MemoryFolders implements ProjectFolders {
  final files = <String, String>{};
  final bytes = <String, Uint8List>{};
  final folders = <String>{};

  /// Every path deleted, in order.
  final deleted = <String>[];

  /// Paths whose writing fails, as a full disk would.
  final failing = <String>{};

  /// Every path written, in order.
  final written = <String>[];

  /// Adds [folder] with [files] in it.
  void add(String folder, Map<String, String> files) {
    folders.add(folder);
    for (final MapEntry(:key, :value) in files.entries) {
      this.files[join(folder, key)] = value;
    }
  }

  @override
  Future<List<String>> list(String folder) async {
    if (!folders.contains(folder)) {
      throw FolderIoException(folder, 'no such folder');
    }
    return [
      for (final path in files.keys)
        if (path.startsWith('$folder/') &&
            !path.substring(folder.length + 1).contains('/'))
          path.substring(folder.length + 1),
    ];
  }

  @override
  Future<String?> read(String path) async => files[path];

  @override
  Future<void> write(String path, String text) async {
    if (failing.contains(path)) throw FolderIoException(path, 'disk full');
    written.add(path);
    files[path] = text;
  }

  @override
  Future<Uint8List?> readBytes(String path) async => bytes[path];

  @override
  Future<void> writeBytes(String path, Uint8List bytes) async {
    if (failing.contains(path)) throw FolderIoException(path, 'disk full');
    if (!folders.contains(parent(path))) {
      throw FolderIoException(path, 'no such folder');
    }
    written.add(path);
    this.bytes[path] = bytes;
  }

  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
    bytes.remove(path);
  }

  @override
  Future<bool> exists(String path) async =>
      folders.contains(path) ||
      files.containsKey(path) ||
      bytes.containsKey(path);

  @override
  Future<void> createFolder(String path) async => folders.add(path);

  @override
  String join(String folder, String name) => '$folder/$name';

  @override
  String parent(String path) => path.substring(0, path.lastIndexOf('/'));

  @override
  String name(String path) => path.substring(path.lastIndexOf('/') + 1);
}
