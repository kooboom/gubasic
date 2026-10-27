import 'dart:io';
import 'dart:typed_data';

import 'package:gubasic_player/gubasic_player.dart' show gubasicVersion;

import 'app_export.dart';

/// The player's [template] for this GuBASIC (D84, D86): the one kept from
/// the first export, or else downloaded from the GuBASIC site and kept.
/// Throws [TemplateUnavailable], or [TemplateNotUsable] for a download
/// that is not a template for this GuBASIC.
Future<Uint8List> fetchAppTemplate(AppTemplate template) async {
  final kept = _keptTemplate(template);
  if (kept != null) {
    try {
      final bytes = await kept.readAsBytes();
      readTemplate(bytes);
      return bytes;
    } on Object {
      // Not kept yet, or damaged: downloaded again.
    }
  }
  final bytes = await _download(template.url);
  readTemplate(bytes);
  if (kept != null) {
    try {
      await kept.parent.create(recursive: true);
      final part = File('${kept.path}.part');
      await part.writeAsBytes(bytes, flush: true);
      await part.rename(kept.path);
    } on IOException {
      // Not kept: the next export downloads it again.
    }
  }
  return bytes;
}

/// Where the template is kept: the user's cache folder, one file for each
/// GuBASIC version, since each reads its own bundle layout; a development
/// build keeps main's apart from its release's (D93).
File? _keptTemplate(AppTemplate template) {
  final env = Platform.environment;
  final folder = switch (Platform.operatingSystem) {
    'macos' when env['HOME'] != null =>
      '${env['HOME']}/Library/Caches/io.github.kooboom.gubasic.ide',
    'windows' when env['LOCALAPPDATA'] != null =>
      '${env['LOCALAPPDATA']}\\GuBASIC IDE',
    _ => null,
  };
  if (folder == null) return null;
  return File(
    '$folder${Platform.pathSeparator}'
    '${template.name}-template-$gubasicVersion'
    '${gubasicRelease.isEmpty ? '-main' : ''}.zip',
  );
}

Future<Uint8List> _download(String url) async {
  final client = HttpClient()..connectionTimeout = const Duration(seconds: 20);
  try {
    final request = await client.getUrl(Uri.parse(url));
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw const TemplateUnavailable();
    }
    final bytes = BytesBuilder(copy: false);
    await response.forEach(bytes.add);
    return bytes.takeBytes();
  } on IOException {
    throw const TemplateUnavailable();
  } finally {
    client.close();
  }
}
