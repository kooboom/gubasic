// Runs in Chrome: flutter test --platform chrome test/web
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/platform_browser.dart';
import 'package:web/web.dart' as web;

void main() {
  final hello = exampleProjects['hello']!;
  late BrowserStorage storage;

  setUp(() {
    web.window.localStorage.clear();
    storage = platformBrowser()!.storage;
  });
  tearDown(() => web.window.localStorage.clear());

  test('a project is kept in localStorage under gubasic.ide.', () {
    web.window.localStorage.setItem('playground.code', 'Debug.Print 1');
    final kept = BrowserProjects(storage)..save('내 퀴즈', hello);
    expect(
      web.window.localStorage.getItem('gubasic.ide.project.내 퀴즈'),
      isNotNull,
    );
    expect(BrowserProjects(storage).read('내 퀴즈')!.files, hello);
    kept.delete('내 퀴즈');
    expect(kept.list(), isEmpty);
    expect(web.window.localStorage.getItem('playground.code'), 'Debug.Print 1');
  });

  test('a full localStorage is StorageFailed, not a crash', () {
    final big = 'x' * (6 * 1024 * 1024);
    expect(
      () => storage.write('gubasic.ide.big', big),
      throwsA(isA<StorageFailed>()),
    );
  });
}
