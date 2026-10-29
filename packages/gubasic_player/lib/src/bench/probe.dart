import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:gubasic_lang/gubasic_lang.dart'
    show GbKeyEvent, GbMouseEvent, keyCodes, mouseButtons;
import 'package:gubasic_lang/testing.dart';

import '../run_session.dart';

/// Whether this build measures (STAGE2_PLAN §7): `--dart-define
/// GUBASIC_BENCH=true`. Off in every build that is not for measuring, so
/// that the calls below are compiled away.
const benchEnabled = bool.fromEnvironment('GUBASIC_BENCH');

/// Times one benchmark in the IDE or the player: drives its event script
/// once the form is shown, and prints one line, `GUBASIC_BENCH {json}`,
/// with what it measured.
class BenchProbe {
  BenchProbe(this.name, this.script, {required this.where});

  /// The probe of this run, set by the measuring build's entry point.
  static BenchProbe? current;

  final String name;
  final String script;

  /// `ide` or `player`.
  final String where;

  final _clock = Stopwatch()..start();
  RunSession? _session;
  var _driving = false;

  /// Microseconds on [_clock] when each `DoEvents` began to wait, and when
  /// the program went on after it.
  final _yieldCalls = <int>[];
  final _yieldResumes = <int>[];

  /// When the program printed `bench:start` and `bench:end`.
  int? _startAt;
  int? _endAt;

  /// When each frame was drawn, on [_clock].
  final _frameAt = <int>[];

  /// How long building and rasterising frames took, as Flutter reports it
  /// (in batches, so only their averages are used), with when it came.
  final _timings = <(int, int, int)>[];

  /// How long each step of the script took, to the frame after it.
  final _steps = <int>[];

  int get _now => _clock.elapsedMicroseconds;

  /// Called by [RunSession] as it is made.
  void attach(RunSession session) {
    _session = session;
    SchedulerBinding.instance.addTimingsCallback(_onTimings);
    SchedulerBinding.instance.addPersistentFrameCallback(
      (_) => _frameAt.add(_now),
    );
    session.addListener(_changed);
  }

  /// Called by the run window's host around each `DoEvents`.
  void yieldStarted() => _yieldCalls.add(_now);
  void yieldEnded() => _yieldResumes.add(_now);

  void _onTimings(List<FrameTiming> timings) {
    for (final t in timings) {
      _timings.add((
        _now,
        t.buildDuration.inMicroseconds,
        t.rasterDuration.inMicroseconds,
      ));
    }
  }

  void _changed() {
    final session = _session!;
    for (final line in session.output) {
      if (line.startsWith('bench:start')) _startAt ??= _now;
      if (line.startsWith('bench:end')) _endAt ??= _now;
    }
    if (session.formShown && !_driving) {
      _driving = true;
      unawaited(_drive());
    }
  }

  bool get _waitsForUser {
    final session = _session!;
    return session.host.dialogs.hasOpenDialog ||
        (session.formShown && session.interpreter.isWaitingForUser);
  }

  Future<void> _settle() async {
    for (var i = 0; i < 1000000; i++) {
      await Future<void>.delayed(Duration.zero);
      if (_session!.result != null || _waitsForUser) return;
    }
  }

  Future<void> _drive() async {
    final session = _session!;
    final host = session.host;
    final interpreter = session.interpreter;
    for (final step in parseEventScript(script)) {
      await _settle();
      if (session.result != null) break;
      final began = _now;
      switch (step) {
        case EventStep(:final control, :final event):
          interpreter.raiseEvent(control, event);
        case TypeStep(:final control, :final value):
          host.model.control(control)!.set('Text', value);
          interpreter.raiseEvent(control, 'Changed');
        case SelectStep(:final control, :final index):
          host.model.control(control)!.set('ListIndex', index);
          interpreter.raiseEvent(control, 'Changed');
        case OkStep():
          host.dialogs.answerTop('');
        case AnswerStep(:final value):
          host.dialogs.answerTop(value);
        case ChooseStep(:final item):
          host.dialogs.answerTop(item);
        case CloseStep():
          interpreter.closeForm();
        case KeyStep(:final event, :final key):
          interpreter.raiseKey(event, GbKeyEvent(keyCodes[key]!));
        case MouseStep(:final control, :final event, :final button):
          interpreter.raiseMouse(
            control,
            event,
            GbMouseEvent(mouseButtons[button]!, step.x, step.y),
          );
        case ResizeStep():
          break;
      }
      await _settle();
      await SchedulerBinding.instance.endOfFrame;
      _steps.add(_now - began);
    }
    // A program timed between bench:start and bench:end runs on in
    // DoEvents after its step has let the script go on.
    while (_startAt != null && _endAt == null && session.result == null) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    // Frame timings come in batches, about once a second.
    await Future<void>.delayed(const Duration(milliseconds: 1500));
    _report();
  }

  void _report() {
    double ms(num us) => (us / 1000 * 100).round() / 100;
    double mean(List<int> xs) =>
        xs.isEmpty ? 0 : xs.reduce((a, b) => a + b) / xs.length;
    final out = <String, Object?>{
      'name': name,
      'where': where,
      'platform': kIsWeb ? 'web' : defaultTargetPlatform.name,
      'stepsMs': [for (final s in _steps) ms(s)],
    };
    final start = _startAt;
    final end = _endAt;
    if (start != null && end != null) {
      out['runMs'] = ms(end - start);
      // The rounds between bench:start and bench:end, each ended by a
      // DoEvents: the interpreter's part runs from the last resume (or the
      // start) to the next DoEvents; the rest is the wait in it.
      final calls = [
        for (final c in _yieldCalls)
          if (c > start && c < end) c,
      ];
      final resumes = [
        for (final r in _yieldResumes)
          if (r > start && r <= end) r,
      ];
      if (calls.isNotEmpty) {
        final interpreter = <int>[];
        final waiting = <int>[];
        var last = start;
        for (var i = 0; i < calls.length; i++) {
          interpreter.add(calls[i] - last);
          if (i < resumes.length) {
            waiting.add(resumes[i] - calls[i]);
            last = resumes[i];
          }
        }
        final seconds = (end - start) / 1e6;
        out['rounds'] = calls.length;
        out['roundsPerSecond'] = (calls.length / seconds * 10).round() / 10;
        out['roundMs'] = ms((end - start) / calls.length);
        out['interpreterMs'] = ms(mean(interpreter));
        out['waitInDoEventsMs'] = ms(mean(waiting));
        final frames = [
          for (final f in _frameAt)
            if (f >= start && f <= end) f,
        ];
        out['frames'] = frames.length;
        out['framesPerSecond'] = (frames.length / seconds * 10).round() / 10;
        final timings = [
          for (final t in _timings)
            if (t.$1 >= start && t.$1 <= end + 1500000) t,
        ];
        out['buildMs'] = ms(mean([for (final t in timings) t.$2]));
        out['rasterMs'] = ms(mean([for (final t in timings) t.$3]));
      }
    }
    // ignore: avoid_print
    print('GUBASIC_BENCH ${jsonEncode(out)}');
  }
}
