import 'dart:convert';

/// Every key the IDE keeps in the browser starts with this, so that
/// other pages on the same site (the playground, later projects) never
/// mix with it or remove it (D33).
const browserKeyPrefix = 'gubasic.ide.';

const _projectKeyPrefix = '${browserKeyPrefix}project.';
const _noticeKey = '${browserKeyPrefix}noticeShown';

/// The layout of a project kept in the browser; a newer one is left alone.
const browserProjectVersion = 1;

/// Writing to the browser's storage failed: it is full, or turned off.
class StorageFailed implements Exception {
  const StorageFailed();
}

/// The browser's key-value storage for text (`localStorage`).
abstract interface class BrowserStorage {
  Iterable<String> get keys;
  String? read(String key);

  /// Throws [StorageFailed].
  void write(String key, String value);
  void remove(String key);
}

/// What the web IDE needs from the browser besides storage.
abstract interface class Browser {
  BrowserStorage get storage;

  /// Gives the user [bytes] as a file named [fileName] (a download).
  void download(String fileName, List<int> bytes);

  /// Makes the browser ask before the page is left while [unsaved] says
  /// so; its words are the browser's own.
  void guardUnload(bool Function() unsaved);

  /// Runs [action] when the page is hidden: another tab, or closing.
  void onHidden(void Function() action);

  /// Goes to [url], relative to the page, in the same tab; the browser
  /// asks first if [guardUnload] says the work is not saved.
  void open(String url);
}

/// A project kept in the browser.
class StoredProject {
  const StoredProject({
    required this.name,
    required this.files,
    required this.savedAt,
    this.downloadedAt,
    this.changedSinceDownload = true,
  });

  final String name;
  final Map<String, String> files;
  final DateTime savedAt;

  /// When it was last downloaded as a `.zip`, or null.
  final DateTime? downloadedAt;

  /// Whether it changed since it was last downloaded (or uploaded).
  final bool changedSinceDownload;
}

/// The projects kept in the browser (D33): one key each, under
/// [browserKeyPrefix], as JSON with its layout's version.
class BrowserProjects {
  BrowserProjects(this.storage, {DateTime Function()? now})
    : _now = now ?? DateTime.now;

  final BrowserStorage storage;
  final DateTime Function() _now;

  String _key(String name) => '$_projectKeyPrefix${name.toLowerCase()}';

  /// The projects, the last saved first. Entries that cannot be read, or
  /// were written by a newer GuBASIC, are left out and left alone.
  List<StoredProject> list() {
    final projects = [
      for (final key in storage.keys.toList())
        if (key.startsWith(_projectKeyPrefix)) ?_decode(storage.read(key)),
    ]..sort((a, b) => b.savedAt.compareTo(a.savedAt));
    return projects;
  }

  StoredProject? read(String name) => _decode(storage.read(_key(name)));

  /// Whether a project named [name] (in any case) is kept.
  bool contains(String name) => storage.read(_key(name)) != null;

  /// Keeps [files] as project [name]. [fromFile] says they came from a
  /// `.zip`, so they are not changed since a download. Throws
  /// [StorageFailed].
  void save(String name, Map<String, String> files, {bool fromFile = false}) {
    final before = read(name);
    final changed =
        !fromFile &&
        (before == null ||
            before.changedSinceDownload ||
            !_sameFiles(before.files, files));
    _write(
      StoredProject(
        name: name,
        files: files,
        savedAt: _now(),
        downloadedAt: fromFile ? null : before?.downloadedAt,
        changedSinceDownload: changed,
      ),
    );
  }

  /// Records that project [name] was just downloaded.
  void markDownloaded(String name) {
    final p = read(name);
    if (p == null) return;
    _write(
      StoredProject(
        name: p.name,
        files: p.files,
        savedAt: p.savedAt,
        downloadedAt: _now(),
        changedSinceDownload: false,
      ),
    );
  }

  void delete(String name) => storage.remove(_key(name));

  /// Whether the notice about the browser's storage was shown here.
  bool get noticeShown => storage.read(_noticeKey) != null;

  void markNoticeShown() {
    try {
      storage.write(_noticeKey, '1');
    } on StorageFailed {
      // Shown again next time; nothing is lost.
    }
  }

  void _write(StoredProject p) => storage.write(
    _key(p.name),
    jsonEncode({
      'formatVersion': browserProjectVersion,
      'name': p.name,
      'files': p.files,
      'savedAt': p.savedAt.toUtc().toIso8601String(),
      'downloadedAt': p.downloadedAt?.toUtc().toIso8601String(),
      'changedSinceDownload': p.changedSinceDownload,
    }),
  );

  static StoredProject? _decode(String? text) {
    if (text == null) return null;
    try {
      final json = jsonDecode(text) as Map<String, Object?>;
      if (json['formatVersion'] != browserProjectVersion) return null;
      final downloaded = json['downloadedAt'] as String?;
      return StoredProject(
        name: json['name']! as String,
        files: (json['files']! as Map<String, Object?>).map(
          (k, v) => MapEntry(k, v! as String),
        ),
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
}
