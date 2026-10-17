import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

import 'browser.dart';

/// The browser the web IDE runs in.
Browser? platformBrowser() => const _WebBrowser();

class _WebBrowser implements Browser {
  const _WebBrowser();

  @override
  BrowserStorage get storage => const _LocalStorage();

  @override
  void download(String fileName, List<int> bytes) {
    final blob = web.Blob(
      [Uint8List.fromList(bytes).toJS].toJS,
      web.BlobPropertyBag(type: 'application/zip'),
    );
    final url = web.URL.createObjectURL(blob);
    final link = web.HTMLAnchorElement()
      ..href = url
      ..download = fileName;
    web.document.body!.append(link);
    link.click();
    link.remove();
    web.URL.revokeObjectURL(url);
  }

  @override
  void guardUnload(bool Function() unsaved) {
    web.window.addEventListener(
      'beforeunload',
      (web.Event event) {
        if (unsaved()) event.preventDefault();
      }.toJS,
    );
  }

  @override
  void open(String url) => web.window.location.href = url;

  @override
  void onHidden(void Function() action) {
    web.document.addEventListener(
      'visibilitychange',
      (web.Event _) {
        if (web.document.visibilityState == 'hidden') action();
      }.toJS,
    );
  }
}

/// `localStorage`. Any failure to use it (full, or turned off by the
/// browser's settings) is [StorageFailed].
class _LocalStorage implements BrowserStorage {
  const _LocalStorage();

  web.Storage? get _storage {
    try {
      return web.window.localStorage;
    } catch (_) {
      return null;
    }
  }

  @override
  Iterable<String> get keys {
    final s = _storage;
    if (s == null) return const [];
    return [for (var i = 0; i < s.length; i++) ?s.key(i)];
  }

  @override
  String? read(String key) {
    try {
      return _storage?.getItem(key);
    } catch (_) {
      return null;
    }
  }

  @override
  void write(String key, String value) {
    final s = _storage;
    if (s == null) throw const StorageFailed();
    try {
      s.setItem(key, value);
    } catch (_) {
      throw const StorageFailed();
    }
  }

  @override
  void remove(String key) {
    try {
      _storage?.removeItem(key);
    } catch (_) {
      // Already unusable: nothing to remove.
    }
  }
}
