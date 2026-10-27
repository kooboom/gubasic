import 'dart:typed_data';

import 'package:gubasic_player/gubasic_player.dart';

/// No macOS apps are made in the browser (D87).
const Future<Uint8List> Function(
  List<int> template,
  ProjectBundle bundle,
  String guide,
)?
macAppMaker = null;
