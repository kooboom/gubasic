import 'dart:async';
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
  Future<ProjectStore?> openProjects() => _IndexedDbStore.open();

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

/// IndexedDB (D53): the database `gubasic.ide`, with a store of project
/// records (JSON text by the lower case of the name) and a store of
/// pictures (bytes by `KEY/NAME`; neither has a `/`). A failure of any
/// kind, a full disk included, is [StorageFailed].
class _IndexedDbStore implements ProjectStore {
  _IndexedDbStore(this._db);

  static const _projects = 'projects';
  static const _pictures = 'pictures';

  final web.IDBDatabase _db;

  /// The store, or null when the browser does not open it (some private
  /// windows).
  static Future<ProjectStore?> open() async {
    try {
      final request = web.window.indexedDB.open('${browserKeyPrefix}db', 1);
      request.onupgradeneeded = (web.Event _) {
        final db = request.result! as web.IDBDatabase;
        db.createObjectStore(_projects);
        db.createObjectStore(_pictures);
      }.toJS;
      final db = await _done(request) as web.IDBDatabase;
      // A newer IDE in another tab may need the database changed: this
      // connection gives way, and its writes fail as StorageFailed.
      db.onversionchange = (web.Event _) {
        db.close();
      }.toJS;
      return _IndexedDbStore(db);
    } catch (_) {
      return null;
    }
  }

  /// The result of [request], or [StorageFailed].
  static Future<JSAny?> _done(web.IDBRequest request) {
    final done = Completer<JSAny?>();
    request
      ..onsuccess = (web.Event _) {
        done.complete(request.result);
      }.toJS
      ..onerror = (web.Event e) {
        e.preventDefault();
        if (!done.isCompleted) done.completeError(const StorageFailed());
      }.toJS;
    return done.future;
  }

  /// Runs [work] in one transaction over both stores; completes when the
  /// transaction has, or fails with [StorageFailed] when it is aborted
  /// (the disk is full, for one).
  Future<T> _run<T>(
    web.IDBTransactionMode mode,
    T Function(web.IDBObjectStore projects, web.IDBObjectStore pictures) work,
  ) async {
    final web.IDBTransaction tx;
    try {
      tx = _db.transaction([_projects.toJS, _pictures.toJS].toJS, mode);
    } catch (_) {
      throw const StorageFailed();
    }
    final done = Completer<void>();
    tx
      ..oncomplete = (web.Event _) {
        done.complete();
      }.toJS
      ..onabort = (web.Event _) {
        if (!done.isCompleted) done.completeError(const StorageFailed());
      }.toJS
      ..onerror = (web.Event _) {
        if (!done.isCompleted) done.completeError(const StorageFailed());
      }.toJS;
    final T result;
    try {
      result = work(tx.objectStore(_projects), tx.objectStore(_pictures));
    } catch (_) {
      try {
        tx.abort();
      } catch (_) {}
      throw const StorageFailed();
    }
    await done.future;
    return result;
  }

  static web.IDBKeyRange _picturesOf(String key) =>
      web.IDBKeyRange.bound('$key/'.toJS, '$key/\uffff'.toJS);

  @override
  Future<Map<String, String>> readAll() async {
    late web.IDBRequest keys, values;
    await _run('readonly', (projects, _) {
      keys = projects.getAllKeys();
      values = projects.getAll();
    });
    final k = (keys.result! as JSArray<JSString>).toDart;
    final v = (values.result! as JSArray<JSString>).toDart;
    return {for (var i = 0; i < k.length; i++) k[i].toDart: v[i].toDart};
  }

  @override
  Future<String?> read(String key) async {
    late web.IDBRequest request;
    await _run('readonly', (projects, _) => request = projects.get(key.toJS));
    return (request.result as JSString?)?.toDart;
  }

  @override
  Future<Map<String, Uint8List>> readPictures(String key) async {
    late web.IDBRequest keys, values;
    await _run('readonly', (_, pictures) {
      keys = pictures.getAllKeys(_picturesOf(key));
      values = pictures.getAll(_picturesOf(key));
    });
    final k = (keys.result! as JSArray<JSString>).toDart;
    final v = (values.result! as JSArray<JSUint8Array>).toDart;
    return {
      for (var i = 0; i < k.length; i++)
        k[i].toDart.substring(key.length + 1): v[i].toDart,
    };
  }

  @override
  Future<void> write(
    String key,
    String record,
    Map<String, Uint8List>? pictures,
  ) => _run('readwrite', (projects, store) {
    projects.put(record.toJS, key.toJS);
    if (pictures == null) return;
    store.delete(_picturesOf(key));
    for (final MapEntry(key: name, value: bytes) in pictures.entries) {
      store.put(bytes.toJS, '$key/$name'.toJS);
    }
  });

  @override
  Future<void> delete(String key) => _run('readwrite', (projects, pictures) {
    projects.delete(key.toJS);
    pictures.delete(_picturesOf(key));
  });
}
