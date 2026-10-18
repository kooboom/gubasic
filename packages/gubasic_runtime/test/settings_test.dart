import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

void main() {
  test(
    'each project keeps its own settings, under gubasic.settings.',
    () async {
      SharedPreferencesAsyncPlatform.instance =
          InMemorySharedPreferencesAsync.empty();
      final store = GbPreferencesSettings();
      expect(await store.load('Quiz'), isNull);
      await store.save('Quiz', '{"best":"3"}');
      await store.save('Hello', '{"visits":"1"}');
      expect(await store.load('Quiz'), '{"best":"3"}');
      expect(await store.load('Hello'), '{"visits":"1"}');
      expect(await SharedPreferencesAsync().getKeys(), {
        'gubasic.settings.Quiz',
        'gubasic.settings.Hello',
      });
      await store.clear('Quiz');
      expect(await store.load('Quiz'), isNull);
      expect(await store.load('Hello'), '{"visits":"1"}');
    },
  );

  test('settings in memory, for tests', () async {
    final store = GbMemorySettings();
    await store.save('Quiz', 'a');
    expect(await store.load('Quiz'), 'a');
    await store.clear('Quiz');
    expect(store.values, isEmpty);
  });
}
