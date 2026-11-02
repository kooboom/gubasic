import 'database_io.dart' if (dart.library.js_interop) 'database_web.dart';

/// What a query gave back: the columns, and each row's values as SQLite
/// holds them (`int`, or `BigInt` beyond 2⁵³ on the web, `double`,
/// `String`, bytes, or null).
typedef GbSqlRows = ({List<String> columns, List<List<Object?>> rows});

/// Why the database could not do what was asked; [detail] is what SQLite
/// said, for R042 and R044.
class GbSqlError implements Exception {
  const GbSqlError(this.detail);

  final String detail;
}

/// One open database file (docs/DESIGN.md D126). Values go in for the
/// `?`s as `int`, `BigInt`, `double`, `String` or null.
abstract class GbSqlDatabase {
  /// Where the file is: its path on the desktop, its name on the web.
  String get path;

  /// Runs one statement and gives its rows.
  Future<GbSqlRows> select(String sql, List<Object?> values);

  /// Runs [sql] and gives how many rows it changed; without [values] the
  /// text may hold several statements.
  Future<int> execute(String sql, List<Object?> values);

  /// The row ID the last INSERT gave.
  int get lastInsertId;

  Future<void> close();
}

/// SQLite for a running program (D126), through package:sqlite3: on the
/// desktop the library the package bundles, with each app's files under
/// its own folder in the user's application support folder
/// (`GuBASIC/<app ID>/`); on the web SQLite as WebAssembly, loaded only
/// when a program first uses it, with the files in the browser's
/// IndexedDB under the app ID. Tests give a folder of their own with
/// [root].
abstract class GbSqlite {
  /// [root] is where the `GuBASIC/<app ID>/` folders go instead of the
  /// application support folder; on the web it has no meaning.
  factory GbSqlite({String? root}) => createGbSqlite(root);

  /// Where [name] of [appId] is, or would be.
  String pathOf(String appId, String name);

  /// Opens [name] of [appId], making the folder and the file when they
  /// are not there; throws a [GbSqlError].
  Future<GbSqlDatabase> open(String appId, String name);
}

/// [appId] as a folder or database name: the characters a file system
/// refuses become `_`.
String safeAppId(String appId) {
  final safe = appId.replaceAll(RegExp(r'[\\/:*?"<>|]'), '_').trim();
  return safe.isEmpty || safe == '.' || safe == '..' ? 'app' : safe;
}
