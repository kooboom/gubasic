import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:gubasic_player/bench.dart';

import 'main.dart';
import 'src/strings.dart';

/// The IDE for measuring (STAGE2_PLAN §7), built with
/// `-t lib/bench_main.dart --dart-define=GUBASIC_BENCH=true`: opens one of
/// the benchmarks (the page's `?bench=NAME`, or `GUBASIC_BENCH_NAME` on
/// the desktop), runs it as F5 does, drives it with its event script and
/// prints what it measured. Releases are never built from it.
void main() {
  final name = benchName() ?? 'game';
  BenchProbe.current = BenchProbe(name, benchScripts[name]!, where: 'ide');
  runApp(
    IdeApp(
      projects: {name: benchFiles[name]!},
      examplePictures: {
        name: {
          for (final MapEntry(:key, :value) in benchPictures[name]!.entries)
            key: base64Decode(value),
        },
      },
      strings: IdeStrings.en,
      open: name,
      autoRun: true,
    ),
  );
}
