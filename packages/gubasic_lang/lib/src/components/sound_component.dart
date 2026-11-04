import '../diagnostics/diagnostic.dart';
import '../interpreter/checked_math.dart';
import '../interpreter/host.dart';

/// The `Sound` object of a running program (docs/DESIGN.md D138): the
/// project's sounds played through the component channel, as `Http` is.
/// A host gives one that plays: the run window's through the runtime, a
/// test's one that records. `Play` and `PlayMusic` do not wait for the
/// sound to end: a game loop cannot stop for one.
abstract class SoundComponent implements ComponentInstance {
  /// `Volume`, from 0 to 100; 100 at first.
  int volume = 100;

  /// Plays [name] once, over whatever plays; throws a [ComponentProblem]
  /// (R053) when the project has no such sound.
  Future<void> play(String name);

  /// Plays [name] round and round, in place of the music playing.
  Future<void> playMusic(String name);

  /// Stops the music, if any plays.
  Future<void> stopMusic();

  /// The volume changed: [volume] from 0 to 100.
  void volumeChanged();

  @override
  Object? getProperty(String name) => GbInt.of(volume);

  @override
  void setProperty(String name, Object? value) {
    volume = (value as GbInt).toSmallInt()!;
    volumeChanged();
  }

  @override
  void assign(String name, List<Object?> args, Object? value) {
    throw StateError('nothing settable on Sound');
  }

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    switch (name) {
      case 'Play':
        await play(args[0] as String);
        return null;
      case 'PlayMusic':
        await playMusic(args[0] as String);
        return null;
      case 'StopMusic':
        await stopMusic();
        return null;
    }
    throw StateError('no code for Sound.$name');
  }

  /// The problem a sound the project does not have is (R053).
  static ComponentProblem notFound(String name) =>
      ComponentProblem(DiagnosticCode.soundNotFound, [name]);
}
