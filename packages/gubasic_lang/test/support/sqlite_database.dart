import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:sqlite3/sqlite3.dart';

/// The `Database` of a test (docs/DESIGN.md D126): [DatabaseComponent] on
/// package:sqlite3, its files in a folder of the test's own, so that the
/// parity programs run on the real SQLite on the VM as they do in the run
/// window and, through Playwright, in the web player.
class TestDatabase extends DatabaseComponent {
  TestDatabase(this.folder);

  /// A new empty folder under the system's temporary folder.
  factory TestDatabase.temporary() =>
      TestDatabase(Directory.systemTemp.createTempSync('gubasic_db').path);

  final String folder;

  /// Deletes the folder and the files in it.
  void delete() => Directory(folder).deleteSync(recursive: true);

  @override
  String pathOf(String name) => '$folder${Platform.pathSeparator}$name';

  @override
  Future<List<int>> readDatabaseBytes(String name) async {
    final file = File(pathOf(name));
    return file.existsSync() ? file.readAsBytesSync() : _emptyDatabase();
  }

  @override
  Future<void> writeDatabaseBytes(String name, List<int> bytes) async =>
      File(pathOf(name)).writeAsBytesSync(bytes);

  /// An export before anything was written: a new empty database's bytes.
  List<int> _emptyDatabase() {
    final db = sqlite3.open(pathOf('.empty.db'));
    db.execute('CREATE TABLE IF NOT EXISTS gubasic_empty (x); '
        'DROP TABLE gubasic_empty;');
    db.close();
    return File(pathOf('.empty.db')).readAsBytesSync();
  }

  @override
  Future<SqlConnection> open(String name) async {
    try {
      return _Connection(pathOf(name), sqlite3.open(pathOf(name)));
    } on SqliteException catch (e) {
      throw SqlFailure(e.message);
    }
  }
}

class _Connection implements SqlConnection {
  _Connection(this.path, this._db);

  @override
  final String path;
  final Database _db;

  static List<Object?> _bound(List<Object?> values) => [
        for (final v in values)
          // A whole number beyond 2⁵³ is a BigInt on every platform; the
          // VM's int holds it.
          if (v is BigInt) v.toInt() else v
      ];

  @override
  Future<SqlRows> select(String sql, List<Object?> values) async {
    try {
      final result = _db.select(sql, _bound(values));
      return SqlRows(result.columnNames, [for (final r in result.rows) r]);
    } on SqliteException catch (e) {
      throw SqlFailure(e.message);
    } on ArgumentError catch (e) {
      throw SqlFailure('${e.message}');
    }
  }

  @override
  Future<int> execute(String sql, List<Object?> values) async {
    try {
      _db.execute(sql, _bound(values));
      return _db.updatedRows;
    } on SqliteException catch (e) {
      throw SqlFailure(e.message);
    } on ArgumentError catch (e) {
      throw SqlFailure('${e.message}');
    }
  }

  @override
  int get lastInsertId => _db.lastInsertRowId;

  @override
  Future<void> close() async => _db.close();
}
