import 'dart:io';

import 'package:file_selector/file_selector.dart';

import 'files.dart';

GbFiles createGbFiles() => _IoFiles();

List<XTypeGroup> _groups(List<GbFileFilter> filters) => [
  for (final f in filters)
    XTypeGroup(
      label: f.label,
      extensions: f.extensions.isEmpty ? null : f.extensions,
    ),
];

class _IoFiles implements GbFiles {
  @override
  bool get hasSaveDialog => true;

  @override
  Future<String?> chooseOpen(
    String title,
    List<GbFileFilter> filters,
    String fileName,
  ) async => (await openFile(acceptedTypeGroups: _groups(filters)))?.path;

  @override
  Future<String?> chooseSave(
    String title,
    List<GbFileFilter> filters,
    String fileName,
  ) async => (await getSaveLocation(
    acceptedTypeGroups: _groups(filters),
    suggestedName: fileName.isEmpty
        ? null
        : fileName.split(Platform.pathSeparator).last,
  ))?.path;

  @override
  void allowSave(String name) {}

  @override
  Future<List<int>> read(String path) async {
    try {
      return await File(path).readAsBytes();
    } on PathNotFoundException {
      throw const GbFileError(GbFileErrorKind.notFound);
    } on FileSystemException catch (e) {
      throw GbFileError(GbFileErrorKind.other, e.osError?.message ?? e.message);
    }
  }

  @override
  Future<void> write(
    String path,
    List<int> bytes, {
    bool append = false,
  }) async {
    try {
      await File(path)
          .writeAsBytes(bytes, mode: append ? FileMode.append : FileMode.write);
    } on FileSystemException catch (e) {
      throw GbFileError(GbFileErrorKind.other, e.osError?.message ?? e.message);
    }
  }

  @override
  Future<bool> exists(String path) => File(path).exists();
}
