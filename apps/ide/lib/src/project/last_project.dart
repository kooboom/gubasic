import 'package:shared_preferences/shared_preferences.dart';

import 'browser.dart';

/// The key under which the IDE remembers the project open last (D62).
const lastProjectKey = 'gubasic.ide.lastProject';

/// Where the IDE remembers the project open last, to open it again when
/// it starts (D62): `example:NAME`, `browser:NAME` or `folder:PATH`, the
/// path of the `.gbproj` file.
abstract interface class LastProject {
  Future<String?> read();
  Future<void> write(String value);
}

/// [LastProject] in the browser's localStorage, with the web IDE's other
/// small settings.
class StorageLastProject implements LastProject {
  StorageLastProject(this.storage);

  final BrowserStorage storage;

  @override
  Future<String?> read() async => storage.read(lastProjectKey);

  @override
  Future<void> write(String value) async {
    try {
      storage.write(lastProjectKey, value);
    } on StorageFailed {
      // A full storage: the IDE starts with an example next time.
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
}

/// [LastProject] in memory, for tests.
class MemoryLastProject implements LastProject {
  MemoryLastProject([this.value]);

  String? value;

  @override
  Future<String?> read() async => value;

  @override
  Future<void> write(String value) async => this.value = value;
}
