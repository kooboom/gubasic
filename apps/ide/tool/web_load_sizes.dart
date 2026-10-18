// Writes build/web/load_sizes.json: the size of each big file the web IDE
// fetches before its first frame, for the "Loading… 37%" text
// (web/flutter_bootstrap.js, D43). Run after `flutter build web`; CI and
// the Pages workflow do.
//
//   dart run tool/web_load_sizes.dart [build/web]
import 'dart:convert';
import 'dart:io';

void main(List<String> args) {
  final web = Directory(args.isEmpty ? 'build/web' : args.first);
  final sizes = loadSizes(web);
  // A Flutter that moved these would leave the text without a percentage.
  for (final path in ['main.dart.js', 'canvaskit/canvaskit.wasm']) {
    if (!sizes.containsKey(path)) {
      stderr.writeln('${web.path}/$path is missing: build the web IDE first.');
      exit(1);
    }
  }
  File('${web.path}/load_sizes.json').writeAsStringSync(jsonEncode(sizes));
  stdout.writeln('load_sizes.json: ${sizes.length} files');
}

/// The app's code, every CanvasKit build the loader may choose, and the
/// fonts the engine loads at start ([web]/assets/FontManifest.json), by
/// path from the page, with their sizes as the browser gets them after
/// decompressing.
Map<String, int> loadSizes(Directory web) {
  final paths = [
    'main.dart.js',
    for (final variant in ['', 'chromium/', 'webparagraph/'])
      'canvaskit/${variant}canvaskit.wasm',
    for (final family in jsonDecode(
      File('${web.path}/assets/FontManifest.json').readAsStringSync(),
    ) as List)
      for (final font in (family as Map)['fonts'] as List)
        'assets/${(font as Map)['asset']}',
  ];
  return {
    for (final path in paths)
      if (File('${web.path}/$path') case final file when file.existsSync())
        path: file.lengthSync(),
  };
}
