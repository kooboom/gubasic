import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
// Only the bundle's constants: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// The program in the release build, which the IDE renames to the
/// project's name (D86).
const program = 'gubasic_player_app.exe';

/// What a Windows PC without Flutter or Visual Studio needs to run the
/// player: the program, the engine and its data, the app's code and
/// assets, the Visual C++ runtime next to the program (D47) and the
/// player's font. Missing any of them, no template is made.
const required = [
  program,
  'flutter_windows.dll',
  'msvcp140.dll',
  'vcruntime140.dll',
  'vcruntime140_1.dll',
  'data/icudtl.dat',
  'data/app.so',
  'data/flutter_assets/AssetManifest.bin',
  'data/flutter_assets/fonts/pretendard/Pretendard-Regular.otf',
];

/// Makes the Windows player's template, `build/windows-template.zip`, from
/// the release build in `build/windows/x64/runner/Release` (`flutter build
/// windows --release`, with the Visual C++ runtime copied next to the
/// program): what the IDE downloads, adds a project to and gives as a
/// Windows app (D86). Checks that the files a PC needs are all there, and
/// adds `template.json`, with the GuBASIC it is for, the bundle layout it
/// reads and the program's name.
///
///     dart run tool/windows_template.dart
void main() {
  final release = Directory('build/windows/x64/runner/Release');
  if (!release.existsSync()) {
    stderr.writeln('$release is missing: run flutter build windows first');
    exit(1);
  }
  final archive = Archive();
  final names = <String>{};
  for (final entity in release.listSync(recursive: true)) {
    if (entity is! File) continue;
    final path = entity.path
        .substring(release.path.length + 1)
        .replaceAll(r'\', '/');
    archive.add(ArchiveFile.bytes(path, entity.readAsBytesSync()));
    names.add(path);
  }
  final missing = [
    for (final f in required)
      if (!names.contains(f)) f,
  ];
  if (missing.isNotEmpty) {
    stderr.writeln('The release build lacks ${missing.join(', ')}');
    exit(1);
  }
  archive.add(
    ArchiveFile.bytes(
      'template.json',
      utf8.encode(
        jsonEncode({
          'gubasic': gubasicVersion,
          'bundleFormat': bundleFormatVersion,
          'program': program,
        }),
      ),
    ),
  );
  final out = File('build/windows-template.zip')
    ..writeAsBytesSync(ZipEncoder().encodeBytes(archive));
  stdout.writeln(
    'build/windows-template.zip: ${names.length} files, '
    '${(out.lengthSync() / 1e6).toStringAsFixed(1)} MB',
  );
}
