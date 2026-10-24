import 'dart:typed_data';

import 'package:gubasic_ide/src/project/browser.dart';

/// `localStorage` in memory. [full] makes every write fail.
class MemoryStorage implements BrowserStorage {
  final values = <String, String>{};
  var full = false;

  @override
  Iterable<String> get keys => values.keys;

  @override
  String? read(String key) => values[key];

  @override
  void write(String key, String value) {
    if (full) throw const StorageFailed();
    values[key] = value;
  }

  @override
  void remove(String key) => values.remove(key);
}

/// IndexedDB in memory: [records] by key, [pictures] by key and name.
/// [full] makes every write fail; [hold] keeps writes from finishing
/// until it completes.
class MemoryProjectStore implements ProjectStore {
  final records = <String, String>{};
  final pictures = <String, Map<String, Uint8List>>{};
  var full = false;
  Future<void>? hold;

  @override
  Future<Map<String, String>> readAll() async => Map.of(records);

  @override
  Future<String?> read(String key) async => records[key];

  @override
  Future<Map<String, Uint8List>> readPictures(String key) async =>
      Map.of(pictures[key] ?? const {});

  @override
  Future<void> write(
    String key,
    String record,
    Map<String, Uint8List>? pictures,
  ) async {
    await hold;
    if (full) throw const StorageFailed();
    records[key] = record;
    if (pictures != null) this.pictures[key] = Map.of(pictures);
  }

  @override
  Future<void> delete(String key) async {
    records.remove(key);
    pictures.remove(key);
  }
}

/// A browser that records downloads and lets tests leave or hide the page.
class FakeBrowser implements Browser {
  @override
  final MemoryStorage storage = MemoryStorage();

  final MemoryProjectStore projects = MemoryProjectStore();

  @override
  Future<ProjectStore?> openProjects() async => projects;

  /// File name → bytes, in the order downloaded.
  final downloads = <(String, List<int>)>[];

  bool Function()? _unsaved;
  void Function()? _hidden;

  @override
  void download(String fileName, List<int> bytes) =>
      downloads.add((fileName, bytes));

  @override
  void guardUnload(bool Function() unsaved) => _unsaved = unsaved;

  @override
  void onHidden(void Function() action) => _hidden = action;

  /// The pages opened, in order.
  final opened = <String>[];

  @override
  void open(String url) => opened.add(url);

  /// Whether the browser would ask before leaving the page now.
  bool get wouldAskToLeave => _unsaved!();

  void hide() => _hidden!();
}
