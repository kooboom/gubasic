import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/mac_app_source_io.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// Exports two macOS apps from the real macOS template with the IDE's own
/// code (D87), for a Mac to open: 안녕, the hello example counting its runs
/// with SaveSetting, and Ending, whose program saves a setting and ends.
/// Runs only on a Mac, when GUBASIC_MACOS_TEMPLATE names the template and
/// GUBASIC_MACOS_APPS the folder to write `안녕-macos.zip` and
/// `Ending-macos.zip` into.
void main() {
  final template = Platform.environment['GUBASIC_MACOS_TEMPLATE'];
  final out = Platform.environment['GUBASIC_MACOS_APPS'];
  test(
    'hello and Ending exported as macOS apps',
    () async {
      final hello = {
        for (final f in Directory(
          '../../examples/hello',
        ).listSync().whereType<File>())
          f.uri.pathSegments.last: f.readAsStringSync(),
      };
      Map<String, String> named(String name, String code) => {
        ...hello,
        'Hello.gbproj': hello['Hello.gbproj']!.replaceFirst(
          'name: Hello',
          'name: $name',
        ),
        'Form1.gbas': code,
      };
      final bytes = File(template!).readAsBytesSync();
      for (final bundle in [
        ProjectBundle(
          id: 'cimacosexport001',
          name: '안녕',
          files: named(
            '안녕',
            hello['Form1.gbas']!.replaceFirst(
              '    lblMessage.Caption = "Press the button"\n',
              '    Dim runs = CInt(GetSetting("runs", "0")) + 1\n'
                  '    SaveSetting("runs", runs)\n'
                  '    lblMessage.Caption = "Runs: " & runs\n',
            ),
          ),
        ),
        ProjectBundle(
          id: 'cimacosending001',
          name: 'Ending',
          files: named(
            'Ending',
            'Sub Form_Load()\n'
                '    SaveSetting("ran", "yes")\n'
                '    End\n'
                'End Sub\n',
          ),
        ),
      ]) {
        File('$out/${bundle.name}-macos.zip')
            .writeAsBytesSync(await macosAppZip(bytes, bundle, 'README'));
      }
    },
    skip: !Platform.isMacOS || template == null || out == null
        ? 'only on a Mac, with GUBASIC_MACOS_TEMPLATE and GUBASIC_MACOS_APPS'
        : false,
  );
}
