import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:gubasic_player/gubasic_player.dart';

import 'src/bundle_source.dart';
import 'src/player_app.dart';

/// The player (D79): runs the project bundle the export put next to it
/// (D83), or, while developing, the project under `project/` in its
/// assets.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final strings = playerStringsFor(
    PlatformDispatcher.instance.locale.languageCode,
  );
  final bytes = await readBundleBytes();
  if (bytes != null) {
    try {
      final bundle = ProjectBundle.decode(bytes);
      runApp(
        PlayerApp(
          files: bundle.files,
          pictures: bundle.pictures,
          settingsKey: bundle.id,
          strings: strings,
        ),
      );
    } on BundleProblem catch (problem) {
      runApp(BundleProblemApp(problem: problem, strings: strings));
    }
    return;
  }
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
  runApp(PlayerApp(files: files, pictures: pictures, strings: strings));
}
