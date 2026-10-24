import 'dart:convert';
import 'dart:typed_data';

/// Every key the IDE keeps in the browser starts with this, so that
/// other pages on the same site (the playground, later projects) never
/// mix with it or remove it (D33).
const browserKeyPrefix = 'gubasic.ide.';

const _projectKeyPrefix = '${browserKeyPrefix}project.';
const _noticeKey = '${browserKeyPrefix}noticeShown';

/// A project's text written to `localStorage` as the page hides, in case
/// its write to IndexedDB does not finish (D54).
const _unsavedKeyPrefix = '${browserKeyPrefix}unsaved.';

/// The layout of a project kept in the browser; a newer one is left
/// alone. Version 2 lists the project's pictures, which are kept apart
/// (D53); version 1 is what `localStorage` held (D33).
const browserProjectVersion = 2;

/// Writing to the browser's storage failed: it is full, or turned off.
class StorageFailed implements Exception {
  const StorageFailed();
}

/// The browser's key-value storage for text (`localStorage`): small
/// settings, and where projects were kept before D53.
abstract interface class BrowserStorage {
  Iterable<String> get keys;
  String? read(String key);

  /// Throws [StorageFailed].
  void write(String key, String value);
  void remove(String key);
}

/// Where the web IDE keeps projects (IndexedDB, D53): for each project,
/// by the lower case of its name, a record (JSON text) and its pictures.
abstract interface class ProjectStore {
  /// Every record: key → JSON text.
  Future<Map<String, String>> readAll();

  /// The record of [key], or null.
  Future<String?> read(String key);

  /// The pictures of [key]: name → bytes.
  Future<Map<String, Uint8List>> readPictures(String key);

  /// Writes the record of [key] and, unless [pictures] is null, replaces
  /// all its pictures with them: all of it or none. Throws
  /// [StorageFailed].
  Future<void> write(
    String key,
    String record,
    Map<String, Uint8List>? pictures,
  );

  /// Deletes the record of [key] and its pictures.
  Future<void> delete(String key);
}

/// What the web IDE needs from the browser besides storage.
abstract interface class Browser {
  BrowserStorage get storage;

  /// Where projects are kept; null when the browser will not open it.
  Future<ProjectStore?> openProjects();

  /// Gives the user [bytes] as a file named [fileName] (a download).
  void download(String fileName, List<int> bytes);

  /// Makes the browser ask before the page is left while [unsaved] says
  /// so; its words are the browser's own.
  void guardUnload(bool Function() unsaved);

  /// Runs [action] when the page is hidden (another tab) or goes away
  /// (closing, or leaving it).
  void onHidden(void Function() action);

  /// Goes to [url], relative to the page, in the same tab; the browser
  /// asks first if [guardUnload] says the work is not saved.
  void open(String url);
}

/// A project kept in the browser: its text files; its pictures are read
/// when it is opened ([BrowserProjects.pictures]).
class StoredProject {
  const StoredProject({
    required this.name,
    required this.files,
    required this.savedAt,
    this.pictures = const [],
    this.downloadedAt,
    this.changedSinceDownload = true,
  });

  final String name;
  final Map<String, String> files;

  /// The names of its pictures.
  final List<String> pictures;
  final DateTime savedAt;

  /// When it was last downloaded as a `.zip`, or null.
  final DateTime? downloadedAt;

  /// Whether it changed since it was last downloaded (or uploaded).
  final bool changedSinceDownload;
}

/// The projects kept in the browser (D33, D53). Their records are read
/// once, when the IDE starts, so that the list and the page's question
/// before leaving answer at once; writes go to the [ProjectStore] one
/// after another, and the list changes when one has succeeded.
class BrowserProjects {
  BrowserProjects._(this._store, this.storage, this._now);

  /// Opens the projects kept in [store], moving those still kept in
  /// [storage] (`localStorage`, before D53) into it first. A project is
  /// removed from [storage] only once it reads back the same from
  /// [store]; one that fails stays and is moved next time. With no
  /// [store], nothing can be kept, and saving fails.
  static Future<BrowserProjects> open(
    ProjectStore? store,
    BrowserStorage storage, {
    DateTime Function()? now,
  }) async {
    final kept = BrowserProjects._(store, storage, now ?? DateTime.now);
    if (store != null) {
      await _moveFromLocalStorage(store, storage);
      try {
        final records = await store.readAll();
        for (final MapEntry(:key, :value) in records.entries) {
          if (_decode(value) case final p?) kept._projects[key] = p;
        }
      } on StorageFailed {
        // Nothing to list; saving says what is wrong.
      }
      await kept._bringBackUnsaved();
    }
    return kept;
  }

