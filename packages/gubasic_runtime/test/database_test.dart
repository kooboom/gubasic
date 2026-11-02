@TestOn('vm')
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// SQLite through package:sqlite3 on the desktop (docs/DESIGN.md D126):
/// each app's files under `GuBASIC/<app ID>/` in the given folder, values in
/// and out, several statements at once, and what becomes an error.
void main() {
  late Directory root;
  late GbSqlite sqlite;

  setUp(() {
    root = Directory.systemTemp.createTempSync('gubasic_sqlite');
    sqlite = GbSqlite(root: root.path);
  });
  tearDown(() => root.deleteSync(recursive: true));

  test('an app\'s file is under GuBASIC/<app ID>/, made when opened', () async {
    final path = sqlite.pathOf('scores', 'data.db');
    expect(
      path.replaceAll(r'\', '/'),
      '${root.path.replaceAll(r'\', '/')}/GuBASIC/scores/data.db',
    );
    expect(sqlite.pathOf('a/b:c', 'x.db'), contains('a_b_c'));
    final db = await sqlite.open('scores', 'data.db');
    expect(db.path, path);
    expect(File(path).existsSync(), isTrue);
    await db.close();
  });

  test(
    'values go in and come out; changes and the last ID are counted',
    () async {
      final db = await sqlite.open('app', 'data.db');
      await db.execute('CREATE TABLE t (i, d, s, n)', []);
      expect(
        await db.execute('INSERT INTO t VALUES (?, ?, ?, ?)', [
          1,
          2.5,
          'x',
          null,
        ]),
        1,
      );
      expect(db.lastInsertId, 1);
      expect(
        await db.execute('INSERT INTO t VALUES (?, ?, ?, ?)', [
          BigInt.parse('9007199254740993'),
          -0.5,
          '',
          null,
        ]),
        1,
      );
      final rows = await db.select('SELECT i, d, s, n FROM t ORDER BY i', []);
      expect(rows.columns, ['i', 'd', 's', 'n']);
      expect(rows.rows, [
        [1, 2.5, 'x', null],
        [9007199254740993, -0.5, '', null],
      ]);
      expect(
        await db.execute(
          'BEGIN; INSERT INTO t (i) VALUES (3); INSERT INTO t (i) VALUES (4); '
          'COMMIT;',
          [],
        ),
        1,
      );
      expect(await db.execute('UPDATE t SET s = ?', ['y']), 4);
      await db.close();
    },
  );

  test('what SQLite refuses is a GbSqlError with its words', () async {
    final db = await sqlite.open('app', 'data.db');
    await expectLater(
      () => db.execute('SELEC 1', []),
      throwsA(
        isA<GbSqlError>().having(
          (e) => e.detail,
          'detail',
          'near "SELEC": syntax error',
        ),
      ),
    );
    await expectLater(
      () => db.select('SELECT ?, ?', [1]),
      throwsA(
        isA<GbSqlError>().having(
          (e) => e.detail,
          'detail',
          'Expected 2 parameters, got 1',
        ),
      ),
    );
    await db.close();
  });

  test('a folder that cannot be made is a GbSqlError', () async {
    final file = File('${root.path}/wall')..writeAsStringSync('');
    final blocked = GbSqlite(root: file.path);
    await expectLater(
      () => blocked.open('app', 'data.db'),
      throwsA(isA<GbSqlError>()),
    );
  });
}
