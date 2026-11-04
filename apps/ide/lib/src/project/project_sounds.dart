import 'dart:convert';
import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';

import 'project_pictures.dart' show samePictures;

/// Why a sound was not added to the project (docs/DESIGN.md D138).
sealed class SoundRefused {
  const SoundRefused();
}

/// The `.gbproj` file has errors, so its list of sounds cannot be
/// written again.
class SoundProjectFileHasErrors extends SoundRefused {
  const SoundProjectFileHasErrors();
}

/// A name a sound cannot have.
class BadSoundName extends SoundRefused {
  const BadSoundName(this.name, this.problem);

  final String name;
  final SoundNameProblem problem;
}

/// Bytes that are not a WAV or an MP3.
class NotASound extends SoundRefused {
  const NotASound(this.name);

  final String name;
}

/// More than [maxSoundBytes].
class SoundTooLarge extends SoundRefused {
  const SoundTooLarge(this.name, this.bytes);

  final String name;
  final int bytes;
}

/// The project's sounds would take more than [maxProjectSoundBytes].
class ProjectSoundsFull extends SoundRefused {
  const ProjectSoundsFull(this.name);

  final String name;
}

/// What a sound file holds, told from its first bytes.
enum SoundFormat { wav, mp3, unknown }

/// The format of [bytes], from its signature, not its file name: a WAV is
/// `RIFF….WAVE`; an MP3 starts with an ID3 tag or a frame's sync bits.
SoundFormat soundFormat(Uint8List bytes) {
  if (bytes.length >= 12 &&
      bytes[0] == 0x52 &&
      bytes[1] == 0x49 &&
      bytes[2] == 0x46 &&
      bytes[3] == 0x46 &&
      bytes[8] == 0x57 &&
      bytes[9] == 0x41 &&
      bytes[10] == 0x56 &&
      bytes[11] == 0x45) {
    return SoundFormat.wav;
  }
  if (bytes.length >= 3 &&
      ((bytes[0] == 0x49 && bytes[1] == 0x44 && bytes[2] == 0x33) ||
          (bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0))) {
    return SoundFormat.mp3;
  }
  return SoundFormat.unknown;
}

/// Why sound [name] with [bytes] cannot be added to a project with
/// [files] and [sounds], or null when it can. A sound of the same name is
/// replaced, so its bytes do not count.
SoundRefused? checkSound(
  String name,
  Uint8List bytes,
  Map<String, String> files,
  Map<String, Uint8List> sounds,
) {
  final project = _projectFile(files);
  if (project == null || project.$2.hasErrors) {
    return const SoundProjectFileHasErrors();
  }
  if (soundNameProblem(name) case final problem?) {
    return BadSoundName(name, problem);
  }
  if (soundFormat(bytes) == SoundFormat.unknown) return NotASound(name);
  if (bytes.length > maxSoundBytes) return SoundTooLarge(name, bytes.length);
  final replaced = soundNamed(sounds.keys, name);
  var total = bytes.length;
  for (final MapEntry(:key, :value) in sounds.entries) {
    if (key != replaced) total += value.length;
  }
  if (total > maxProjectSoundBytes) return ProjectSoundsFull(name);
  return null;
}

/// [files] with the `.gbproj` file listing [sounds]; its other entries
/// are kept. The `.gbproj` file must read without errors.
Map<String, String> withSoundList(
  Map<String, String> files,
  List<String> sounds,
) {
  final (file, read) = _projectFile(files)!;
  final p = read.project;
  return {
    ...files,
    file: writeProjectFile(
      ProjectFile(
        name: p.name,
        forms: p.forms,
        startup: p.startup,
        pictures: p.pictures,
        id: p.id,
        modules: p.modules,
        sounds: sounds,
      ),
    ),
  };
}

(String, ProjectFileResult)? _projectFile(Map<String, String> files) {
  final names = [
    for (final f in files.keys)
      if (f.toLowerCase().endsWith('.gbproj')) f,
  ];
  if (names.length != 1) return null;
  return (names.single, readProjectFile(files[names.single]!));
}

/// The examples' sounds, kept as Base64 (examples.g.dart), as bytes.
Map<String, Map<String, Uint8List>> decodeExampleSounds(
  Map<String, Map<String, String>> sounds,
) => {
  for (final MapEntry(key: project, value: named) in sounds.entries)
    project: {
      for (final MapEntry(:key, :value) in named.entries)
        key: base64Decode(value),
    },
};

/// Whether [a] and [b] have the same sounds, byte for byte.
bool sameSounds(Map<String, Uint8List> a, Map<String, Uint8List> b) =>
    samePictures(a, b);
