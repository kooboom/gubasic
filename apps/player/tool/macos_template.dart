import 'dart:convert';
import 'dart:io';

// Only the bundle's constants: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// The app in the release build, which the macOS IDE renames to the
/// project's name (D87).
const app = 'GuBASIC Player.app';

/// What the app needs inside: its program, its Info.plist, the engine,
/// the app's code and assets, its icon and the player's font. Missing any
/// of them, no template is made.
const required = [
  'Contents/Info.plist',
  'Contents/MacOS/GuBASIC Player',
  'Contents/Frameworks/FlutterMacOS.framework/FlutterMacOS',
  'Contents/Frameworks/App.framework/App',
  'Contents/Frameworks/App.framework/Resources/flutter_assets/AssetManifest.bin',
  'Contents/Frameworks/App.framework/Resources/flutter_assets/fonts/pretendard/Pretendard-Regular.otf',
  'Contents/Resources/AppIcon.icns',
];

/// Makes the macOS player's template, `build/macos-template.zip`, from the
/// release build in `build/macos/Build/Products/Release` (`flutter build
/// macos --release`): what the macOS IDE downloads, adds a project to,
/// signs again and gives as a macOS app (D87). Checks that the app has
/// the files it needs, and adds `template.json`, with the GuBASIC it is
/// for, the bundle layout it reads and the app's name. The zip is made by
/// macOS's `ditto`, which keeps the app's symbolic links and permissions;
/// so this runs on a Mac.
///
///     dart run tool/macos_template.dart
Future<void> main() async {
  final built = Directory('build/macos/Build/Products/Release/$app');
  if (!built.existsSync()) {
    stderr.writeln('${built.path} is missing: run flutter build macos first');
    exit(1);
  }
  final missing = [
    for (final f in required)
      if (FileSystemEntity.typeSync('${built.path}/$f') ==
          FileSystemEntityType.notFound)
        f,
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('The release build lacks ${missing.join(', ')}');
    exit(1);
  }
  final staging = Directory('build/macos-template');
  if (staging.existsSync()) staging.deleteSync(recursive: true);
  staging.createSync(recursive: true);
  await _run('ditto', [built.path, '${staging.path}/$app']);
  File('${staging.path}/template.json').writeAsStringSync(
    jsonEncode({
      'gubasic': gubasicVersion,
      'bundleFormat': bundleFormatVersion,
      'app': app,
    }),
  );
  final out = File('build/macos-template.zip');
  if (out.existsSync()) out.deleteSync();
  await _run('ditto', ['-c', '-k', staging.path, out.path]);
  stdout.writeln(
    'build/macos-template.zip: '
    '${(out.lengthSync() / 1e6).toStringAsFixed(1)} MB',
  );
}

Future<void> _run(String program, List<String> arguments) async {
  final result = await Process.run(program, arguments);
  if (result.exitCode != 0) {
    stderr.writeln('$program ${arguments.join(' ')}: ${result.stderr}');
    exit(1);
  }
}
