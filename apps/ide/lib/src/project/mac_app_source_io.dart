import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:gubasic_player/gubasic_player.dart';

import 'app_export.dart';

/// What makes macOS apps here: [macosAppZip] on a Mac, nothing elsewhere,
/// since only a Mac can sign the app again (D87).
final Future<Uint8List> Function(
  List<int> template,
  ProjectBundle bundle,
  String guide,
)?
macAppMaker = Platform.isMacOS ? macosAppZip : null;

/// The macOS app of [bundle], made from the macOS player's [template]
/// (D87): a `.zip` with the folder `NAME-macos/`, which holds `NAME.app`
/// and [guide] as `README.txt`. In the app, the Info.plist gives NAME as
/// the app's name and [macBundleId] of the app ID as its bundle ID, and
/// the bundle is in `Contents/Resources` as `project.gbz`; the program
/// keeps its name, since `codesign` cannot check a program whose name is
/// not ASCII (`a sealed resource is missing or invalid`), and the name
/// macOS shows (Dock, menus, Force Quit) is the app's name anyway; then the app is signed again, ad-hoc, keeping the
/// template's entitlements, and the signature checked. NAME is the
/// project's name as a file name ([appFileName]).
///
/// Uses macOS's `ditto`, which keeps the app's symbolic links and
/// permissions, `plutil` and `codesign`. Throws [TemplateNotUsable], or
/// [MacAppNotMade] when one of them fails.
Future<Uint8List> macosAppZip(
  List<int> template,
  ProjectBundle bundle,
  String guide,
) async {
  final work = await Directory.systemTemp.createTemp('gubasic-macos-');
  try {
    final zip = File('${work.path}/template.zip');
    await zip.writeAsBytes(template);
    final unzipped = '${work.path}/template';
    if ((await Process.run('ditto', [
          '-x',
          '-k',
          zip.path,
          unzipped,
        ])).exitCode !=
        0) {
      throw const TemplateNotUsable();
    }
    final Map<Object?, Object?> about;
    try {
      about = jsonDecode(
        await File('$unzipped/template.json').readAsString(),
      ) as Map<Object?, Object?>;
    } catch (_) {
      throw const TemplateNotUsable();
    }
    final format = about['bundleFormat'];
    if (format != bundleFormatVersion) {
      throw TemplateNotUsable(format is int ? format : null);
    }
    final app = about['app'];
    if (app is! String || !Directory('$unzipped/$app').existsSync()) {
      throw const TemplateNotUsable();
    }

    final name = appFileName(bundle.name);
    final folder = await Directory('${work.path}/out/$name-macos')
        .create(recursive: true);
    final made = '${folder.path}/$name.app';
    await Directory('$unzipped/$app').rename(made);
    final plist = '$made/Contents/Info.plist';
    for (final (key, value) in [
      ('CFBundleName', name),
      ('CFBundleDisplayName', name),
      ('CFBundleIdentifier', macBundleId(bundle.id)),
    ]) {
      await _must('plutil', ['-replace', key, '-string', value, plist]);
    }
    await File('$made/Contents/Resources/$bundleFileName')
        .writeAsBytes(bundle.encode());
    // Only the app's own files changed; its frameworks keep their
    // signatures.
    await _must('codesign', [
      '--force',
      '--sign',
      '-',
      '--preserve-metadata=entitlements',
      made,
    ]);
    await _must('codesign', ['--verify', '--deep', '--strict', made]);

    await File('${folder.path}/README.txt').writeAsString(guide);
    final out = '${work.path}/$name-macos.zip';
    await _must('ditto', ['-c', '-k', '--keepParent', folder.path, out]);
    return await File(out).readAsBytes();
  } finally {
    await work.delete(recursive: true);
  }
}

/// Runs [program] and gives what it printed; throws [MacAppNotMade] when
/// it fails.
Future<String> _must(String program, List<String> arguments) async {
  final result = await Process.run(program, arguments);
  if (result.exitCode != 0) {
    throw MacAppNotMade('$program: ${'${result.stderr}'.trim()}');
  }
  return '${result.stdout}';
}
