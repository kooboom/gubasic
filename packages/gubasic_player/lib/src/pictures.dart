import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// [pictures] for the runtime to draw, found by name in any case, as names
/// in code are (`pictureKey`).
GbPictureSource pictureSource(Map<String, Uint8List> pictures) {
  final byKey = {
    for (final MapEntry(:key, :value) in pictures.entries)
      pictureKey(key): value,
  };
  return (name) => byKey[pictureKey(name)];
}
