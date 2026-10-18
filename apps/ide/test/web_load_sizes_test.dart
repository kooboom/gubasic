import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../tool/web_load_sizes.dart';

void main() {
  test('the loading percentage counts the code, the engines and the fonts', () {
    final web = Directory.systemTemp.createTempSync('web_load_sizes');
    addTearDown(() => web.deleteSync(recursive: true));
    void put(String path, int size) => (File(
      '${web.path}/$path',
    )..createSync(recursive: true)).writeAsBytesSync(List.filled(size, 0));
    put('main.dart.js', 30);
    put('canvaskit/canvaskit.wasm', 70);
    put('canvaskit/chromium/canvaskit.wasm', 50);
    put('canvaskit/canvaskit.js', 1);
    put('assets/fonts/Pretendard-Regular.otf', 40);
    put('flutter_bootstrap.js', 2);
    File('${web.path}/assets/FontManifest.json').writeAsStringSync(
      jsonEncode([
        {
          'family': 'Pretendard',
          'fonts': [
            {'asset': 'fonts/Pretendard-Regular.otf'},
            // Listed but not built: left out rather than counted as 0.
            {'weight': 700, 'asset': 'fonts/Pretendard-Bold.otf'},
          ],
        },
      ]),
    );
    expect(loadSizes(web), {
      'main.dart.js': 30,
      'canvaskit/canvaskit.wasm': 70,
      'canvaskit/chromium/canvaskit.wasm': 50,
      'assets/fonts/Pretendard-Regular.otf': 40,
    });
  });
}
