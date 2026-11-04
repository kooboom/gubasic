import 'pictures.dart';

/// The folder of a project that holds its sounds: `Shooter/sounds/`
/// (docs/DESIGN.md D138).
const soundsFolder = 'sounds';

/// The largest sound file a project takes.
const maxSoundBytes = 4 * 1024 * 1024;

/// The most bytes all the sounds of a project may take together.
const maxProjectSoundBytes = 20 * 1024 * 1024;

/// Why a sound name cannot be used.
enum SoundNameProblem {
  /// Empty, or longer than 100 characters.
  length,

  /// A character no file name may have, or a dot or space at the start or
  /// end (as for a picture).
  character,

  /// Not `.wav` or `.mp3`: what every browser and desktop system plays.
  extension,
}

final _soundExtension = RegExp(r'\.(wav|mp3)$', caseSensitive: false);

/// Why [name] cannot be a sound's name, or null when it can. The rules are
/// a picture's but for the extension.
SoundNameProblem? soundNameProblem(String name) {
  switch (pictureNameProblem(name)) {
    case PictureNameProblem.length:
      return SoundNameProblem.length;
    case PictureNameProblem.character:
      return SoundNameProblem.character;
    case PictureNameProblem.extension || null:
      return _soundExtension.hasMatch(name) ? null : SoundNameProblem.extension;
  }
}

/// How two sound names are compared: as pictures' are ([pictureKey]).
String soundKey(String name) => pictureKey(name);

/// The name of [sounds] that is [name] as names in code are compared, or
/// null.
String? soundNamed(Iterable<String> sounds, String name) {
  final key = soundKey(name);
  for (final s in sounds) {
    if (soundKey(s) == key) return s;
  }
  return null;
}
