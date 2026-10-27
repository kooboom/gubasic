import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// Where the desktop IDE downloads the players' templates (D84, D86); the
/// web IDE takes them from beside itself, `../player/`. A test build can
/// name another place: `--dart-define GUBASIC_TEMPLATE_SITE=…`.
const templateSite = String.fromEnvironment(
  'GUBASIC_TEMPLATE_SITE',
  defaultValue: 'https://kooboom.github.io/gubasic/player',
);

/// A player's template, which an app is made from by adding the project.
enum AppTemplate {
  /// The web player (D84).
  web('template.zip'),

  /// The Windows player (D86).
  windows('windows-template.zip');

  const AppTemplate(this.fileName);

  final String fileName;

  /// Where the desktop IDE downloads it.
  String get url => '$templateSite/$fileName';

  /// Where the web IDE takes it from, relative to its page.
  String get path => '../player/$fileName';
}

/// Why an app could not be made from a template.
sealed class WebTemplateProblem implements Exception {
  const WebTemplateProblem();
}

/// The template could not be downloaded.
class TemplateUnavailable extends WebTemplateProblem {
  const TemplateUnavailable();
}

/// The template is not one this IDE can use: not a template, or for
/// another bundle layout ([bundleFormat], null when it does not say).
class TemplateNotUsable extends WebTemplateProblem {
  const TemplateNotUsable([this.bundleFormat]);

  final int? bundleFormat;
}

/// [name] as the name of a file or folder on any system (D86): the
/// characters Windows does not allow in one, and control characters,
/// become `_`; spaces and dots at the ends, which Windows drops, are
/// dropped; a name Windows keeps for a device (`CON`, `COM1`) or nothing
/// left becomes `App`.
String appFileName(String name) {
  var safe = name
      .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
      .replaceAll(RegExp(r'^[ .]+|[ .]+$'), '');
  final device = RegExp(r'^(con|prn|aux|nul|com[0-9]|lpt[0-9])$');
  if (safe.isEmpty || device.hasMatch(safe.toLowerCase())) safe = 'App';
  return safe;
}

/// The app ID of an example (D84): examples are not saved, so each export
/// of one gets the same ID from its name, and keeps its settings.
String exampleAppId(String name) {
  final id = 'example${name.toLowerCase().replaceAll(RegExp('[^a-z0-9]'), '')}';
  return (id.length > 32 ? id.substring(0, 32) : id).padRight(8, '0');
}

/// The app ID of the project of [files], or null when its `.gbproj` file
/// has none or a malformed one (F018).
String? projectIdOf(Map<String, String> files) {
  final id = _projectFile(files)?.$2.project.id;
  return id != null && isProjectId(id) ? id : null;
}

/// [files] with the `.gbproj` file giving the app ID [id]; null when it
/// has errors, so that it cannot be written again.
Map<String, String>? withProjectId(Map<String, String> files, String id) {
  final project = _projectFile(files);
  if (project == null || project.$2.hasErrors) return null;
  final (file, read) = project;
  final p = read.project;
  return {
    ...files,
    file: writeProjectFile(
      ProjectFile(
        name: p.name,
        forms: p.forms,
        startup: p.startup,
        pictures: p.pictures,
        id: id,
      ),
    ),
  };
}

/// The name of the `.gbproj` file of [files], or null.
String? projectFileName(Map<String, String> files) => _projectFile(files)?.$1;

(String, ProjectFileResult)? _projectFile(Map<String, String> files) {
  final names = [
    for (final f in files.keys)
      if (f.toLowerCase().endsWith('.gbproj')) f,
  ];
  if (names.length != 1) return null;
  return (names.single, readProjectFile(files[names.single]!));
}

/// The files of a player's [template]. Throws [TemplateNotUsable]
/// when it is not a template, or one for another bundle layout.
Archive readTemplate(List<int> template) {
  final Archive files;
  try {
    files = ZipDecoder().decodeBytes(template);
  } catch (_) {
    throw const TemplateNotUsable();
  }
  final about = files.findFile('template.json');
  if (about == null) throw const TemplateNotUsable();
  final int? format;
  try {
    format =
        (jsonDecode(utf8.decode(about.content)) as Map)['bundleFormat'] as int?;
  } catch (_) {
    throw const TemplateNotUsable();
  }
  if (format != bundleFormatVersion) throw TemplateNotUsable(format);
  return files;
}

/// The web app of [bundle], made from the web player's [template] (D84):
/// a `.zip` with the folder `NAME-web/`, which holds the template's files,
/// with the page's title and the manifest's name set to the project's
/// name, the bundle as `project.gbz`, and [guide] as `HOSTING.txt`.
/// Throws [TemplateNotUsable].
Uint8List webAppZip(List<int> template, ProjectBundle bundle, String guide) {
  final files = readTemplate(template);
  if (files.findFile('index.html') == null) throw const TemplateNotUsable();
  final folder = '${appFileName(bundle.name)}-web';
  final out = Archive();
  void add(String path, List<int> bytes) =>
      out.add(ArchiveFile.bytes('$folder/$path', bytes));
  for (final file in files.files) {
    if (!file.isFile || file.name == 'template.json') continue;
    final bytes = file.content;
    switch (file.name) {
      case 'index.html':
        add(file.name, utf8.encode(_titled(utf8.decode(bytes), bundle.name)));
      case 'manifest.json':
        final manifest = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
        manifest['name'] = bundle.name;
        manifest['short_name'] = bundle.name;
        add(
          file.name,
          utf8.encode(const JsonEncoder.withIndent('  ').convert(manifest)),
        );
      default:
        add(file.name, bytes);
    }
  }
  add(bundleFileName, bundle.encode());
  add('HOSTING.txt', utf8.encode(guide));
  return Uint8List.fromList(ZipEncoder().encodeBytes(out));
}

/// The Windows app of [bundle], made from the Windows player's [template]
/// (D86): a `.zip` with the folder `NAME-windows/`, which holds the
/// template's files, with the program renamed to `NAME.exe`, the bundle as
/// `project.gbz` next to it and [guide] as `README.txt`. NAME is the
/// project's name as a file name ([appFileName]). Throws
/// [TemplateNotUsable].
Uint8List windowsAppZip(
  List<int> template,
  ProjectBundle bundle,
  String guide,
) {
  final files = readTemplate(template);
  final Object? program;
  try {
    program = (jsonDecode(
      utf8.decode(files.findFile('template.json')!.content),
    ) as Map)['program'];
  } catch (_) {
    throw const TemplateNotUsable();
  }
  if (program is! String || files.findFile(program) == null) {
    throw const TemplateNotUsable();
  }
  final name = appFileName(bundle.name);
  final folder = '$name-windows';
  final out = Archive();
  void add(String path, List<int> bytes) =>
      out.add(ArchiveFile.bytes('$folder/$path', bytes));
  for (final file in files.files) {
    if (!file.isFile || file.name == 'template.json') continue;
    add(file.name == program ? '$name.exe' : file.name, file.content);
  }
  add(bundleFileName, bundle.encode());
  add('README.txt', utf8.encode(guide));
  return Uint8List.fromList(ZipEncoder().encodeBytes(out));
}

/// [html] with [name] as the page's title and the title a phone gives it
/// on the home screen.
String _titled(String html, String name) {
  final escaped = const HtmlEscape().convert(name);
  return html
      .replaceFirst(RegExp('<title>[^<]*</title>'), '<title>$escaped</title>')
      .replaceFirst(
        RegExp('<meta name="apple-mobile-web-app-title" content="[^"]*">'),
        '<meta name="apple-mobile-web-app-title" content="$escaped">',
      );
}
