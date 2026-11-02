import '../diagnostics/diagnostic.dart';
import '../analyzer/conversions.dart';
import '../interpreter/checked_math.dart';
import '../interpreter/host.dart';
import '../interpreter/values.dart';

/// What a query gave back: the columns, and each row's values as SQLite
/// holds them (`int` or `BigInt`, `double`, `String`, bytes, or null).
class SqlRows {
  const SqlRows(this.columns, this.rows);

  final List<String> columns;
  final List<List<Object?>> rows;
}

/// Why the database could not do what was asked: the detail goes into
/// R042 (a statement) or R044 (opening).
class SqlFailure implements Exception {
  const SqlFailure(this.detail);

  final String detail;
}

/// One open database file, where the program runs (docs/DESIGN.md D126):
/// the player's on package:sqlite3, the tests' the same on the VM. Values
/// go in as [DatabaseComponent.sqlValue] makes them: `int` or `BigInt`,
/// `double`, `String` or null. Every method throws an [SqlFailure] for
/// what SQLite refuses.
abstract interface class SqlConnection {
  /// Where the file is, for `Path`.
  String get path;

  /// Runs one statement and gives its rows.
  Future<SqlRows> select(String sql, List<Object?> values);

  /// Runs [sql] and gives how many rows it changed. Without [values] the
  /// text may hold several statements, `BEGIN; …; COMMIT;`.
  Future<int> execute(String sql, List<Object?> values);

  /// The row ID the last INSERT gave (SQLite's `last_insert_rowid`).
  int get lastInsertId;

  Future<void> close();
}

/// The `Database` object (D124, D126), a component through the component
/// channel: everything but the file, which [open] gives where the program
/// runs. An app's database is [defaultName] in its own data folder,
/// opened when first used; `Open(name)` opens another file there.
///
/// `Execute(sql, values…)` runs a statement and gives how many rows it
/// changed, `Query` gives the rows as a `Table` of text, `Scalar` the
/// first value of the first row as text ("" and `LastWasNull` for NULL or
/// no row). A `?` in the SQL takes the next value after it: Integer,
/// Double and String as they are, Boolean as 1 or 0, Date as
/// `yyyy-MM-dd HH:mm:ss`, Nothing as NULL. SQL the database refuses is
/// R042; a name that is not a file name R043; a file that cannot be opened
/// R044.
abstract class DatabaseComponent implements ComponentInstance {
  /// The database every app has: `data.db`.
  static const defaultName = 'data.db';

  /// Opens [name] in the app's data folder, making the file when it is
  /// not there; throws an [SqlFailure].
  Future<SqlConnection> open(String name);

  /// Where [name] is or would be, for `Path` before the file is opened.
  String pathOf(String name);

  SqlConnection? _connection;
  var _name = defaultName;

  /// `LastWasNull`: whether the last `Scalar` found NULL, or no row.
  var lastWasNull = false;

  /// The open file's name.
  String get name => _name;

  Future<SqlConnection> get _db async => _connection ??= await _open(_name);

  Future<SqlConnection> _open(String name) async {
    try {
      return await open(name);
    } on SqlFailure catch (f) {
      throw ComponentProblem(
          DiagnosticCode.databaseOpenFailed, [name, f.detail]);
    }
  }

  @override
  Object? getProperty(String name) => switch (name) {
        'Path' => _connection?.path ?? pathOf(_name),
        'LastWasNull' => lastWasNull,
        'LastId' => GbInt.of(_connection?.lastInsertId ?? 0),
        _ => throw StateError('no code for Database.$name'),
      };

  @override
  void setProperty(String name, Object? value) =>
      throw StateError('Database.$name is read-only');

