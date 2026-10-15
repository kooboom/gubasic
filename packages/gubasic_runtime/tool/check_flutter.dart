import 'dart:convert';
import 'dart:io';

/// Checks that the Flutter on this machine is the one this repository is
/// pinned to (D29): `environment: flutter:` in this package's pubspec.yaml.
/// pub only checks that version as a lower bound, so this compares it
/// exactly. CI installs the same version from the same line.
///
///     dart tool/check_flutter.dart
void main() {
  final pubspec = File.fromUri(Platform.script.resolve('../pubspec.yaml'));
  final pinned = RegExp(
    r'^\s+flutter:\s*([0-9]+\.[0-9]+\.[0-9]+)\s*$',
    multiLine: true,
  ).firstMatch(pubspec.readAsStringSync())?.group(1);
  if (pinned == null) {
    stderr.writeln('${pubspec.path}: no exact "flutter: x.y.z" line.');
    exit(2);
  }
  final r = Process.runSync('flutter', [
    '--version',
    '--machine',
  ], runInShell: true);
  if (r.exitCode != 0) {
    stderr.writeln('Could not run flutter: ${r.stderr}');
    exit(2);
  }
  final out = r.stdout as String;
  final info = jsonDecode(out.substring(out.indexOf('{'))) as Map;
  final installed = info['frameworkVersion'];
  if (installed != pinned) {
    stderr.writeln(
      'This repository uses Flutter $pinned, but this machine '
      'has $installed.\n'
      'In the Flutter SDK folder (${info['flutterRoot']}), run:\n'
      '  git fetch --tags && git checkout $pinned && flutter --version',
    );
    exit(1);
  }
  stdout.writeln('Flutter $installed, as pinned.');
}
