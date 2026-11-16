import 'dart:io';
import 'dart:typed_data';

// Only the bundle: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// Makes the Duel example's bundle (`.gbz`, D83), as the IDE's export
/// would, into `build/duel/duel.gbz`, pictures and sounds included,
/// so that tool/web_check's duel.mjs can play it in a browser (D139):
///
///     dart run tool/duel_bundle.dart
void main() {
  final dir = Directory('../../examples/duel');
  Map<String, Uint8List> bytesOf(String folder) => {
    for (final f in Directory(
      '${dir.path}/$folder',
    ).listSync().whereType<File>())
      f.uri.pathSegments.last: f.readAsBytesSync(),
  };
  final out = Directory('build/duel')..createSync(recursive: true);
  File('${out.path}/duel.gbz').writeAsBytesSync(
    ProjectBundle(
      id: 'exampleduel',
      name: 'Duel',
      files: {
        for (final f in dir.listSync().whereType<File>())
          f.uri.pathSegments.last: f.readAsStringSync(),
      },
      pictures: bytesOf('pictures'),
      sounds: bytesOf('sounds'),
    ).encode(),
  );
  stdout.writeln('${out.path}/duel.gbz');
}
