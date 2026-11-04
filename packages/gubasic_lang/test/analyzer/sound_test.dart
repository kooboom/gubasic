import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The `Sound` object as the analyzer and the project file see it
/// (docs/DESIGN.md D138); what it does when it runs is in the parity
/// program sound_play.
void main() {
  List<String> codes(String source, {List<String>? sounds}) => [
        for (final d in compile(source, sounds: sounds).diagnostics)
          '${d.code.code}@${d.line}',
      ];

  test('Play, PlayMusic, StopMusic and Volume', () {
    expect(codes('''
Sub Main()
    Sound.Play("shot.wav")
    Sound.PlayMusic("music.mp3")
    Sound.StopMusic()
    Sound.Volume = Sound.Volume - 10
End Sub
''', sounds: ['shot.wav', 'music.mp3']), isEmpty);
  });

  test('a sound the project does not have, written as text (A082)', () {
    final d = compile('''
Sub Main()
    Sound.Play("SHOT.WAV")
    Sound.PlayMusic("gone.mp3")
    Sound.Play(someName)
End Sub
''', sounds: ['shot.wav']).diagnostics;
    expect(d.map((d) => '${d.code.code}@${d.line}'),
        containsAll(['A082@3', 'A001@4']));
    expect(d.where((d) => d.code.code == 'A082').single.isError, isFalse);
    expect(d.where((d) => d.code.code == 'A082').single.message,
        startsWith('This project has no sound "gone.mp3"'));
    // Without a project the names are not known: no warning.
    expect(codes('Sub Main()\n    Sound.Play("gone.mp3")\nEnd Sub\n'), isEmpty);
  });

  test('Visual Basic .NET\'s Stop points to StopMusic (A036)', () {
    expect(codes('Sub Main()\n    Sound.Stop()\nEnd Sub\n'), ['A036@2']);
  });

  test('the project file lists sounds, as version 4 (F025, F026)', () {
    final r = readProjectFile('''
formatVersion: 4
name: Shooter
forms:
  - Form1
sounds:
  - shot.wav
  - Music.MP3
''');
    expect(r.diagnostics, isEmpty);
    expect(r.project.sounds, ['shot.wav', 'Music.MP3']);
    expect(writeProjectFile(r.project), contains('formatVersion: 4\n'));
    expect(writeProjectFile(r.project),
        endsWith('sounds:\n  - shot.wav\n  - Music.MP3\n'));
    final bad = readProjectFile('''
formatVersion: 4
name: Shooter
forms:
  - Form1
sounds:
  - shot.ogg
  - "a:b.wav"
  - shot.wav
  - SHOT.WAV
''');
    expect(bad.diagnostics.map((d) => d.code.code), ['F025', 'F025', 'F026']);
    expect(bad.project.sounds, ['shot.wav']);
    // Without sounds a project stays the version it was.
    expect(writeProjectFile(ProjectFile(name: 'A', forms: const ['Form1'])),
        startsWith('formatVersion: 1\n'));
  });

  test('sound names: .wav or .mp3, otherwise as a picture\'s', () {
    expect(soundNameProblem('shot.wav'), isNull);
    expect(soundNameProblem('노래.MP3'), isNull);
    expect(soundNameProblem('shot.ogg'), SoundNameProblem.extension);
    expect(soundNameProblem('a/b.wav'), SoundNameProblem.character);
    expect(soundNameProblem(''), SoundNameProblem.length);
    expect(soundNamed(['Shot.wav'], 'SHOT.WAV'), 'Shot.wav');
    expect(soundNamed(['Shot.wav'], 'hit.wav'), isNull);
  });
}
