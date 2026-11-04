import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The `Sound` object of a running program (docs/DESIGN.md D138): the
/// interpreter's [SoundComponent], playing through the runtime's [GbSound]
/// the bytes [sounds] gives for a name; a name it has no bytes for is
/// R053.
class PlayerSound extends SoundComponent {
  PlayerSound(this._engine, this._sounds);

  final GbSound _engine;
  final GbSoundSource? _sounds;

  Uint8List _bytes(String name) =>
      _sounds?.call(name) ?? (throw SoundComponent.notFound(name));

  @override
  Future<void> play(String name) => _engine.play(name, _bytes(name));

  @override
  Future<void> playMusic(String name) => _engine.playMusic(name, _bytes(name));

  @override
  Future<void> stopMusic() => _engine.stopMusic();

  @override
  void volumeChanged() => _engine.setVolume(volume / 100);
}
