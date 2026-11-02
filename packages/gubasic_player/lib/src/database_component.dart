import 'package:flutter/foundation.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The `Database` object of a running program (docs/DESIGN.md D126): the
/// interpreter's [DatabaseComponent] on the runtime's [GbSqlite], its
/// files under the app's own folder, [appId] (the project's name in the
/// IDE, the app ID in an exported app, as the settings are kept). [busy]
/// counts the calls under way, so that the run window shows the pointer
/// as waiting while the web loads SQLite (D124 A).
class PlayerDatabase extends DatabaseComponent {
  PlayerDatabase(this._sqlite, this.appId, this.busy, {GbFiles? files}) {
    if (files != null) this.files = _Files(files);
  }

  final GbSqlite _sqlite;
  final String appId;
  final ValueNotifier<int> busy;

  @override
  String pathOf(String name) => _sqlite.pathOf(appId, name);

  @override
  Future<List<int>> readDatabaseBytes(String name) =>
      _bytes(() => _sqlite.readBytes(appId, name));

  @override
  Future<void> writeDatabaseBytes(String name, List<int> bytes) =>
      _bytes(() => _sqlite.writeBytes(appId, name, bytes));

  Future<T> _bytes<T>(Future<T> Function() body) async {
    busy.value++;
    try {
      return await body();
    } on GbSqlError catch (e) {
      throw SqlFailure(e.detail);
    } finally {
      busy.value--;
    }
  }

  @override
  Future<SqlConnection> open(String name) async {
    busy.value++;
    try {
      return _Connection(await _sqlite.open(appId, name));
    } on GbSqlError catch (e) {
      throw SqlFailure(e.detail);
    } catch (e) {
      // Anything else that went wrong where SQLite is loaded or the file
      // opened is R044 too, not a program that stops without a word.
      throw SqlFailure('$e');
    } finally {
      busy.value--;
    }
  }
}

/// The program's files for Export and Import (D130), as `File` has them
/// (D113): on the web an export downloads under its name, and an import
/// reads a file the user chose or the program saved in this run.
class _Files implements DatabaseFiles {
  _Files(this._files);

  final GbFiles _files;

  static Never _problem(GbFileError e) => throw FileProblem(switch (e.kind) {
    GbFileErrorKind.notFound => FileProblemKind.notFound,
    GbFileErrorKind.notChosen => FileProblemKind.notChosen,
    GbFileErrorKind.other => FileProblemKind.other,
  }, e.detail);

  @override
  Future<List<int>> read(String path) async {
    try {
      return await _files.read(path);
    } on GbFileError catch (e) {
      _problem(e);
    }
  }

  @override
  Future<void> write(String path, List<int> bytes) async {
    try {
      _files.allowSave(path);
      await _files.write(path, bytes);
    } on GbFileError catch (e) {
      _problem(e);
    }
  }
}

class _Connection implements SqlConnection {
  _Connection(this._db);

  final GbSqlDatabase _db;

  @override
  String get path => _db.path;

  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on GbSqlError catch (e) {
      throw SqlFailure(e.detail);
    }
  }

  @override
  Future<SqlRows> select(String sql, List<Object?> values) => _guard(() async {
    final rows = await _db.select(sql, values);
    return SqlRows(rows.columns, rows.rows);
  });

  @override
  Future<int> execute(String sql, List<Object?> values) =>
      _guard(() => _db.execute(sql, values));

  @override
  int get lastInsertId => _db.lastInsertId;

  @override
  Future<void> close() => _guard(_db.close);
}
