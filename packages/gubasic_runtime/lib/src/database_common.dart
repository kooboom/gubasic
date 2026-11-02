import 'package:sqlite3/common.dart';

import 'database.dart';

/// A [GbSqlDatabase] over package:sqlite3's [CommonDatabase], the same on
/// the desktop and the web; [flush] waits for the web's storage to have
/// written a change (null on the desktop).
class CommonSqlDatabase implements GbSqlDatabase {
  CommonSqlDatabase(this.path, this._db, {this.flush});

  @override
  final String path;
  final CommonDatabase _db;

  /// Waits for the web's storage to have written a change; null on the
  /// desktop.
  final Future<void> Function()? flush;

  static T _guard<T>(T Function() body) {
    try {
      return body();
    } on SqliteException catch (e) {
      throw GbSqlError(e.message);
    } on ArgumentError catch (e) {
      throw GbSqlError('${e.message}');
    }
  }

  @override
  Future<GbSqlRows> select(String sql, List<Object?> values) async {
    final result = _guard(() => _db.select(sql, values));
    return (
      columns: result.columnNames,
      rows: [for (final r in result.rows) r],
    );
  }

  @override
  Future<int> execute(String sql, List<Object?> values) async {
    final changed = _guard(() {
      _db.execute(sql, values);
      return _db.updatedRows;
    });
    await flush?.call();
    return changed;
  }

  @override
  int get lastInsertId => _db.lastInsertRowId;

  @override
  Future<void> close() async {
    _db.close();
    await flush?.call();
  }
}
