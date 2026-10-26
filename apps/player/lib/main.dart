import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'src/player_app.dart';

/// The player (D79): runs the project built into it, from the assets under
/// `project/` (STAGE2_PLAN step 2-2; the bundle of step 2-3 takes their
/// place).
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final manifest = await AssetManifest.loadFromAssetBundle(rootBundle);
  final files = <String, String>{};
  final pictures = <String, Uint8List>{};
  for (final asset in manifest.listAssets()) {
    if (asset.startsWith('project/pictures/')) {
      final name = asset.substring('project/pictures/'.length);
      if (name.startsWith('.')) continue;
      pictures[name] = (await rootBundle.load(asset)).buffer.asUint8List();
    } else if (asset.startsWith('project/')) {
      files[asset.substring('project/'.length)] = await rootBundle.loadString(
        asset,
      );
    }
  }
  runApp(
    PlayerApp(
      files: files,
      pictures: pictures,
      strings: playerStringsFor(
        PlatformDispatcher.instance.locale.languageCode,
      ),
    ),
  );
}
