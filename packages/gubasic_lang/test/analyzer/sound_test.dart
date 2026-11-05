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

  test("Visual Basic 6's Beep points to Sound.Play (A083)", () {
    final d = compile('''
Sub Main()
    Beep
    Beep()
End Sub
''').diagnostics;
    expect(d.map((d) => '${d.code.code}@${d.line}'), ['A083@2', 'A083@3']);
    expect(
        d.first.message,
        'Beep is not in GuBASIC. Add a short sound in File → Sounds and play '
        'it with Sound.Play, as Sound.Play("beep.wav").');
    // No replacement: the project needs the sound first.
    expect(d.first.replacements, isEmpty);
    expect(koreanMessages[d.first.code], startsWith('GuBASIC에는 Beep이 없습니다.'));
  });

  test('a Sub of its own named Beep is not pointed anywhere', () {
    expect(codes('''
Sub Beep()
    Debug.Print("beep")
End Sub

Sub Main()
    Beep()
End Sub
'''), isEmpty);
  });

  test("Visual Basic 6's sound calls by Declare are P044", () {
    final d = compile('''
Declare Function PlaySound Lib "winmm.dll" Alias "PlaySoundA" (ByVal name As String, ByVal hmod As Long, ByVal flags As Long) As Long
Declare Function sndPlaySound Lib "winmm.dll" Alias "sndPlaySoundA" (ByVal name As String, ByVal flags As Long) As Long
Declare Function mciSendString Lib "winmm.dll" Alias "mciSendStringA" (ByVal command As String, ByVal ret As String, ByVal size As Long, ByVal hwnd As Long) As Long
Declare Function MessageBeep Lib "user32" (ByVal kind As Long) As Long
Declare Function Beep Lib "kernel32" (ByVal freq As Long, ByVal ms As Long) As Long
Declare Sub Sleep Lib "kernel32" (ByVal ms As Long)

Sub Main()
    Debug.Print("hi")
End Sub
''').diagnostics;
    expect(d.map((d) => '${d.code.code}@${d.line}'),
        ['P044@1', 'P044@2', 'P044@3', 'P044@4', 'P044@5', 'P042@6']);
    expect(
        d.first.message,
        'GuBASIC has no Declare (PlaySound). Add the sound in File → Sounds '
        'and play it with Sound.Play, or Sound.PlayMusic for music.');
    expect(koreanMessages[d.first.code],
        startsWith('GuBASIC에는 Declare가 없습니다({0}).'));
  });
}
