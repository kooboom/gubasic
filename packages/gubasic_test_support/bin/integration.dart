/// Runs `flutter test` with the arguments given, in the app's folder, and
/// keeps what it printed: `build/integration_logs/TEST-TIME/output.txt`,
/// and beside it the picture of the window each failing test left
/// (`testWidgetsKeepingFailures`). It says where they are, and ends as
/// `flutter test` did. CI uploads the folder when a test fails.
///
///     dart run gubasic_test_support:integration integration_test/scores_test.dart -d macos
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gubasic_test_support/shots.dart';

Future<void> main(List<String> args) async {
  final test = args
      .firstWhere((a) => a.endsWith('.dart'), orElse: () => 'tests')
      .split(RegExp(r'[/\\]'))
      .last
      .replaceAll('.dart', '');
  final now = DateTime.now();
  String two(int v) => '$v'.padLeft(2, '0');
  final time =
      '${now.year}${two(now.month)}${two(now.day)}-'
      '${two(now.hour)}${two(now.minute)}${two(now.second)}';
  final folder = Directory(
    'build${Platform.pathSeparator}integration_logs'
    '${Platform.pathSeparator}$test-$time',
  )..createSync(recursive: true);
  final log = File('${folder.path}${Platform.pathSeparator}output.txt');
  final sink = log.openWrite();
  final output = StringBuffer();

  final process = await Process.start('flutter', [
    'test',
    ...args,
  ], runInShell: Platform.isWindows);
  Future<void> copy(Stream<List<int>> from, IOSink to) =>
      from.transform(utf8.decoder).forEach((text) {
        to.write(text);
        sink.write(text);
        output.write(text);
      });
  await Future.wait([
    copy(process.stdout, stdout),
    copy(process.stderr, stderr),
  ]);
  final code = await process.exitCode;
  await sink.close();

  final shots = failureShotsIn('$output');
  for (final MapEntry(:key, :value) in shots.entries) {
    File('${folder.path}${Platform.pathSeparator}$key.png')
        .writeAsBytesSync(value);
  }
  stdout.writeln(
    code == 0
        ? 'Output kept in ${log.path}'
        : 'FAILED (exit $code). Output and ${shots.length} picture(s) of '
              'the window kept in ${folder.path}',
  );
  exit(code);
}
