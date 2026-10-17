import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Where the recording was made: the browser and its system.
Map<String, Object?> recordedOn() => {
  'userAgent': web.window.navigator.userAgent,
  'platform': web.window.navigator.platform,
};

/// Downloads [json] as `ime-log-<system>-chrome.json`; gives its name.
Future<String> saveLog(String json) async {
  final blob = web.Blob(
    [json.toJS].toJS,
    web.BlobPropertyBag(type: 'application/json'),
  );
  final url = web.URL.createObjectURL(blob);
  final os = web.window.navigator.platform.toLowerCase().startsWith('mac')
      ? 'macos'
      : 'windows';
  final name = 'ime-log-$os-chrome.json';
  web.HTMLAnchorElement()
    ..href = url
    ..download = name
    ..click();
  web.URL.revokeObjectURL(url);
  return name;
}
