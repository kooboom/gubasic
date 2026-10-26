import 'dart:io';
import 'dart:typed_data';

import 'package:gubasic_player/gubasic_player.dart';

/// The exported app's project bundle (D83), or null when there is none: in
/// a macOS app's `Contents/Resources`, next to the program elsewhere.
Future<Uint8List?> readBundleBytes() async {
  final program = File(Platform.resolvedExecutable);
  final file = Platform.isMacOS
      ? File('${program.parent.parent.path}/Resources/$bundleFileName')
      : File('${program.parent.path}/$bundleFileName');
  return file.existsSync() ? file.readAsBytes() : null;
}
