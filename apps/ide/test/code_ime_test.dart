import 'dart:io';

import 'support/code_ime_replay.dart';

/// The recordings of packages/gubasic_runtime/test/ime_logs, replayed into
/// the code editor (D36).
void main() {
  final files =
      Directory('../../packages/gubasic_runtime/test/ime_logs')
          .listSync()
          .whereType<File>()
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  defineCodeImeTests({
    for (final f in files) f.uri.pathSegments.last: f.readAsStringSync(),
  });
}
