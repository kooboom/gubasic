import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/app_export.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// Exports the hello example, named 안녕, as a Windows app from the real
/// Windows template (D86), for CI to unzip and run on Windows
/// (`apps/player/tool/check_windows_app.ps1`). Runs only when
/// GUBASIC_WINDOWS_TEMPLATE names the template and GUBASIC_WINDOWS_APP the
/// `.zip` to write.
void main() {
  final template = Platform.environment['GUBASIC_WINDOWS_TEMPLATE'];
  final out = Platform.environment['GUBASIC_WINDOWS_APP'];
  test(
    'hello exported as a Windows app',
    () {
      final files = {
        for (final f in Directory(
          '../../examples/hello',
        ).listSync().whereType<File>())
          f.uri.pathSegments.last: f.readAsStringSync(),
      };
      files['Hello.gbproj'] = files['Hello.gbproj']!.replaceFirst(
        'name: Hello',
        'name: 안녕',
      );
      final bundle = ProjectBundle(
        id: 'ciwindowsexport1',
        name: '안녕',
        files: files,
      );
      final zip = windowsAppZip(
        File(template!).readAsBytesSync(),
        bundle,
        'README',
      );
      File(out!).writeAsBytesSync(zip);
    },
    skip: template == null || out == null
        ? 'GUBASIC_WINDOWS_TEMPLATE and GUBASIC_WINDOWS_APP are not set'
        : false,
  );
}
