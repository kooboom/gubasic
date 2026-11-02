import 'package:sqlite3/wasm.dart';

import 'database.dart';
import 'database_common.dart';

/// The SQLite module once loaded, and the file system of each app, by its
/// ID: one IndexedDB database per app, `gubasic-<app ID>`.
WasmSqlite3? _sqlite;
final _fileSystems = <String, IndexedDbFileSystem>{};
final _registered = <String>{};

/// The file `sqlite3.wasm` next to the page, from the sqlite3 package's
/// release (tool/fetch_sqlite_wasm.dart puts it there).
const sqliteWasmFile = 'sqlite3.wasm';

/// Opens [name] of [appId] in the browser's storage.
Future<GbSqlDatabase> openDatabase(String appId, String name) async {
  final WasmSqlite3 sqlite;
  try {
    sqlite = _sqlite ??= await WasmSqlite3.loadFromUrlString(sqliteWasmFile);
  } catch (e) {
    throw GbSqlError('$sqliteWasmFile could not be loaded: $e');
  }
  final IndexedDbFileSystem fs;
  try {
    // The IndexedDB database and the VFS both under the app's name, so
    // that two apps on one page keep their files apart.
    fs = _fileSystems[appId] ??= await IndexedDbFileSystem.open(
      dbName: 'gubasic-$appId',
      vfsName: 'gubasic-$appId',
    );
  } catch (e) {
    throw GbSqlError('the browser\'s storage could not be opened: $e');
  }
  // Registered once; the default so that a plain open finds it too.
  if (_registered.add(fs.name)) {
    sqlite.registerVirtualFileSystem(fs, makeDefault: true);
  }
  try {
    return CommonSqlDatabase(
      name,
      sqlite.open('/$name', vfs: fs.name),
      flush: fs.flush,
    );
  } on SqliteException catch (e) {
    throw GbSqlError(e.message);
  }
}