  /// The projects whose unsaved text was brought back when they were
  /// opened (D54), by name.
  final restored = <String>[];

  /// Brings back the text written as the page hid ([writeUnsaved]) where
  /// it is newer than the project's record and differs from it, and
  /// removes it. One that cannot be written stays, for next time.
  Future<void> _bringBackUnsaved() async {
    for (final key in storage.keys.toList()) {
      if (!key.startsWith(_unsavedKeyPrefix)) continue;
      final project = _projects[key.substring(_unsavedKeyPrefix.length)];
      final unsaved = _decodeUnsaved(storage.read(key));
      // One that cannot be read, or from a newer GuBASIC, is left alone.
      if (unsaved == null) continue;
      if (project != null &&
          !unsaved.writtenAt.isBefore(project.savedAt) &&
          !_sameFiles(project.files, unsaved.files)) {
        try {
          await _queue(
            () => _write(
              StoredProject(
                name: project.name,
                files: unsaved.files,
                pictures: project.pictures,
                savedAt: _now(),
                downloadedAt: project.downloadedAt,
                changedSinceDownload: true,
              ),
              null,
            ),
          );
          restored.add(project.name);
        } on StorageFailed {
          continue;
        }
      }
      storage.remove(key);
    }
  }

  /// Writes [files] of project [name] to `localStorage` at once, as the
  /// page hides: a write to IndexedDB may not finish before it closes,
  /// and the next start brings them back (D54). Gives whether it could.
  bool writeUnsaved(String name, Map<String, String> files) {
    try {
      storage.write(
        '$_unsavedKeyPrefix${_key(name)}',
        jsonEncode({
          'formatVersion': 1,
          'files': files,
          'writtenAt': _now().toUtc().toIso8601String(),
        }),
      );
      return true;
    } on StorageFailed {
      return false;
    }
  }

  /// Forgets what [writeUnsaved] wrote for [name]: it is kept now.
  void clearUnsaved(String name) =>
      storage.remove('$_unsavedKeyPrefix${_key(name)}');

