import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'save.dart';

/// Measures how fast two audio packages start a sound (docs/plans/PLAN_V07.md
/// §7): the milliseconds from the call to the first progress the package
/// reports, for one short effect, for the same effect twenty times in quick
/// succession, and for five different sounds at once. It writes its results
/// as one JSON line, `SOUND_PROBE {…}`, to the console, and on the desktop
/// to a file in the Downloads folder.
void main() => runApp(const ProbeApp());

/// A 16-bit mono WAV of [seconds] at 44.1 kHz, [sample] giving each frame
/// from -1 to 1.
Uint8List wav(double seconds, double Function(int i, double t) sample) {
  const rate = 44100;
  final frames = (seconds * rate).round();
  final data = ByteData(44 + frames * 2);
  void ascii(int at, String s) {
    for (var i = 0; i < s.length; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  ascii(0, 'RIFF');
  data.setUint32(4, 36 + frames * 2, Endian.little);
  ascii(8, 'WAVE');
  ascii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 1, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 2, Endian.little);
  data.setUint16(32, 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  ascii(36, 'data');
  data.setUint32(40, frames * 2, Endian.little);
  for (var i = 0; i < frames; i++) {
    final v = sample(i, i / rate).clamp(-1.0, 1.0);
    data.setInt16(44 + i * 2, (v * 32767).round(), Endian.little);
  }
  return data.buffer.asUint8List();
}

/// The sounds of the game example: a shot, a hit (noise), a short beep, a
/// longer tone and a chord.
Map<String, Uint8List> makeSounds() {
  final random = math.Random(1);
  double envelope(double t, double length) => (1 - t / length).clamp(0, 1);
  return {
    'shot.wav': wav(
      0.05,
      (i, t) =>
          envelope(t, 0.05) *
          (math.sin(t * 880 * 2 * math.pi) > 0 ? 0.5 : -0.5),
    ),
    'hit.wav': wav(
      0.08,
      (i, t) => envelope(t, 0.08) * (random.nextDouble() * 2 - 1) * 0.6,
    ),
    'beep.wav': wav(0.03, (i, t) => 0.5 * math.sin(t * 440 * 2 * math.pi)),
    'tone.wav': wav(
      0.5,
      (i, t) => envelope(t, 0.5) * 0.4 * math.sin(t * 330 * 2 * math.pi),
    ),
    'chord.wav': wav(
      0.3,
      (i, t) =>
          envelope(t, 0.3) *
          0.2 *
          (math.sin(t * 262 * 2 * math.pi) +
              math.sin(t * 330 * 2 * math.pi) +
              math.sin(t * 392 * 2 * math.pi)),
    ),
  };
}

/// One package, behind the same questions.
abstract class Engine {
  String get name;
  Future<String?> prepare(Map<String, Uint8List> sounds);

  /// Starts [name] and completes with the milliseconds until the package
  /// first reports progress, or -1 when it does not within a second.
  Future<int> play(String name);
  Future<void> dispose();
}

class AudioplayersEngine implements Engine {
  @override
  String get name => 'audioplayers $audioplayersVersion';

  late Map<String, Uint8List> _sounds;
  final _players = <AudioPlayer>[];

  @override
  Future<String?> prepare(Map<String, Uint8List> sounds) async {
    _sounds = sounds;
    // One warm-up, so that the first measured play is not the engine's start.
    await play('beep.wav');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return null;
  }

  @override
  Future<int> play(String name) async {
    final player = AudioPlayer();
    _players.add(player);
    await player.setReleaseMode(ReleaseMode.release);
    final started = Completer<int>();
    final watch = Stopwatch()..start();
    late final StreamSubscription<Duration> sub;
    sub = player.onPositionChanged.listen((p) {
      if (p > Duration.zero && !started.isCompleted) {
        started.complete(watch.elapsedMilliseconds);
      }
    });
    late final StreamSubscription<PlayerState> stateSub;
    stateSub = player.onPlayerStateChanged.listen((s) {
      if (s == PlayerState.playing && !started.isCompleted) {
        // Progress may come later; the state is the earliest sign.
        started.complete(watch.elapsedMilliseconds);
      }
    });
    unawaited(
      player.play(
        BytesSource(_sounds[name]!, mimeType: 'audio/wav'),
        mode: PlayerMode.lowLatency,
      ),
    );
    final ms = await started.future.timeout(
      const Duration(seconds: 1),
      onTimeout: () => -1,
    );
    unawaited(sub.cancel());
    unawaited(stateSub.cancel());
    return ms;
  }

  @override
  Future<void> dispose() async {
    for (final p in _players) {
      await p.dispose();
    }
  }
}

class SoloudEngine implements Engine {
  @override
  String get name => 'flutter_soloud $soloudVersion';

  final _sources = <String, AudioSource>{};

  @override
  Future<String?> prepare(Map<String, Uint8List> sounds) async {
    try {
      await SoLoud.instance.init();
    } catch (e) {
      return '$e';
    }
    for (final MapEntry(:key, :value) in sounds.entries) {
      _sources[key] = await SoLoud.instance.loadMem(key, value);
    }
    await play('beep.wav');
    await Future<void>.delayed(const Duration(milliseconds: 300));
    return null;
  }

  @override
  Future<int> play(String name) async {
    final watch = Stopwatch()..start();
    final handle = SoLoud.instance.play(_sources[name]!);
    while (watch.elapsedMilliseconds < 1000) {
      if (SoLoud.instance.getPosition(handle) > Duration.zero) {
        return watch.elapsedMilliseconds;
      }
      if (!SoLoud.instance.getIsValidVoiceHandle(handle)) {
        // Over before it was seen: the shortest sounds.
        return watch.elapsedMilliseconds;
      }
      await Future<void>.delayed(const Duration(milliseconds: 1));
    }
    return -1;
  }

  @override
  Future<void> dispose() async {
    for (final s in _sources.values) {
      await SoLoud.instance.disposeSource(s);
    }
    SoLoud.instance.deinit();
  }
}

const audioplayersVersion = '6.8.1';
const soloudVersion = '5.2.2';

/// The three cases of one package.
Future<Map<String, Object?>> measure(
  Engine engine,
  Map<String, Uint8List> sounds,
) async {
  final result = <String, Object?>{'package': engine.name};
  final problem = await engine.prepare(sounds);
  if (problem != null) {
    result['error'] = problem;
    return result;
  }
  // 1. One short effect, five times with a pause between.
  final single = <int>[];
  for (var i = 0; i < 5; i++) {
    single.add(await engine.play('shot.wav'));
    await Future<void>.delayed(const Duration(milliseconds: 250));
  }
  result['single'] = single;
  // 2. The same effect twenty times, 10 ms apart, each on its own.
  final rapid = <Future<int>>[];
  for (var i = 0; i < 20; i++) {
    rapid.add(engine.play('shot.wav'));
    await Future<void>.delayed(const Duration(milliseconds: 10));
  }
  result['rapid'] = await Future.wait(rapid);
  await Future<void>.delayed(const Duration(milliseconds: 500));
  // 3. Five different sounds at once.
  result['overlap'] = await Future.wait([
    for (final name in sounds.keys) engine.play(name),
  ]);
  await Future<void>.delayed(const Duration(milliseconds: 800));
  await engine.dispose();
  return result;
}

String summary(List<Map<String, Object?>> results) {
  String stats(Object? list) {
    final values = (list as List).cast<int>();
    final ok = values.where((v) => v >= 0).toList()..sort();
    if (ok.isEmpty) return 'none started';
    final median = ok[ok.length ~/ 2];
    return 'median $median ms, max ${ok.last} ms, ${ok.length}/${values.length} started';
  }

  final b = StringBuffer();
  for (final r in results) {
    b.writeln(r['package']);
    if (r['error'] != null) {
      b.writeln('  could not start: ${r['error']}');
      continue;
    }
    b.writeln('  one effect: ${stats(r['single'])}');
    b.writeln('  twenty in a row: ${stats(r['rapid'])}');
    b.writeln('  five at once: ${stats(r['overlap'])}');
  }
  return '$b';
}

class ProbeApp extends StatefulWidget {
  const ProbeApp({super.key});

  @override
  State<ProbeApp> createState() => _ProbeAppState();
}

class _ProbeAppState extends State<ProbeApp> {
  String _text = kIsWeb
      ? 'Press Start (the browser plays sound only after a click).'
      : 'Starting in a moment…';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    if (!kIsWeb) Timer(const Duration(seconds: 1), _run);
  }

  Future<void> _run() async {
    if (_running) return;
    setState(() {
      _running = true;
      _text = 'Measuring…';
    });
    final sounds = makeSounds();
    final results = <Map<String, Object?>>[];
    for (final engine in [AudioplayersEngine(), SoloudEngine()]) {
      try {
        results.add(await measure(engine, sounds));
      } catch (e) {
        results.add({'package': engine.name, 'error': '$e'});
      }
      setState(() => _text = summary(results));
    }
    final platform = kIsWeb ? 'web' : defaultTargetPlatform.name;
    final json = jsonEncode({'platform': platform, 'results': results});
    debugPrint('SOUND_PROBE $json');
    final where = await saveResults('sound-probe-$platform.json', json);
    setState(
      () => _text = '${summary(results)}\n${where ?? ''}\nSOUND_PROBE_DONE',
    );
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    home: Scaffold(
      appBar: AppBar(title: const Text('Sound probe')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            FilledButton(
              key: const ValueKey('start'),
              onPressed: _running ? null : _run,
              child: const Text('Start'),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Text(
                  _text,
                  key: const ValueKey('text'),
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
