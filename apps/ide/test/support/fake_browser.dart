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

/// A browser that records downloads and lets tests leave or hide the page.
class FakeBrowser implements Browser {
  @override
  final MemoryStorage storage = MemoryStorage();

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

  /// Whether the browser would ask before leaving the page now.
  bool get wouldAskToLeave => _unsaved!();

  void hide() => _hidden!();
}
