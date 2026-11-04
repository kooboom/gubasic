import 'dart:io';
import 'dart:typed_data';

// Only the bundle: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// Makes the Shooter example's bundle (`.gbz`, D83), as the IDE's export
/// would, into `build/shooter/shooter.gbz`, pictures and sounds included,
/// so that tool/web_check's shooter.mjs can play it in a browser (D138):
///
///     dart run tool/shooter_bundle.dart
void main() {
  final dir = Directory('../../examples/shooter');
  Map<String, Uint8List> bytesOf(String folder) => {
    for (final f in Directory(
      '${dir.path}/$folder',
    ).listSync().whereType<File>())
      f.uri.pathSegments.last: f.readAsBytesSync(),
  };
  final out = Directory('build/shooter')..createSync(recursive: true);
  File('${out.path}/shooter.gbz').writeAsBytesSync(
    ProjectBundle(
      id: 'exampleshooter',
      name: 'Shooter',
      files: {
        for (final f in dir.listSync().whereType<File>())
          f.uri.pathSegments.last: f.readAsStringSync(),
      },
      pictures: bytesOf('pictures'),
      sounds: bytesOf('sounds'),
    ).encode(),
  );
  stdout.writeln('${out.path}/shooter.gbz');
}