  static ({Map<String, String> files, DateTime writtenAt})? _decodeUnsaved(
    String? text,
  ) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      if (json['formatVersion'] != 1) return null;
      return (
        files: (json['files']! as Map<String, Object?>).map(
          (k, v) => MapEntry(k, v! as String),
        ),
        writtenAt: DateTime.parse(json['writtenAt']! as String).toLocal(),
      );
    } catch (_) {
      return null;
    }
  }

  static Future<void> _moveFromLocalStorage(
    ProjectStore store,
    BrowserStorage storage,
  ) async {
    for (final key in storage.keys.toList()) {
      if (!key.startsWith(_projectKeyPrefix)) continue;
      final text = storage.read(key);
      // Entries that cannot be read are left alone, as before.
      if (text == null || _decode(text) == null) continue;
      final name = key.substring(_projectKeyPrefix.length);
      try {
        // One kept here already was moved before; it is the newer.
        if (await store.read(name) == null) {
          await store.write(name, text, const {});
          if (await store.read(name) != text) continue;
        }
        storage.remove(key);
      } on StorageFailed {
        // Left where it is; moved next time.
      }
    }
  }

  final ProjectStore? _store;

  /// `localStorage`, for the notice.
  final BrowserStorage storage;
  final DateTime Function() _now;
  final _projects = <String, StoredProject>{};

  /// The last write; the next one waits for it.
  Future<void> _writes = Future.value();
  var _pending = 0;

  /// Whether a write has not finished yet.
  bool get busy => _pending > 0;

  static String _key(String name) => name.toLowerCase();

  /// The projects, the last saved first. Entries that cannot be read, or
  /// were written by a newer GuBASIC, are left out and left alone.
  List<StoredProject> list() =>
      _projects.values.toList()..sort((a, b) => b.savedAt.compareTo(a.savedAt));

  StoredProject? read(String name) => _projects[_key(name)];

  /// Whether a project named [name] (in any case) is kept.
  bool contains(String name) => _projects.containsKey(_key(name));

  /// The pictures of project [name]. Throws [StorageFailed].
  Future<Map<String, Uint8List>> pictures(String name) async {
    final store = _store;
    final p = read(name);
    if (store == null || p == null || p.pictures.isEmpty) return const {};
    return store.readPictures(_key(name));
  }

  /// Keeps [files] and [pictures] as project [name]. [fromFile] says they
  /// came from a `.zip`, so they are not changed since a download. Throws
  /// [StorageFailed].
  Future<void> save(
    String name,
    Map<String, String> files, {
    Map<String, Uint8List> pictures = const {},
    bool fromFile = false,
  }) => _queue(() async {
    final before = read(name);
    final changed =
        !fromFile &&
        (before == null ||
            before.changedSinceDownload ||
            !_sameFiles(before.files, files) ||
            !_sameNames(before.pictures, pictures.keys));
    await _write(
      StoredProject(
        name: name,
        files: files,
        pictures: pictures.keys.toList(),
        savedAt: _now(),
        downloadedAt: fromFile ? null : before?.downloadedAt,
        changedSinceDownload: changed,
      ),
      pictures,
    );
  });

  /// Records that project [name] was just downloaded.
  Future<void> markDownloaded(String name) => _queue(() async {
    final p = read(name);
    if (p == null) return;
    await _write(
      StoredProject(
        name: p.name,
        files: p.files,
        pictures: p.pictures,
        savedAt: p.savedAt,
        downloadedAt: _now(),
        changedSinceDownload: false,
      ),
      null,
    );
  });

  /// Deletes project [name]. Throws [StorageFailed].
  Future<void> delete(String name) => _queue(() async {
    await _store?.delete(_key(name));
    _projects.remove(_key(name));
  });

  /// Whether the notice about the browser's storage was shown here.
  bool get noticeShown => storage.read(_noticeKey) != null;

  void markNoticeShown() {
    try {
      storage.write(_noticeKey, '1');
    } on StorageFailed {
      // Shown again next time; nothing is lost.
    }
  }

  Future<void> _queue(Future<void> Function() write) {
    _pending++;
    final done = _writes.then((_) => write());
    _writes = done.then((_) {}, onError: (_) {});
    return done.whenComplete(() => _pending--);
  }

  Future<void> _write(StoredProject p, Map<String, Uint8List>? pictures) async {
    final store = _store;
    if (store == null) throw const StorageFailed();
    await store.write(
      _key(p.name),
      jsonEncode({
        'formatVersion': browserProjectVersion,
        'name': p.name,
        'files': p.files,
        'pictures': p.pictures,
        'savedAt': p.savedAt.toUtc().toIso8601String(),
        'downloadedAt': p.downloadedAt?.toUtc().toIso8601String(),
        'changedSinceDownload': p.changedSinceDownload,
      }),
      pictures,
    );
    _projects[_key(p.name)] = p;
  }

  static StoredProject? _decode(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      final version = json['formatVersion'];
      if (version is! int || version < 1 || version > browserProjectVersion) {
        return null;
      }
      final downloaded = json['downloadedAt'] as String?;
      return StoredProject(
        name: json['name']! as String,
        files: (json['files']! as Map<String, Object?>).map(
          (k, v) => MapEntry(k, v! as String),
        ),
        pictures: [
          for (final p in json['pictures'] as List<Object?>? ?? const [])
            p! as String,
        ],
        savedAt: DateTime.parse(json['savedAt']! as String).toLocal(),
        downloadedAt: downloaded == null
            ? null
            : DateTime.parse(downloaded).toLocal(),
        changedSinceDownload: json['changedSinceDownload']! as bool,
      );
    } catch (_) {
      return null;
    }
  }

  static bool _sameFiles(Map<String, String> a, Map<String, String> b) =>
      a.length == b.length && a.entries.every((e) => b[e.key] == e.value);

  static bool _sameNames(List<String> a, Iterable<String> b) =>
      a.length == b.length && a.toSet().containsAll(b);
}
