import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/app_export.dart';
import 'package:gubasic_ide/src/project/template_source_io.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// A release's IDE downloads the templates of its own release (D93), with
/// the IDE's own code, from GitHub, and they are for this GuBASIC. Runs
/// only for a release build of the test:
///
///     flutter test --dart-define=GUBASIC_RELEASE=v0.2.0 test/release
///
/// The templates it keeps in the user's cache folder are deleted again.
void main() {
  test(
    'the templates of release $gubasicRelease',
    () async {
      expect(
        templateSite,
        'https://github.com/kooboom/gubasic/releases/download/$gubasicRelease',
      );
      for (final template in AppTemplate.values) {
        final bytes = await fetchAppTemplate(template);
        final about = readTemplate(bytes).findFile('template.json')!;
        final json = jsonDecode(utf8.decode(about.content)) as Map;
        expect(json['gubasic'], gubasicVersion, reason: template.name);
        expect(json['bundleFormat'], bundleFormatVersion);
      }
    },
    skip: gubasicRelease.isEmpty
        ? 'only with --dart-define=GUBASIC_RELEASE=v…'
        : false,
  );

  tearDownAll(() {
    final home = Platform.environment['HOME'];
    if (gubasicRelease.isEmpty || home == null || !Platform.isMacOS) return;
    for (final template in AppTemplate.values) {
      final kept = File(
        '$home/Library/Caches/io.github.kooboom.gubasic.ide/'
        '${template.name}-template-$gubasicVersion.zip',
      );
      if (kept.existsSync()) kept.deleteSync();
    }
  });
}
