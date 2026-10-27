import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'app_export.dart';

/// Takes the player's [template] from beside the web IDE (D84, D86).
/// Throws [TemplateUnavailable].
Future<Uint8List> fetchAppTemplate(AppTemplate template) async {
  try {
    final response = await web.window.fetch(template.path.toJS).toDart;
    if (!response.ok) throw const TemplateUnavailable();
    return (await response.arrayBuffer().toDart).toDart.asUint8List();
  } on TemplateUnavailable {
    rethrow;
  } catch (_) {
    throw const TemplateUnavailable();
  }
}
