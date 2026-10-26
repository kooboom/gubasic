import 'dart:convert';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:gubasic_player/bench.dart';

import 'src/player_app.dart';

/// The player for measuring (STAGE2_PLAN §7), built with
/// `-t lib/bench_main.dart --dart-define=GUBASIC_BENCH=true`: runs one of
/// the benchmarks (the page's `?bench=NAME`, or `GUBASIC_BENCH_NAME` on
/// the desktop), drives it with its event script and prints what it
/// measured. Apps are never built from it.
void main() {
  final name = benchName() ?? 'game';
  BenchProbe.current = BenchProbe(name, benchScripts[name]!, where: 'player');
  runApp(
    PlayerApp(
      files: benchFiles[name]!,
      pictures: {
        for (final MapEntry(:key, :value) in benchPictures[name]!.entries)
          key: base64Decode(value),
      },
      strings: playerStringsFor(
        PlatformDispatcher.instance.locale.languageCode,
      ),
    ),
  );
}
