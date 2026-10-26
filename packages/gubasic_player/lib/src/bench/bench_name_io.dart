import 'dart:io';

/// The benchmark to run: the environment's `GUBASIC_BENCH_NAME`.
String? benchName() => Platform.environment['GUBASIC_BENCH_NAME'];
