// Puts sqlite3.wasm, SQLite as WebAssembly from the sqlite3 package's
// release (docs/DESIGN.md D126), into each web folder given, so that a
// web build serves it next to the page and a program that uses Database
// loads it:
//
//   dart run tool/fetch_sqlite_wasm.dart ../../apps/ide/web ../../apps/player/web
//
// The release must be the one package:sqlite3 in pubspec.yaml is from, so
// that the module and the Dart code agree: the tag and the file's SHA-256
// are written here and checked. The file is not checked in (.gitignore);
// CI fetches it before every web build, and so must a PC that builds or
// runs the IDE or the player for the web. --check only says whether each
// folder has the right file.
import 'dart:io';

import 'package:crypto/crypto.dart';

/// The release tag of the sqlite3 package in pubspec.yaml.
const release = 'sqlite3-3.8.0';

/// SHA-256 of that release's sqlite3.wasm.
const sha256Hex =
    'efd308be92a34f3aa15f289a37f213b0230fd80888a1364326ee29579d892d37';

const url =
    'https://github.com/simolus3/sqlite3.dart/releases/download/$release/sqlite3.wasm';

Future<void> main(List<String> args) async {
  final check = args.contains('--check');
  final folders = args.where((a) => a != '--check').toList();
  if (folders.isEmpty) {
    stderr.writeln('usage: fetch_sqlite_wasm.dart [--check] WEB_FOLDER...');
    exit(2);
  }
  // pubspec.yaml must name the same release.
  final pubspec = File('pubspec.yaml').readAsStringSync();
  final version = release.substring('sqlite3-'.length);
  if (!pubspec.contains(RegExp('sqlite3:\\s*\\^$version\\b'))) {
    stderr.writeln(
      'pubspec.yaml does not depend on sqlite3 ^$version: update release '
      'and sha256Hex in this tool.',
    );
    exit(1);
  }
  List<int>? bytes;
  for (final folder in folders) {
    final target = File('$folder/sqlite3.wasm');
    if (target.existsSync() && _hash(target.readAsBytesSync()) == sha256Hex) {
      stdout.writeln('${target.path}: up to date');
      continue;
    }
    if (check) {
      stderr.writeln(
        '${target.path} is missing or not from $release: run '
        'dart run tool/fetch_sqlite_wasm.dart ${folders.join(' ')}',
      );
      exit(1);
    }
    bytes ??= await _download();
    target.writeAsBytesSync(bytes);
    stdout.writeln('${target.path}: ${bytes.length} bytes from $release');
  }
}

String _hash(List<int> bytes) => sha256.convert(bytes).toString();

Future<List<int>> _download() async {
  final client = HttpClient();
  try {
    var request = await client.getUrl(Uri.parse(url));
    var response = await request.close();
    // GitHub answers with a redirect to its file store.
    for (var hops = 0; response.isRedirect && hops < 5; hops++) {
      final location = response.headers.value(HttpHeaders.locationHeader)!;
      await response.drain<void>();
      request = await client.getUrl(Uri.parse(location));
      response = await request.close();
    }
    if (response.statusCode != 200) {
      stderr.writeln('$url: ${response.statusCode}');
      exit(1);
    }
    final bytes = await response.fold<List<int>>([], (a, b) => a..addAll(b));
    if (_hash(bytes) != sha256Hex) {
      stderr.writeln('$url: SHA-256 is ${_hash(bytes)}, not $sha256Hex');
      exit(1);
    }
    return bytes;
  } finally {
    client.close();
  }
}
