import 'dart:io';

// Only the bundle: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// Makes the LiveQuiz example's bundle (`.gbz`, D83), as the IDE's export
/// would, into `build/livequiz/livequiz.gbz`, with both forms' Room.Server
/// set to a relay server on this computer, so that tool/web_check's
/// livequiz.mjs can play one round in two browsers (D136):
///
///     dart run tool/livequiz_bundle.dart [ws://127.0.0.1:7181/room]
void main(List<String> args) {
  final server = args.isEmpty ? 'ws://127.0.0.1:7181/room' : args.first;
  final dir = Directory('../../examples/livequiz');
  final files = <String, String>{
    for (final f in dir.listSync().whereType<File>())
      f.uri.pathSegments.last: f.readAsStringSync(),
  };
  files['FormTV.form.yaml'] = files['FormTV.form.yaml']!.replaceFirst(
    '      Nickname: TV\n',
    '      Nickname: TV\n      Server: $server\n',
  );
  files['FormPhone.form.yaml'] = files['FormPhone.form.yaml']!.replaceFirst(
    '  - name: rmQuiz\n    type: Room\n',
    '  - name: rmQuiz\n    type: Room\n    properties:\n      Server: $server\n',
  );
  final pictures = {
    for (final f in Directory(
      '${dir.path}/pictures',
    ).listSync().whereType<File>())
      f.uri.pathSegments.last: f.readAsBytesSync(),
  };
  final out = Directory('build/livequiz')..createSync(recursive: true);
  File('${out.path}/livequiz.gbz').writeAsBytesSync(
    ProjectBundle(
      id: 'examplelivequiz',
      name: 'LiveQuiz',
      files: files,
      pictures: pictures,
    ).encode(),
  );
  stdout.writeln('${out.path}/livequiz.gbz: Room.Server = $server');
}
