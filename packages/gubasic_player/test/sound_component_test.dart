import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// `Sound.Play` does not wait (docs/DESIGN.md D138): the first play starts
/// the engine and decodes the sound, which took a Duel tick 120 to 320 ms
/// when the call waited for it; the game's loop must go on meanwhile.
void main() {
  test('Play returns before the engine has played', () async {
    final engine = _SlowSound();
    final sound = PlayerSound(engine, (name) => Uint8List(4));
    await sound.play('hit.wav').timeout(const Duration(milliseconds: 50));
    expect(engine.asked, ['hit.wav']);
    engine.done.complete();
  });

  test('a sound the project does not have is still R053 at once', () async {
    final sound = PlayerSound(_SlowSound(), (name) => null);
    expect(() => sound.play('none.wav'), throwsA(isA<ComponentProblem>()));
  });
}

/// An engine that takes its time, as flutter_soloud starting.
class _SlowSound implements GbSound {
  final asked = <String>[];
  final done = Completer<void>();

  @override
  Future<void> play(String name, Uint8List bytes) {
    asked.add(name);
    return done.future;
  }

  @override
  Future<void> playMusic(String name, Uint8List bytes) => done.future;

  @override
  Future<void> stopMusic() async {}

  @override
  void setVolume(double volume) {}

  @override
  Future<void> stopAll() async {}
}
