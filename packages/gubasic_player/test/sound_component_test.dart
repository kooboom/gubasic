import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
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

  // The engine's own start holds the app's thread for about a tenth of a
  // second (STAGE2_PLAN §7, the Duel): a program that uses Sound starts it
  // at its first click or key, not at a sound in the middle of a game. One
  // that does not never starts it (no AudioContext on a page that never
  // sounds).
  for (final uses in [true, false]) {
    testWidgets(
      uses
          ? 'a program that uses Sound starts the engine at its first click'
          : 'a program without Sound never starts the engine',
      (tester) async {
        final form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnGo, type: Button, properties: { Caption: Go, Width: 80, Height: 30 } }
''', name: 'Form1').form;
        final code = uses
            ? 'Sub btnGo_Click()\nIf False Then Sound.Play("hit.wav")\nEnd Sub\n'
            : 'Sub btnGo_Click()\nbtnGo.Tag = "Went"\nEnd Sub\n';
        final program = compile(code, form: form, sounds: ['hit.wav']);
        expect(program.diagnostics, isEmpty);
        expect(program.usesSound, uses);
        final engine = _SlowSound();
        final host = RunHost(
          form,
          settings: GbMemorySettings(),
          sound: engine,
          sounds: (name) => Uint8List(4),
        );
        final session = RunSession(
          StartupForm(form, 'Form1.gbas', program, null),
          strings: PlayerStrings.en,
          host: host,
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(child: RunWindow(session: session)),
            ),
          ),
        );
        await tester.pump();
        expect(engine.started, 0, reason: 'not before the user acts');
        await tester.tap(find.text('Go'));
        await tester.pump();
        expect(engine.started, uses ? 1 : 0);
        await tester.tap(find.text('Go'));
        await tester.pump();
        expect(engine.started, uses ? 1 : 0, reason: 'once');
        engine.done.complete();
        session.closeForm();
        await tester.pump();
        session.dispose();
      },
    );
  }

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

  var started = 0;

  @override
  Future<bool> start() async {
    started++;
    return true;
  }
}
