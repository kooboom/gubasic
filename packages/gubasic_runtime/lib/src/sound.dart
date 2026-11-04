import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_soloud/flutter_soloud.dart';

/// The bytes of the project's sound [name] (WAV or MP3), or null when
/// there is none; names are compared as pictures' are, in any case.
typedef GbSoundSource = Uint8List? Function(String name);

/// [sounds] for a program to play, found by name in any case.
GbSoundSource soundSource(Map<String, Uint8List> sounds) {
  final byKey = {
    for (final MapEntry(:key, :value) in sounds.entries)
      key.toLowerCase(): value,
  };
  return (name) => byKey[name.toLowerCase()];
}

/// Plays a program's sounds (docs/DESIGN.md D138): an effect at once,
/// several overlapping, and one piece of music round and round. The real
/// one mixes with flutter_soloud, chosen by measurement
/// (docs/plans/PLAN_V07.md §7.1); tests give a fake. Each sound's bytes
/// are decoded once, by [name].
abstract class GbSound {
  factory GbSound() => _SoLoudSound();

  /// Plays [bytes], the sound [name], once over whatever plays.
  Future<void> play(String name, Uint8List bytes);

  /// Plays [bytes], the sound [name], round and round, in place of the
  /// music playing.
  Future<void> playMusic(String name, Uint8List bytes);

  /// Stops the music, if any plays.
  Future<void> stopMusic();

  /// The volume of everything, from 0 to 1.
  void setVolume(double volume);

  /// Stops everything and forgets the decoded sounds: the program ended.
  Future<void> stopAll();
}

/// GbSound over flutter_soloud. The engine starts on the first play and
/// stays for the next program; on the web a page may play sound only
/// after the user has clicked or pressed a key, so a play before that is
/// dropped without an error (D138).
class _SoLoudSound implements GbSound {
  final _sources = <String, AudioSource>{};
  SoundHandle? _music;
  var _volume = 1.0;

  Future<bool> _ready() async {
    final engine = SoLoud.instance;
    if (engine.isInitialized) return true;
    try {
      await engine.init();
      engine.setGlobalVolume(_volume);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<AudioSource?> _source(String name, Uint8List bytes) async {
    if (!await _ready()) return null;
    final key = name.toLowerCase();
    if (_sources[key] case final loaded?) return loaded;
    try {
      return _sources[key] = await SoLoud.instance.loadMem(name, bytes);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> play(String name, Uint8List bytes) async {
    final source = await _source(name, bytes);
    if (source == null) return;
    try {
      SoLoud.instance.play(source);
    } catch (_) {
      // Not a sound the engine can play: silence, as on the web before
      // the first click.
    }
  }

  @override
  Future<void> playMusic(String name, Uint8List bytes) async {
    await stopMusic();
    final source = await _source(name, bytes);
    if (source == null) return;
    try {
      _music = SoLoud.instance.play(source, looping: true);
    } catch (_) {
      _music = null;
    }
  }

  @override
  Future<void> stopMusic() async {
    final handle = _music;
    _music = null;
    if (handle == null || !SoLoud.instance.isInitialized) return;
    try {
      await SoLoud.instance.stop(handle);
    } catch (_) {}
  }

  @override
  void setVolume(double volume) {
    _volume = volume.clamp(0, 1);
    if (SoLoud.instance.isInitialized) {
      SoLoud.instance.setGlobalVolume(_volume);
    }
  }

  @override
  Future<void> stopAll() async {
    await stopMusic();
    if (!SoLoud.instance.isInitialized) {
      _sources.clear();
      return;
    }
    for (final source in _sources.values) {
      try {
        await SoLoud.instance.disposeSource(source);
      } catch (_) {}
    }
    _sources.clear();
  }
}
