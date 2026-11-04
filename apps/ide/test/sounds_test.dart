import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_sounds.dart';
import 'package:gubasic_ide/src/project/project_zip.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// A project's sounds in the IDE (docs/DESIGN.md D138): what is taken,
/// the `.gbproj` file's list, and the `.zip` that carries them.
void main() {
  final hello = exampleProjects['hello']!;

  /// The smallest WAV: a RIFF/WAVE header and no samples.
  final wav = Uint8List.fromList([
    ...'RIFF'.codeUnits, 36, 0, 0, 0, ...'WAVE'.codeUnits, //
    ...'fmt '.codeUnits, 16, 0, 0, 0, 1, 0, 1, 0, 0x44, 0xAC, 0, 0, //
    0x88, 0x58, 1, 0, 2, 0, 16, 0, ...'data'.codeUnits, 0, 0, 0, 0,
  ]);
  final mp3 = Uint8List.fromList([...'ID3'.codeUnits, 4, 0, 0, 0, 0, 0, 0]);
  final frame = Uint8List.fromList([0xFF, 0xFB, 0x90, 0x00, 1, 2, 3]);

  group('checkSound', () {
    SoundRefused? check(
      String name,
      Uint8List bytes, {
      Map<String, Uint8List> sounds = const {},
    }) => checkSound(name, bytes, hello, sounds);

    test('a WAV and an MP3 are taken, by their bytes', () {
      expect(check('shot.wav', wav), isNull);
      expect(check('노래.mp3', mp3), isNull);
      expect(check('beat.MP3', frame), isNull);
      expect(soundFormat(wav), SoundFormat.wav);
      expect(soundFormat(mp3), SoundFormat.mp3);
      expect(soundFormat(Uint8List.fromList([1, 2, 3])), SoundFormat.unknown);
    });

    test('what is refused', () {
      expect(check('shot.ogg', wav), isA<BadSoundName>());
      expect(check('a:b.wav', wav), isA<BadSoundName>());
      expect(
        check('shot.wav', Uint8List.fromList([1, 2, 3])),
        isA<NotASound>(),
      );
      final tooBig = Uint8List(maxSoundBytes + 1)..setRange(0, wav.length, wav);
      expect(check('shot.wav', tooBig), isA<SoundTooLarge>());
      final big = Uint8List(maxSoundBytes);
      big.setRange(0, wav.length, wav);
      expect(
        check(
          'six.wav',
          wav,
          sounds: {for (var i = 0; i < 5; i++) 'big$i.wav': big},
        ),
        isA<ProjectSoundsFull>(),
      );
      expect(check('shot.wav', wav, sounds: const {}), isNull);
      expect(
        checkSound('shot.wav', wav, {'X.gbproj': 'name: [', ...hello}, {}),
        isA<SoundProjectFileHasErrors>(),
      );
    });
  });

  test('the project lists its sounds, as version 4, and takes them out', () {
    final project = OpenProject(const ExampleLocation('hello'), hello);
    expect(project.isDirty, isFalse);
    project.setSound('shot.wav', wav);
    expect(project.sounds.keys, ['shot.wav']);
    expect(project.isDirty, isTrue);
    final file = project.files['Hello.gbproj']!;
    expect(file, contains('formatVersion: 4\n'));
    expect(file, endsWith('sounds:\n  - shot.wav\n'));
    expect(readProjectFile(file).project.sounds, ['shot.wav']);
    // The same name in another case replaces it, keeping the spelling.
    project.setSound('SHOT.WAV', mp3);
    expect(project.sounds, {'shot.wav': mp3});
    project.removeSound('shot.wav');
    expect(project.sounds, isEmpty);
    expect(project.files['Hello.gbproj'], isNot(contains('sounds:')));
    expect(project.files['Hello.gbproj'], startsWith('formatVersion: 1\n'));
  });

  test('a .zip carries the sounds in NAME/sounds/ and reads them back', () {
    final project = OpenProject(const ExampleLocation('hello'), hello)
      ..setSound('shot.wav', wav)
      ..setSound('music.mp3', mp3);
    final bytes = zipProject(
      'Hello',
      project.files,
      pictures: project.pictures,
      sounds: project.sounds,
    );
    final back = unzipProject(bytes);
    expect(back.name, 'Hello');
    expect(back.sounds.keys, unorderedEquals(['shot.wav', 'music.mp3']));
    expect(back.sounds['shot.wav'], wav);
    expect(back.missing, isEmpty);
    expect(back.ignored, isEmpty);
    // A sound the .gbproj does not list is left out and named; one it
    // lists that is not there is missing.
    final listedOnly = unzipProject(
      zipProject(
        'Hello',
        project.files,
        sounds: {'shot.wav': wav, 'x.wav': wav},
      ),
    );
    expect(listedOnly.sounds.keys, ['shot.wav']);
    expect(listedOnly.ignored, ['Hello/sounds/x.wav']);
    expect(listedOnly.missing, ['sounds/music.mp3']);
  });
}
