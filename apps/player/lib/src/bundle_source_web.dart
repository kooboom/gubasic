import 'dart:js_interop';
import 'dart:typed_data';

import 'package:gubasic_player/gubasic_player.dart';
import 'package:web/web.dart' as web;

/// The exported web app's project bundle (D83), next to its `index.html`,
/// or null when there is none.
Future<Uint8List?> readBundleBytes() async {
  try {
    final response = await web.window.fetch(bundleFileName.toJS).toDart;
    if (!response.ok) return null;
    final buffer = await response.arrayBuffer().toDart;
    return buffer.toDart.asUint8List();
  } catch (_) {
    return null;
  }
}
