import 'dart:typed_data';

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

/// The SQLite module, loaded once.
Future<WasmSqlite3> _module() async {
  try {
    return _sqlite ??= await WasmSqlite3.loadFromUrlString(sqliteWasmFile);
  } catch (e) {
    throw GbSqlError('$sqliteWasmFile could not be loaded: $e');
  }
}

/// The file system of [appId], opened once and registered with the
/// module: the IndexedDB database and the VFS both under the app's name,
/// so that two apps on one page keep their files apart.
Future<IndexedDbFileSystem> _fileSystem(
  WasmSqlite3 sqlite,
  String appId,
) async {
  final IndexedDbFileSystem fs;
  try {
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
  return fs;
}

/// The bytes of [name] of [appId] in the browser's storage (D130); a new
/// empty database's when there is none yet.
Future<List<int>> readBytes(String appId, String name) async {
  final sqlite = await _module();
  final fs = await _fileSystem(sqlite, appId);
  if (fs.xAccess('/$name', 0) == 0) {
    // Nothing written yet: a new empty database with its header, made
    // and closed.
    sqlite.open('/$name', vfs: fs.name)
      ..execute(emptyDatabaseSql)
      ..close();
    await fs.flush();
  }
  final file = fs
      .xOpen(Sqlite3Filename('/$name'), SqlFlag.SQLITE_OPEN_READONLY)
      .file;
  try {
    final bytes = Uint8List(file.xFileSize());
    file.xRead(bytes, 0);
    return bytes;
  } finally {
    file.xClose();
  }
}

/// Writes [name] of [appId] anew from [bytes] (D130).
Future<void> writeBytes(String appId, String name, List<int> bytes) async {
  final sqlite = await _module();
  final fs = await _fileSystem(sqlite, appId);
  final file = fs
      .xOpen(
        Sqlite3Filename('/$name'),
        SqlFlag.SQLITE_OPEN_READWRITE | SqlFlag.SQLITE_OPEN_CREATE,
      )
      .file;
  try {
    file.xTruncate(0);
    file.xWrite(Uint8List.fromList(bytes), 0);
    file.xSync(0);
  } finally {
    file.xClose();
  }
  await fs.flush();
}

/// Opens [name] of [appId] in the browser's storage.
Future<GbSqlDatabase> openDatabase(String appId, String name) async {
  final sqlite = await _module();
  final fs = await _fileSystem(sqlite, appId);
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