  @override
  void assign(String name, List<Object?> args, Object? value) =>
      throw StateError('no code for Database.$name = …');

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    switch (name) {
      case 'Open':
        final file = args[0] as String;
        if (!isDatabaseName(file)) {
          throw ComponentProblem(DiagnosticCode.databaseName, [file]);
        }
        await _close();
        _name = file;
        _connection = await _open(file);
        return null;
      case 'Execute':
        return GbInt.of(
            await _run((db, sql, values) => db.execute(sql, values), args));
      case 'Query':
        final rows =
            await _run((db, sql, values) => db.select(sql, values), args);
        return GbTable(List.of(rows.columns), [
          for (final r in rows.rows) [for (final v in r) sqlText(v)]
        ]);
      case 'Scalar':
        final rows =
            await _run((db, sql, values) => db.select(sql, values), args);
        final value = rows.rows.isEmpty || rows.rows.first.isEmpty
            ? null
            : rows.rows.first.first;
        lastWasNull = value == null;
        return sqlText(value);
      case 'Close':
        await _close();
        return null;
    }
    throw StateError('no code for Database.$name');
  }

  /// [body] on the open file with the SQL and the values of [args]; what
  /// SQLite refuses is R042.
  Future<T> _run<T>(
      Future<T> Function(SqlConnection db, String sql, List<Object?> values)
          body,
      List<Object?> args) async {
    final db = await _db;
    try {
      return await body(
          db, args[0] as String, [for (final a in args.skip(1)) sqlValue(a)]);
    } on SqlFailure catch (f) {
      throw ComponentProblem(DiagnosticCode.databaseError, [f.detail]);
    }
  }

  Future<void> _close() async {
    final db = _connection;
    _connection = null;
    if (db != null) await db.close();
  }

  /// Whether [name] can be a database's file name: a name alone, not a
  /// path, and not hidden.
  static bool isDatabaseName(String name) =>
      name.isNotEmpty &&
      name.trim() == name &&
      !name.startsWith('.') &&
      !name.contains(RegExp(r'[/\\:*?"<>|]')) &&
      name != '..';

  /// A GuBASIC value as it goes into the SQL for a `?`: an Integer as an
  /// `int` (or a `BigInt` beyond 2⁵³, which the file keeps exact), a
  /// Double, a String, a Boolean as 1 or 0, a Date as `yyyy-MM-dd
  /// HH:mm:ss`, Nothing as NULL.
  static Object? sqlValue(Object? value) {
    if (isGbInt(value)) {
      final i = value as GbInt;
      return i.toSmallInt() ?? BigInt.parse(i.format());
    }
    return switch (value) {
      null => null,
      double d => d,
      String s => s,
      bool b => b ? 1 : 0,
      DateTime d => formatSqlDate(d),
      _ => throw StateError('no SQL value for $value'),
    };
  }

  /// A value from the database as the text a Table's cell holds: a whole
  /// number below 2⁵³ as its digits, another number as GuBASIC writes a
  /// Double, text as it is, "" for NULL and for bytes (a BLOB).
  ///
  /// On the web a REAL that is whole comes as the same number an INTEGER
  /// does (a JavaScript number), so the rule is by the value, not the
  /// type, and gives the same text on every platform.
  static String sqlText(Object? value) => switch (value) {
        null => '',
        BigInt b => b.toString(),
        num n => numberText(n),
        String s => s,
        _ => '',
      };

  /// Whether this runs as JavaScript, where every number is one type.
  static final _web = identical(0, 0.0);

  /// [n] as [sqlText] writes a number.
  static String numberText(num n) {
    if (n is int && !_web) return GbInt.of(n).format();
    final d = n.toDouble();
    if (d == d.truncateToDouble() && d.abs() < 9007199254740992) {
      return d.toInt().toString();
    }
    return formatDouble(d);
  }

  /// [date] as SQLite's date and time functions read it:
  /// `2026-11-02 14:05:09`.
  static String formatSqlDate(DateTime date) {
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date.year.toString().padLeft(4, '0')}-${two(date.month)}-'
        '${two(date.day)} ${two(date.hour)}:${two(date.minute)}:'
        '${two(date.second)}';
  }
}
