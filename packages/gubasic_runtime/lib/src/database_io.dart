import 'dart:io';

import 'package:sqlite3/sqlite3.dart';

import 'database.dart';
import 'database_common.dart';

GbSqlite createGbSqlite(String? root) => _IoSqlite(root ?? supportFolder());

/// The user's application support folder, where apps keep their own
/// files: `%APPDATA%` on Windows, `~/Library/Application Support` on
/// macOS (inside the app's container when it is sandboxed), and
/// `$XDG_DATA_HOME` or `~/.local/share` elsewhere.
String supportFolder() {
  final env = Platform.environment;
  if (Platform.isWindows) {
    return env['APPDATA'] ?? '${env['USERPROFILE'] ?? '.'}\\AppData\\Roaming';
  }
  final home = env['HOME'] ?? '.';
  if (Platform.isMacOS) return '$home/Library/Application Support';
  return env['XDG_DATA_HOME'] ?? '$home/.local/share';
}

class _IoSqlite implements GbSqlite {
  _IoSqlite(this.root);

  final String root;

  String _folder(String appId) =>
      [root, 'GuBASIC', safeAppId(appId)].join(Platform.pathSeparator);

  @override
  String pathOf(String appId, String name) =>
      '${_folder(appId)}${Platform.pathSeparator}$name';

  @override
  Future<List<int>> readBytes(String appId, String name) async {
    final file = File(pathOf(appId, name));
    try {
      if (!file.existsSync() || file.lengthSync() == 0) {
        // Nothing written yet: a new empty database, made and closed. A
        // table made and dropped gives the file its header; SQLite leaves
        // an untouched database as zero bytes.
        final db = await open(appId, name);
        await db.execute(emptyDatabaseSql, []);
        await db.close();
      }
      // Synchronous, as the rest of the desktop's files are: the bytes
      // are there at once, also where a test's clock is not real.
      return file.readAsBytesSync();
    } on FileSystemException catch (e) {
      throw GbSqlError(e.osError?.message ?? e.message);
    }
  }

  @override
  Future<void> writeBytes(String appId, String name, List<int> bytes) async {
    try {
      Directory(_folder(appId)).createSync(recursive: true);
      File(pathOf(appId, name)).writeAsBytesSync(bytes, flush: true);
    } on FileSystemException catch (e) {
      throw GbSqlError(e.osError?.message ?? e.message);
    }
  }

  @override
  Future<GbSqlDatabase> open(String appId, String name) async {
    final path = pathOf(appId, name);
    try {
      Directory(_folder(appId)).createSync(recursive: true);
    } on FileSystemException catch (e) {
      throw GbSqlError(e.osError?.message ?? e.message);
    }
    try {
      // A whole number beyond 2⁵³ comes as a BigInt; the VM's int holds it.
      return _Database(path, sqlite3.open(path));
    } on SqliteException catch (e) {
      throw GbSqlError(e.message);
    }
  }
}

class _Database extends CommonSqlDatabase {
  _Database(super.path, super.db);

  static List<Object?> _ints(List<Object?> values) => [
    for (final v in values)
      if (v is BigInt) v.toInt() else v,
  ];

  @override
  Future<GbSqlRows> select(String sql, List<Object?> values) =>
      super.select(sql, _ints(values));

  @override
  Future<int> execute(String sql, List<Object?> values) =>
      super.execute(sql, _ints(values));
}
