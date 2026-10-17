import 'dart:io';

import 'support/caption_ime_replay.dart';

/// The recordings of packages/gubasic_runtime/test/ime_logs, replayed into
/// the Properties window's Caption field (D35).
void main() {
  final files =
      Directory('../../packages/gubasic_runtime/test/ime_logs')
          .listSync()
          .whereType<File>()
          .toList()
        ..sort((File a, File b) => a.path.compareTo(b.path));
  defineCaptionImeTests({
    for (final f in files) f.uri.pathSegments.last: f.readAsStringSync(),
  });
}
