import 'package:shared_preferences/shared_preferences.dart';

/// Where a program's settings are kept (`SaveSetting`, `GetSetting`;
/// docs/DESIGN.md D48): one text for each project, by its name, which the
/// program writes whole each time.
abstract interface class GbSettingsStore {
  /// The settings of [project], or null if it has none.
  Future<String?> load(String project);

  /// Keeps [text] as the settings of [project]. Throws an [Exception] if
  /// they cannot be kept.
  Future<void> save(String project, String text);

  /// Forgets the settings of [project] (the IDE's Clear Saved Settings).
  Future<void> clear(String project);
}

/// The key the settings of [project] are kept under. On the web it is
/// apart from the IDE's own keys, which start with `gubasic.ide.`.
String gbSettingsKey(String project) => 'gubasic.settings.$project';

/// [GbSettingsStore] in shared_preferences: on macOS the app's user
/// defaults, on Windows `shared_preferences.json` in the app's support
/// folder, on the web the browser's localStorage (D48).
class GbPreferencesSettings implements GbSettingsStore {
  // Made when first used: a program that saves nothing needs no plugin.
  late final _preferences = SharedPreferencesAsync();

  @override
  Future<String?> load(String project) =>
      _preferences.getString(gbSettingsKey(project));

  @override
  Future<void> save(String project, String text) async {
    try {
      await _preferences.setString(gbSettingsKey(project), text);
    } on Object catch (e) {
      // A full browser storage, for one: the program reports it (R012).
      throw Exception('$e');
    }
  }

  @override
  Future<void> clear(String project) =>
      _preferences.remove(gbSettingsKey(project));
}

/// [GbSettingsStore] in memory, for tests.
class GbMemorySettings implements GbSettingsStore {
  /// By project name.
  final values = <String, String>{};

  @override
  Future<String?> load(String project) async => values[project];

  @override
  Future<void> save(String project, String text) async =>
      values[project] = text;

  @override
  Future<void> clear(String project) async => values.remove(project);
}
