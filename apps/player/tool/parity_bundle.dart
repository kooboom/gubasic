import 'dart:convert';
import 'dart:io';

// Only the bundle: the package's library needs Flutter.
import 'package:gubasic_player/src/bundle.dart';

/// Makes a project bundle (`.gbz`, D83) of each parity program that uses
/// Database (`test/parity/NAME.database`, D126), as the IDE's export
/// would, into `build/parity/NAME.gbz`, so that the web player runs it
/// in a real browser for tool/web_check (Playwright) and its console is
/// compared with `NAME.out`:
///
///     dart run tool/parity_bundle.dart
void main() {
  final dir = Directory('../../test/parity');
  final out = Directory('build/parity')..createSync(recursive: true);
  var count = 0;
  for (final marker in dir.listSync().whereType<File>().where(
    (f) => f.path.endsWith('.database'),
  )) {
    final base = marker.path.substring(
      0,
      marker.path.length - '.database'.length,
    );
    final name = base.split(RegExp(r'[\\/]')).last;
    final files = <String, String>{};
    final forms = <String>[];
    final modules = <String>[];
    for (final f in dir.listSync().whereType<File>()) {
      final path = f.path;
      if (!path.startsWith('$base.')) continue;
      final rest = path.substring(base.length + 1);
      if (rest == 'gbas') {
        files['Form1.gbas'] = f.readAsStringSync();
      } else if (rest == 'form.yaml') {
        files['Form1.form.yaml'] = f.readAsStringSync();
        forms.add('Form1');
      } else if (rest.endsWith('.form.yaml')) {
        final form = rest.substring(0, rest.length - '.form.yaml'.length);
        files['$form.form.yaml'] = f.readAsStringSync();
        files['$form.gbas'] = File('$base.$form.gbas').readAsStringSync();
        forms.add(form);
      } else if (rest.endsWith('.gbas') &&
          !File('$base.${rest.substring(0, rest.length - 5)}.form.yaml')
              .existsSync()) {
        final module = rest.substring(0, rest.length - '.gbas'.length);
        files['$module.gbas'] = f.readAsStringSync();
        modules.add(module);
      }
    }
    forms.sort();
    modules.sort();
    final startup = File('$base.startup');
    final startsWithMain =
        startup.existsSync() && startup.readAsStringSync().trim() == 'Sub Main';
    files['$name.gbproj'] =
        'formatVersion: 1\n'
        'name: ${jsonEncode(name)}\n'
        'startup: ${startsWithMain ? 'Sub Main' : 'Form1'}\n'
        'forms:\n${forms.map((f) => '  - $f\n').join()}'
        '${modules.isEmpty ? '' : 'modules:\n${modules.map((m) => '  - $m\n').join()}'}';
    // An app ID of its own, so that its files stay apart from other apps'.
    final id =
        'parity${name.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '')}'
            .padRight(8, '0');
    final bundle = ProjectBundle(
      id: id.substring(0, id.length.clamp(8, 32)),
      name: name,
      files: files,
    );
    File('${out.path}/$name.gbz').writeAsBytesSync(bundle.encode());
    count++;
    stdout.writeln('${out.path}/$name.gbz: ${files.keys.join(', ')}');
  }
  if (count == 0) {
    stderr.writeln('no parity program has a .database file');
    exit(1);
  }
}
