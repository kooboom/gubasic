import 'dart:js_interop';
import 'dart:typed_data';

import 'package:file_selector/file_selector.dart';
import 'package:web/web.dart' as web;

import 'files.dart';

GbFiles createGbFiles() => _WebFiles();

class _WebFiles implements GbFiles {
  /// The files the user chose or the program saved in this run, by name.
  final _known = <String, List<int>>{};
  final _savable = <String>{};

  @override
  bool get hasSaveDialog => false;

  @override
  Future<String?> chooseOpen(
    String title,
    List<GbFileFilter> filters,
    String fileName,
  ) async {
    final file = await openFile(
      acceptedTypeGroups: [
        for (final f in filters)
          XTypeGroup(
            label: f.label,
            extensions: f.extensions.isEmpty ? null : f.extensions,
          ),
      ],
    );
    if (file == null) return null;
    _known[file.name] = await file.readAsBytes();
    return file.name;
  }

  @override
  Future<String?> chooseSave(
    String title,
    List<GbFileFilter> filters,
    String fileName,
  ) => throw UnsupportedError('no save dialog on the web');

  @override
  void allowSave(String name) => _savable.add(name);

  @override
  Future<List<int>> read(String path) async =>
      _known[path] ?? (throw const GbFileError(GbFileErrorKind.notChosen));

  @override
  Future<void> write(
    String path,
    List<int> bytes, {
    bool append = false,
  }) async {
    if (!_known.containsKey(path) && !_savable.contains(path)) {
      throw const GbFileError(GbFileErrorKind.notChosen);
    }
    final all = _known[path] = [if (append) ...?_known[path], ...bytes];
    // Saving on the web is downloading (D113): the whole file each time.
    final blob = web.Blob(
      [Uint8List.fromList(all).toJS].toJS,
      web.BlobPropertyBag(type: 'application/octet-stream'),
    );
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = path;
    web.document.body!.append(link);
    link.click();
    link.remove();
    web.URL.revokeObjectURL(url);
  }

  @override
  Future<bool> exists(String path) async => _known.containsKey(path);
}
