import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'web_export.dart';

/// Takes the web player's template from beside the web IDE (D84).
/// Throws [TemplateUnavailable].
Future<Uint8List> fetchWebTemplate() async {
  try {
    final response = await web.window.fetch(webTemplatePath.toJS).toDart;
    if (!response.ok) throw const TemplateUnavailable();
    return (await response.arrayBuffer().toDart).toDart.asUint8List();
  } on TemplateUnavailable {
    rethrow;
  } catch (_) {
    throw const TemplateUnavailable();
  }
}
