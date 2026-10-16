import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';

import 'support/fake_browser.dart';

void main() {
  final hello = exampleProjects['hello']!;
  late MemoryStorage storage;
  late BrowserProjects kept;
  var now = DateTime(2026, 10, 17, 9);

  setUp(() {
    storage = MemoryStorage();
    now = DateTime(2026, 10, 17, 9);
    kept = BrowserProjects(storage, now: () => now);
  });

  test('a project is kept under gubasic.ide. and read back', () {
    kept.save('My Quiz', hello);
    expect(storage.values.keys, ['gubasic.ide.project.my quiz']);
    final p = kept.read('MY QUIZ')!;
    expect(p.name, 'My Quiz');
    expect(p.files, hello);
    expect(p.savedAt, now);
    expect(p.downloadedAt, isNull);
    expect(p.changedSinceDownload, isTrue);
    expect(kept.contains('my quiz'), isTrue);
  });

  test("other pages' keys are not read, changed or removed", () {
    storage.values['playground.code'] = 'Debug.Print 1';
    storage.values['project.Hello'] = 'not ours';
    kept.save('Hello', hello);
    kept.delete('Hello');
    expect(kept.list(), isEmpty);
    expect(storage.values, {
      'playground.code': 'Debug.Print 1',
      'project.Hello': 'not ours',
    });
  });

  test('the list is the last saved first', () {
    kept.save('A', hello);
    now = now.add(const Duration(minutes: 1));
    kept.save('B', hello);
    expect(kept.list().map((p) => p.name), ['B', 'A']);
  });

  test('changes since the last download', () {
    kept.save('A', hello);
    kept.markDownloaded('A');
    expect(kept.read('A')!.changedSinceDownload, isFalse);
    expect(kept.read('A')!.downloadedAt, now);

    kept.save('A', hello);
    expect(
      kept.read('A')!.changedSinceDownload,
      isFalse,
      reason: 'the same files again',
    );
    kept.save('A', {...hello, 'Form1.gbas': "' changed\n"});
    expect(kept.read('A')!.changedSinceDownload, isTrue);
    kept.save('A', hello);
    expect(
      kept.read('A')!.changedSinceDownload,
      isTrue,
      reason: 'still not downloaded since the change',
    );
  });

  test('a project from a .zip is not changed since a download', () {
    kept.save('A', hello, fromFile: true);
    expect(kept.read('A')!.changedSinceDownload, isFalse);
  });

  test('entries that cannot be read are left out and left alone', () {
    storage.values['gubasic.ide.project.broken'] = '{not json';
    storage.values['gubasic.ide.project.newer'] = jsonEncode({
      'formatVersion': browserProjectVersion + 1,
    });
    kept.save('A', hello);
    expect(kept.list().map((p) => p.name), ['A']);
    expect(storage.values, contains('gubasic.ide.project.broken'));
    expect(storage.values, contains('gubasic.ide.project.newer'));
  });

  test('a full storage fails the save and keeps what was there', () {
    kept.save('A', hello);
    storage.full = true;
    expect(
      () => kept.save('A', {...hello, 'Form1.gbas': 'x'}),
      throwsA(isA<StorageFailed>()),
    );
    expect(kept.read('A')!.files, hello);
  });

  test('the notice is remembered', () {
    expect(kept.noticeShown, isFalse);
    kept.markNoticeShown();
    expect(kept.noticeShown, isTrue);
    expect(storage.values.keys, ['gubasic.ide.noticeShown']);
  });
}
