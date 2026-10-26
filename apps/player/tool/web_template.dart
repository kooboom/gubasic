import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
// Only the bundle's constants: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// Makes the web player's template, `build/template.zip`, from the release
/// build in `build/web` (`flutter build web --release
/// --no-web-resources-cdn`): what the IDE downloads, adds a project to and
/// gives as a web app (D84).
///
/// It leaves out what an app built for JavaScript never loads, the engine
/// builds for WebAssembly (skwasm, wimp, webparagraph) and the debugging
/// symbols, which took the folder from 42 MB to 18 MB (STAGE2_PLAN §7);
/// makes the page's base relative (`<base href="./">`), so that the app
/// runs from any folder of any web host; and adds `template.json`, with
/// the GuBASIC it is for and the bundle layout it reads.
///
///     dart run tool/web_template.dart
void main() {
  final web = Directory('build/web');
  if (!web.existsSync()) {
    stderr.writeln('build/web is missing: run flutter build web first');
    exit(1);
  }
  final archive = Archive();
  var count = 0;
  for (final entity in web.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path
        .substring(web.path.length + 1)
        .replaceAll(r'\', '/');
    if (_leftOut(path)) continue;
    var bytes = entity.readAsBytesSync();
    if (path == 'index.html') {
      final html = utf8.decode(bytes);
      final relative = html.replaceFirst(
        RegExp(r'<base href="[^"]*">'),
        '<base href="./">',
      );
      if (relative == html) {
        stderr.writeln('index.html has no <base href>');
        exit(1);
      }
      bytes = utf8.encode(relative);
    }
    archive.add(ArchiveFile.bytes(path, bytes));
    count++;
  }
  archive.add(
    ArchiveFile.bytes(
      'template.json',
      utf8.encode(
        jsonEncode({
          'gubasic': gubasicVersion,
          'bundleFormat': bundleFormatVersion,
        }),
      ),
    ),
  );
  final out = File('build/template.zip')
    ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
  stdout.writeln(
    'build/template.zip: $count files, '
    '${(out.lengthSync() / 1e6).toStringAsFixed(1)} MB',
  );
}

/// What an app built for JavaScript never loads.
bool _leftOut(String path) {
  if (path.endsWith('.symbols') || path == '.last_build_id') return true;
  final name = path.split('/').last;
  return path.startsWith('canvaskit/') &&
      (name.startsWith('skwasm') ||
          name.startsWith('wimp') ||
          path.startsWith('canvaskit/webparagraph/'));
}
