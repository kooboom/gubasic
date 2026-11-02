import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

import '../support/sqlite_database.dart';

/// The program's files in a map, as a test's ScriptedHost has them.
class _Files implements DatabaseFiles {
  _Files(this.disk);

  final Map<String, List<int>> disk;

  @override
  Future<List<int>> read(String path) async =>
      disk[path] ?? (throw const FileProblem(FileProblemKind.notFound));

  @override
  Future<void> write(String path, List<int> bytes) async =>
      disk[path] = List.of(bytes);
}

/// The Database object on a real SQLite (docs/DESIGN.md D126): the
/// values that go in and come out, Scalar and LastWasNull, LastId, Open,
/// Close, and what becomes R042, R043 and R044.
void main() {
  late TestDatabase db;
  setUp(() => db = TestDatabase.temporary());
  tearDown(() async {
    await db.call('Close', []);
    db.delete();
  });

  test('data.db is opened when first used, in the folder', () async {
    expect(db.getProperty('Path'), endsWith('data.db'));
    expect(db.getProperty('LastId'), GbInt.of(0));
    expect(await db.call('Execute', ['CREATE TABLE t (a, b)']), GbInt.of(0));
    expect(db.getProperty('Path'), db.pathOf('data.db'));
  });

  test('values go in for ? as SQLite holds them, and come out as text',
      () async {
    await db.call('Execute', ['CREATE TABLE t (i, d, s, b, dt, n)']);
    final changed = await db.call('Execute', [
      'INSERT INTO t VALUES (?, ?, ?, ?, ?, ?)',
      GbInt.of(42),
      2.5,
      "it's",
      true,
      DateTime(2026, 3, 1, 9, 5, 7),
      null,
    ]);
    expect(changed, GbInt.of(1));
    expect(db.getProperty('LastId'), GbInt.of(1));
    final table = await db.call('Query', [
      'SELECT i, d, s, b, dt, n, typeof(i), typeof(b), typeof(dt) FROM t'
    ]) as GbTable;
    expect(table.headers, [
      'i',
      'd',
      's',
      'b',
      'dt',
      'n',
      'typeof(i)',
      'typeof(b)',
      'typeof(dt)'
    ]);
    expect(table.rows, [
      [
        '42',
        '2.5',
        "it's",
        '1',
        '2026-03-01 09:05:07',
        '',
        'integer',
        'integer',
        'text'
      ]
    ]);
    // A REAL that is whole, a BLOB, and a number too large for a Double.
    final odd = await db.call('Query', [
      "SELECT 78.0, X'0102', 1e20, 9007199254740993, -0.5, ?",
      GbInt.parse('9007199254740993'),
    ]) as GbTable;
    expect(odd.rows.single,
        ['78', '', '1E+20', '9007199254740993', '-0.5', '9007199254740993']);
  });

  test('Scalar gives the first value as text; LastWasNull says NULL or none',
      () async {
    await db.call('Execute', ['CREATE TABLE t (a, b)']);
    await db.call('Execute', ['INSERT INTO t VALUES (?, ?)', 'x', null]);
    expect(await db.call('Scalar', ['SELECT a FROM t']), 'x');
    expect(db.getProperty('LastWasNull'), isFalse);
    expect(await db.call('Scalar', ['SELECT b FROM t']), '');
    expect(db.getProperty('LastWasNull'), isTrue);
    expect(await db.call('Scalar', ['SELECT a FROM t WHERE a = ?', 'y']), '');
    expect(db.getProperty('LastWasNull'), isTrue);
    expect(await db.call('Scalar', ['SELECT COUNT(*) FROM t']), '1');
    expect(db.getProperty('LastWasNull'), isFalse);
  });

  test('Execute runs several statements when there are no values', () async {
    await db.call('Execute', [
      'CREATE TABLE t (a); BEGIN; INSERT INTO t VALUES (1); '
          'INSERT INTO t VALUES (2); COMMIT;'
    ]);
    expect(await db.call('Scalar', ['SELECT COUNT(*) FROM t']), '2');
    expect(await db.call('Execute', ['UPDATE t SET a = a + 1']), GbInt.of(2));
    expect(await db.call('Execute', ['DELETE FROM t WHERE a = ?', GbInt.of(2)]),
        GbInt.of(1));
  });

  test('Open changes the file, Close closes it; the next use opens again',
      () async {
    await db.call('Execute', ['CREATE TABLE t (a)']);
    await db.call('Open', ['other.db']);
    expect(db.getProperty('Path'), endsWith('other.db'));
    expect(
        await db.call('Scalar', ['SELECT COUNT(*) FROM sqlite_master']), '0');
    await db.call('Close', []);
    expect(db.getProperty('Path'), endsWith('other.db'));
    expect(await db.call('Scalar', ['SELECT 1 + 1']), '2');
    await db.call('Open', ['data.db']);
    expect(
        await db.call('Scalar', ['SELECT COUNT(*) FROM sqlite_master']), '1');
  });

  test('SQL the database refuses is R042; a bad name R043', () async {
    Future<void> expectProblem(Future<Object?> Function() body,
        DiagnosticCode code, String arg) async {
      try {
        await body();
        fail('no problem');
      } on ComponentProblem catch (p) {
        expect(p.code, code);
        expect(p.args.first, arg);
      }
    }

    await expectProblem(() => db.call('Execute', ['SELEC 1']),
        DiagnosticCode.databaseError, 'near "SELEC": syntax error');
    await expectProblem(() => db.call('Query', ['SELECT * FROM missing']),
        DiagnosticCode.databaseError, 'no such table: missing');
    await expectProblem(() => db.call('Scalar', ['SELECT ?, ?', GbInt.of(1)]),
        DiagnosticCode.databaseError, 'Expected 2 parameters, got 1');
    for (final name in ['', ' a.db', '../x.db', 'a/b.db', r'a\b.db', '.x']) {
      await expectProblem(
          () => db.call('Open', [name]), DiagnosticCode.databaseName, name);
    }
    expect(DatabaseComponent.isDatabaseName('scores.db'), isTrue);
    expect(DatabaseComponent.isDatabaseName('점수'), isTrue);
  });

  test('a folder that cannot be written is R044', () async {
    final broken = TestDatabase('${db.folder}/missing/deeper');
    try {
      await broken.call('Scalar', ['SELECT 1']);
      fail('no problem');
    } on ComponentProblem catch (p) {
      expect(p.code, DiagnosticCode.databaseOpenFailed);
      expect(p.args.first, 'data.db');
    }
  });

  test(
      'Export writes the file where the program\'s files go; Import '
      'brings it back; a file that is not a database is R045', () async {
    final disk = <String, List<int>>{};
    db.files = _Files(disk);
    await db.call('Execute', ['CREATE TABLE t (a)']);
    await db.call('Execute', ['INSERT INTO t VALUES (?)', 'kept']);
    await db.call('Export', ['backup.db']);
    expect(DatabaseComponent.isSqliteFile(disk['backup.db']!), isTrue);
    await db.call('Execute', ['DELETE FROM t']);
    expect(await db.call('Scalar', ['SELECT COUNT(*) FROM t']), '0');
    await db.call('Import', ['backup.db']);
    expect(await db.call('Scalar', ['SELECT a FROM t']), 'kept');
    // Not a database.
    disk['text.txt'] = 'hello'.codeUnits;
    try {
      await db.call('Import', ['text.txt']);
      fail('no problem');
    } on ComponentProblem catch (p) {
      expect(p.code, DiagnosticCode.databaseNotFile);
      expect(p.args, ['text.txt']);
    }
    // Not there: the file's own code.
    try {
      await db.call('Import', ['missing.db']);
      fail('no problem');
    } on ComponentProblem catch (p) {
      expect(p.code, DiagnosticCode.fileNotFound);
    }
    // An export before anything was written is still a database.
    final fresh = TestDatabase.temporary()..files = _Files(disk);
    addTearDown(fresh.delete);
    await fresh.call('Export', ['empty.db']);
    expect(DatabaseComponent.isSqliteFile(disk['empty.db']!), isTrue);
    // Without files (the playground), R038.
    fresh.files = null;
    try {
      await fresh.call('Export', ['x.db']);
      fail('no problem');
    } on ComponentProblem catch (p) {
      expect(p.code, DiagnosticCode.componentUnavailable);
    }
  });

  test('Date and the other values as text for SQL', () {
    expect(DatabaseComponent.formatSqlDate(DateTime(2026, 11, 2, 7, 8, 9)),
        '2026-11-02 07:08:09');
    expect(DatabaseComponent.sqlValue(GbInt.of(-3)), -3);
    expect(DatabaseComponent.sqlValue(false), 0);
    expect(DatabaseComponent.sqlValue(GbInt.parse('9007199254740993')),
        BigInt.parse('9007199254740993'));
    expect(DatabaseComponent.sqlText(BigInt.parse('-9007199254740993')),
        '-9007199254740993');
    expect(DatabaseComponent.sqlText(3.0), '3');
    expect(DatabaseComponent.sqlText(1e15), '1000000000000000');
    expect(DatabaseComponent.sqlText(1e20), '1E+20');
    expect(DatabaseComponent.sqlText(-0.0), '0');
    expect(DatabaseComponent.sqlText(2.5e-7), '2.5E-7');
    expect(
        DatabaseComponent.sqlText(9007199254740992.0), '9.007199254740992E+15');
    expect(DatabaseComponent.sqlText(9007199254740993), '9007199254740993');
    expect(DatabaseComponent.sqlText([1, 2]), '');
  });
}
