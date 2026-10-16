import 'dart:convert';
import 'dart:io';

import 'folders.dart';

/// The disk, on macOS and Windows.
ProjectFolders? platformFolders() => const _DiskFolders();

class _DiskFolders implements ProjectFolders {
  const _DiskFolders();

  @override
  Future<List<String>> list(String folder) => _guard(folder, () async {
    final names = <String>[];
    await for (final e in Directory(folder).list(followLinks: false)) {
      if (e is File) names.add(e.uri.pathSegments.last);
    }
    return names;
  });

  @override
  Future<String?> read(String path) => _guard(path, () async {
    final file = File(path);
    if (!await file.exists()) return null;
    return utf8.decode(await file.readAsBytes());
  });

  @override
  Future<void> write(String path, String text) => _guard(path, () async {
    // Written next to the file, then renamed over it: a rename replaces
    // the file in one step, so a crash leaves the old file or the new one.
    final temp = File('$path.saving');
    try {
      await temp.writeAsBytes(utf8.encode(text), flush: true);
      await temp.rename(path);
    } catch (_) {
      if (await temp.exists()) await temp.delete();
      rethrow;
    }
  });

  @override
  Future<bool> exists(String path) => _guard(
    path,
    () async =>
        await FileSystemEntity.type(path) != FileSystemEntityType.notFound,
  );

  @override
  Future<void> createFolder(String path) =>
      _guard(path, () => Directory(path).create());

  @override
  String join(String folder, String name) =>
      '$folder${Platform.pathSeparator}$name';
}

Future<T> _guard<T>(String path, Future<T> Function() action) async {
  try {
    return await action();
  } on FileSystemException catch (e) {
    throw FolderIoException(path, e.osError?.message ?? e.message);
  } on FormatException {
    throw FolderIoException.notText(path);
  }
}
