// Runs in Chrome: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/platform_browser.dart';
import 'package:web/web.dart' as web;

import '../support/pictures.dart';

void main() {
  final hello = exampleProjects['hello']!;
  final browser = platformBrowser()!;

  /// Deletes the IDE's database; the IDE's open connections give way
  /// (versionchange), as they would to a newer IDE in another tab.
  Future<void> deleteDatabase() {
    final done = Completer<void>();
    web.window.indexedDB.deleteDatabase('gubasic.ide.db')
      ..onsuccess = (web.Event _) {
        done.complete();
      }.toJS
      ..onerror = (web.Event _) {
        done.completeError('cannot delete the database');
      }.toJS;
    return done.future;
  }

  setUp(() async {
    web.window.localStorage.clear();
    await deleteDatabase();
  });
  tearDown(() => web.window.localStorage.clear());

  Future<BrowserProjects> open() async =>
      BrowserProjects.open(await browser.openProjects(), browser.storage);

  test(
    'a project and its pictures are kept in IndexedDB and come back',
    () async {
      final kept = await open();
      await kept.save('내 퀴즈', hello, pictures: {'사과.png': onePixelPng});
      expect(web.window.localStorage.length, 0, reason: 'not in localStorage');

      final again = await open();
      expect(again.read('내 퀴즈')!.files, hello);
      expect(again.read('내 퀴즈')!.pictures, ['사과.png']);
      expect(await again.pictures('내 퀴즈'), {'사과.png': onePixelPng});

      await again.save('내 퀴즈', hello);
      expect(await (await open()).pictures('내 퀴즈'), isEmpty);
      await again.delete('내 퀴즈');
      expect((await open()).list(), isEmpty);
    },
  );

  test("a project's pictures are its own", () async {
    final kept = await open();
    await kept.save('a', hello, pictures: {'x.png': onePixelPng});
    await kept.save('ab', hello, pictures: {'y.png': onePixelPng});
    await kept.delete('a');
    final again = await open();
    expect(await again.pictures('ab'), {'y.png': onePixelPng});
  });

  test(
    'projects kept in localStorage are moved, and removed from it',
    () async {
      web.window.localStorage
        ..setItem('playground.code', 'Debug.Print 1')
        ..setItem(
          'gubasic.ide.project.내 퀴즈',
          jsonEncode({
            'formatVersion': 1,
            'name': '내 퀴즈',
            'files': hello,
            'savedAt': '2026-10-01T00:00:00.000Z',
            'downloadedAt': null,
            'changedSinceDownload': false,
          }),
        );
      final kept = await open();
      expect(kept.read('내 퀴즈')!.files, hello);
      expect(kept.read('내 퀴즈')!.changedSinceDownload, isFalse);
      expect(
        web.window.localStorage.getItem('gubasic.ide.project.내 퀴즈'),
        isNull,
      );
      expect(
        web.window.localStorage.getItem('playground.code'),
        'Debug.Print 1',
      );
      expect((await open()).read('내 퀴즈')!.files, hello, reason: 'reopened');
    },
  );

  test(
    'text written as the page hid is brought back from localStorage',
    () async {
      final kept = await open();
      await kept.save('Quiz', hello);
      final edited = {...hello, 'Form1.gbas': "' typed just before closing\n"};
      expect(kept.writeUnsaved('Quiz', edited), isTrue);
      expect(
        web.window.localStorage.getItem('gubasic.ide.unsaved.quiz'),
        isNotNull,
      );

      final again = await open();
      expect(again.restored, ['Quiz']);
      expect(again.read('Quiz')!.files, edited);
      expect(
        web.window.localStorage.getItem('gubasic.ide.unsaved.quiz'),
        isNull,
      );
      expect(
        (await open()).read('Quiz')!.files,
        edited,
        reason: 'in IndexedDB',
      );
    },
  );

  test('a full localStorage is StorageFailed, not a crash', () {
    final big = 'x' * (6 * 1024 * 1024);
    expect(
      () => browser.storage.write('gubasic.ide.big', big),
      throwsA(isA<StorageFailed>()),
    );
  });

  test('the database is the IDE\'s own', () async {
    await (await open()).save('a', hello);
    final names = await web.window.indexedDB.databases().toDart;
    expect(names.toDart.map((d) => d.name), contains('gubasic.ide.db'));
  });
}
