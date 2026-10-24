import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';

import 'support/fake_browser.dart';
import 'support/pictures.dart';

void main() {
  final hello = exampleProjects['hello']!;
  late MemoryStorage storage;
  late MemoryProjectStore store;
  late BrowserProjects kept;
  var now = DateTime(2026, 10, 17, 9);

  Future<BrowserProjects> open() =>
      BrowserProjects.open(store, storage, now: () => now);

  setUp(() async {
    storage = MemoryStorage();
    store = MemoryProjectStore();
    now = DateTime(2026, 10, 17, 9);
    kept = await open();
  });

  /// What localStorage held for [name] before D53.
  String version1(String name, Map<String, String> files) => jsonEncode({
    'formatVersion': 1,
    'name': name,
    'files': files,
    'savedAt': '2026-10-01T00:00:00.000Z',
    'downloadedAt': null,
    'changedSinceDownload': true,
  });

  test(
    'a project is kept by the lower case of its name, and read back',
    () async {
      await kept.save('My Quiz', hello);
      expect(store.records.keys, ['my quiz']);
      final p = kept.read('MY QUIZ')!;
      expect(p.name, 'My Quiz');
      expect(p.files, hello);
      expect(p.savedAt, now);
      expect(p.downloadedAt, isNull);
      expect(p.changedSinceDownload, isTrue);
      expect(kept.contains('my quiz'), isTrue);
      expect((await open()).read('my quiz')!.files, hello, reason: 'reopened');
    },
  );

  test('pictures are kept apart and read when asked for', () async {
    await kept.save('Fruit', hello, pictures: {'사과.png': onePixelPng});
    expect(store.pictures['fruit'], {'사과.png': onePixelPng});
    final again = await open();
    expect(again.read('Fruit')!.pictures, ['사과.png']);
    expect(await again.pictures('fruit'), {'사과.png': onePixelPng});

    await again.save('Fruit', hello);
    expect(store.pictures['fruit'], isEmpty, reason: 'one taken out goes');
    expect(await again.pictures('Fruit'), isEmpty);
  });

  test('marking a download keeps the pictures', () async {
    await kept.save('Fruit', hello, pictures: {'a.png': onePixelPng});
    await kept.markDownloaded('Fruit');
    expect(store.pictures['fruit'], {'a.png': onePixelPng});
    expect(kept.read('Fruit')!.changedSinceDownload, isFalse);
  });

  test('the list is the last saved first', () async {
    await kept.save('A', hello);
    now = now.add(const Duration(minutes: 1));
    await kept.save('B', hello);
    expect(kept.list().map((p) => p.name), ['B', 'A']);
  });

  test('changes since the last download', () async {
    await kept.save('A', hello);
    await kept.markDownloaded('A');
    expect(kept.read('A')!.changedSinceDownload, isFalse);
    expect(kept.read('A')!.downloadedAt, now);

    await kept.save('A', hello);
    expect(
      kept.read('A')!.changedSinceDownload,
      isFalse,
      reason: 'the same files again',
    );
    await kept.save('A', hello, pictures: {'a.png': onePixelPng});
    expect(kept.read('A')!.changedSinceDownload, isTrue, reason: 'a picture');
    await kept.markDownloaded('A');
    await kept.save(
      'A',
      {...hello, 'Form1.gbas': "' changed\n"},
      pictures: {'a.png': onePixelPng},
    );
    expect(kept.read('A')!.changedSinceDownload, isTrue);
  });

  test('a project from a .zip is not changed since a download', () async {
    await kept.save('A', hello, fromFile: true);
    expect(kept.read('A')!.changedSinceDownload, isFalse);
  });

  test('records that cannot be read are left out and left alone', () async {
    store.records['broken'] = '{not json';
    store.records['newer'] = jsonEncode({
      'formatVersion': browserProjectVersion + 1,
    });
    kept = await open();
    await kept.save('A', hello);
    expect(kept.list().map((p) => p.name), ['A']);
    expect(store.records, contains('broken'));
    expect(store.records, contains('newer'));
  });

  test('a full storage fails the save and keeps what was there', () async {
    await kept.save('A', hello);
    store.full = true;
    await expectLater(
      kept.save('A', {...hello, 'Form1.gbas': 'x'}),
      throwsA(isA<StorageFailed>()),
    );
    expect(kept.read('A')!.files, hello);
    store.full = false;
    await kept.save('B', hello);
    expect(kept.contains('B'), isTrue, reason: 'later writes still go');
  });

  test('without a store nothing is listed and saving fails', () async {
    kept = await BrowserProjects.open(null, storage);
    expect(kept.list(), isEmpty);
    await expectLater(kept.save('A', hello), throwsA(isA<StorageFailed>()));
  });

  test('writes go one after another, and busy says so meanwhile', () async {
    final hold = Completer<void>();
    store.hold = hold.future;
    final first = kept.save('A', hello);
    final second = kept.save('A', {...hello, 'Form1.gbas': "' 2\n"});
    await pumpEventQueue();
    expect(kept.busy, isTrue);
    expect(kept.contains('A'), isFalse, reason: 'listed once written');
    hold.complete();
    await first;
    await second;
    expect(kept.busy, isFalse);
    expect(kept.read('A')!.files['Form1.gbas'], "' 2\n");
  });

  group('moving from localStorage (D53)', () {
    test('projects are moved, and removed from localStorage', () async {
      storage.values['gubasic.ide.project.my quiz'] = version1(
        'My Quiz',
        hello,
      );
      storage.values['gubasic.ide.noticeShown'] = '1';
      storage.values['playground.code'] = 'Debug.Print 1';
      kept = await open();
      expect(kept.read('My Quiz')!.files, hello);
      expect(kept.read('My Quiz')!.pictures, isEmpty);
      expect(store.records.keys, ['my quiz']);
      expect(storage.values, {
        'gubasic.ide.noticeShown': '1',
        'playground.code': 'Debug.Print 1',
      });
      expect(kept.noticeShown, isTrue);
    });

    test('one that cannot be written stays, and moves next time', () async {
      storage.values['gubasic.ide.project.a'] = version1('A', hello);
      store.full = true;
      kept = await open();
      expect(kept.list(), isEmpty);
      expect(storage.values, contains('gubasic.ide.project.a'));
      store.full = false;
      kept = await open();
      expect(kept.read('A')!.files, hello);
      expect(storage.values, isNot(contains('gubasic.ide.project.a')));
    });

    test('one kept in IndexedDB already is not overwritten', () async {
      await kept.save('A', {...hello, 'Form1.gbas': "' newer\n"});
      storage.values['gubasic.ide.project.a'] = version1('A', hello);
      kept = await open();
      expect(kept.read('A')!.files['Form1.gbas'], "' newer\n");
      expect(storage.values, isEmpty);
    });

    test('entries that cannot be read stay where they are', () async {
      storage.values['gubasic.ide.project.broken'] = '{not json';
      kept = await open();
      expect(kept.list(), isEmpty);
      expect(storage.values, contains('gubasic.ide.project.broken'));
      expect(store.records, isEmpty);
    });
  });

  test('the notice is remembered in localStorage', () {
    expect(kept.noticeShown, isFalse);
    kept.markNoticeShown();
    expect(kept.noticeShown, isTrue);
    expect(storage.values.keys, ['gubasic.ide.noticeShown']);
  });
}
