import 'package:shared_preferences/shared_preferences.dart';

import 'browser.dart';

/// The key under which the IDE remembers the project open last (D62).
const lastProjectKey = 'gubasic.ide.lastProject';

/// Where the IDE remembers the project open last, to open it again when
/// it starts (D62): `example:NAME`, `browser:NAME` or `folder:PATH`, the
/// path of the `.gbproj` file. The IDE's other small settings live in the
/// same place, by key: each project's breakpoints (D129).
abstract interface class LastProject {
  Future<String?> read();
  Future<void> write(String value);

  /// Another setting, by [key].
  Future<String?> readValue(String key);
  Future<void> writeValue(String key, String value);
}

/// [LastProject] in the browser's localStorage, with the web IDE's other
/// small settings.
class StorageLastProject implements LastProject {
  StorageLastProject(this.storage);

  final BrowserStorage storage;

  @override
  Future<String?> read() async => storage.read(lastProjectKey);

  @override
  Future<void> write(String value) => writeValue(lastProjectKey, value);

  @override
  Future<String?> readValue(String key) async => storage.read(key);

  @override
  Future<void> writeValue(String key, String value) async {
    try {
      storage.write(key, value);
    } on StorageFailed {
      // A full storage: the IDE starts with an example next time, or
      // without the breakpoints.
    }
  }
}

/// [LastProject] in shared_preferences: on macOS the app's user defaults,
/// on Windows `shared_preferences.json` in the app's support folder.
class PreferencesLastProject implements LastProject {
  // Made when first used, as the runtime's settings are.
  late final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> read() => _preferences.getString(lastProjectKey);

  @override
  Future<void> write(String value) =>
      _preferences.setString(lastProjectKey, value);

  @override
  Future<String?> readValue(String key) => _preferences.getString(key);

  @override
  Future<void> writeValue(String key, String value) =>
      _preferences.setString(key, value);
}

/// [LastProject] in memory, for tests.
class MemoryLastProject implements LastProject {
  MemoryLastProject([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;

  /// The other settings, by key.
  final values = <String, String>{};

  @override
  Future<String?> readValue(String key) async => values[key];

  @override
  Future<void> writeValue(String key, String value) async =>
      values[key] = value;
}
