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
  PlayerDatabase(this._sqlite, this.appId, this.busy);

  final GbSqlite _sqlite;
  final String appId;
  final ValueNotifier<int> busy;

  @override
  String pathOf(String name) => _sqlite.pathOf(appId, name);

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
