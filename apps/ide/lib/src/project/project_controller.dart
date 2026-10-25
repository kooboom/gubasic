import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import '../strings.dart';
import 'browser.dart';
import 'folders.dart';
import 'last_project.dart';
import 'open_project.dart';
import 'picture_reduce.dart';
import 'project_pictures.dart';
import 'project_zip.dart';

/// A picture file the user chose: its name and its bytes.
typedef PickedPicture = ({String name, Uint8List bytes});

/// The system's dialogs for choosing where projects are (D32).
class ProjectPickers {
  const ProjectPickers({
    required this.openProjectFile,
    required this.saveLocation,
    this.openPicture,
  });

  /// Asks for a picture file to add to the project (D51), or null when
  /// the user cancels. [confirm] is the word on the dialog's button.
  final Future<PickedPicture?> Function(String confirm)? openPicture;

  /// Asks for a `.gbproj` file to open: its path, or null when the user
  /// cancels. [confirm] is the word on the dialog's button.
  final Future<String?> Function(String confirm) openProjectFile;

  /// Asks where to save a project and under what name, offering
  /// [suggestedName]: the path the user chose (`…/MyQuiz`), or null.
  final Future<String?> Function(String suggestedName, String confirm)
  saveLocation;
}

/// What to do with unsaved changes.
enum _Unsaved { save, discard, cancel }

/// Opens and saves projects: the built-in examples, projects on disk
/// (D32) and, on the web, projects kept in the browser (D33). The
/// commands ask the user through dialogs shown in the given context.
class ProjectController extends ChangeNotifier {
  ProjectController({
    required this.examples,
    this.examplePictures = const {},
    required this.strings,
    this.folders,
    this.pickers,
    this.browser,
    this._kept,
    this.pickZip,
    this.autosaveDelay = const Duration(seconds: 2),
    this._settings,
    this.lastProject,
    String open = 'hello',
  }) : _current = _example(examples, examplePictures, open) {
    if (browser case final browser?) {
      // Also while a project is being written: closing the page then
      // could stop the write (D53).
      browser.guardUnload(() => changedSinceDownload || (_kept?.busy ?? false));
      browser.onHidden(_pageHidden);
    }
  }

  /// The built-in projects: name → file name → text.
  final Map<String, Map<String, String>> examples;

  /// The pictures of the built-in projects that have some: name →
  /// picture name → bytes.
  final Map<String, Map<String, Uint8List>> examplePictures;

  static OpenProject _example(
    Map<String, Map<String, String>> examples,
    Map<String, Map<String, Uint8List>> pictures,
    String name,
  ) => OpenProject(
    ExampleLocation(name),
    examples[name]!,
    pictures: pictures[name] ?? const {},
  );
  final IdeStrings strings;

  /// The disk, or null where projects cannot be opened or saved (the web,
  /// for now).
  final ProjectFolders? folders;
  final ProjectPickers? pickers;

  /// The web browser, or null on the desktop; with it, the projects kept
  /// there (D53), opened before the IDE starts.
  final Browser? browser;

  /// Asks for a `.zip` file: its bytes, or null when the user cancels.
  final Future<List<int>?> Function()? pickZip;

  /// Where the project open last is remembered, to open it again when the
  /// IDE starts (D62); null: always start with [open].
  final LastProject? lastProject;

  /// How long after a change a project in the browser is kept.
  final Duration autosaveDelay;

  OpenProject _current;
  OpenProject? _folderProject;
  OpenProject? _browserProject;
  final BrowserProjects? _kept;
  Timer? _autosave;

  /// The open project.
  OpenProject get current => _current;

  /// Whether the File menu offers projects on disk (the desktop).
  bool get canUseFolders => folders != null && pickers != null;

  /// Whether the File menu offers projects in the browser (the web).
  bool get canUseBrowser => _kept != null && pickZip != null;

  /// The projects kept in this browser, or null on the desktop.
  BrowserProjects? get kept => _kept;

  /// Whether the open project has changes that were not downloaded as a
  /// `.zip` (web): an example's or a kept project's changes since then.
  bool get changedSinceDownload => switch (_current.location) {
    ExampleLocation() => _current.isDirty,
    BrowserLocation(:final name) =>
      _current.isDirty || (_kept?.read(name)?.changedSinceDownload ?? true),
    FolderLocation() => false,
  };

  /// The project menu's entries, a key and the words shown: the examples
  /// by name, then the project on disk last opened or saved, if any.
  List<(String, String)> get menuEntries => [
    for (final name in examples.keys) ('example:$name', name),
    if (_folderProject case final p?) ('folder', p.project.name),
    if (_browserProject case final p?) ('browser', p.project.name),
  ];

  /// The menu key of the open project.
  String get currentKey => switch (_current.location) {
    ExampleLocation(:final name) => 'example:$name',
    FolderLocation() => 'folder',
    BrowserLocation() => 'browser',
  };

  /// Opens the menu entry [key], after asking about unsaved changes.
  Future<void> choose(BuildContext context, String key) async {
    context = _lasting(context);
    if (key == currentKey) return;
    if (!await mayLeave(context)) return;
    if (key == 'folder') {
      _show(_folderProject!);
    } else if (key == 'browser') {
      _show(_browserProject!);
    } else {
      final name = key.substring('example:'.length);
      _show(_example(examples, examplePictures, name));
    }
  }

  /// Asks for a `.gbproj` file and opens its project.
  Future<void> open(BuildContext context) async {
    context = _lasting(context);
    if (!await mayLeave(context)) return;
    if (!context.mounted) return;
    final file = await _whilePicking(
      () => pickers!.openProjectFile(strings.openButton),
    );
    if (file == null || !context.mounted) return;
    try {
      final read = await readProject(folders!, file);
      final project = OpenProject(
        FolderLocation(folders!.parent(file)),
        read.files,
        pictures: read.pictures,
      );
      _folderProject = project;
      _show(project);
      if (context.mounted) await _tellMissing(context, read.missing);
    } on FolderProblem catch (p) {
      if (context.mounted) await _tell(context, _describe(p));
    }
  }

  /// Saves the open project: into its folder, or as a copy when it is an
  /// example. Gives whether it was saved.
  Future<bool> save(BuildContext context) async {
    context = _lasting(context);
    final project = _current;
    final location = project.location;
    if (location is BrowserLocation) {
      if (!project.isDirty) {
        _snack(context, strings.nothingToSave);
        return true;
      }
      final kept = await _keep(context);
      if (kept && context.mounted) _snack(context, strings.keptInBrowser);
      return kept;
    }
    if (location is! FolderLocation) return saveAs(context);
    if (!project.isDirty) {
      _snack(context, strings.nothingToSave);
      return true;
    }
    try {
      final changed = await changedOnDisk(
        folders!,
        location.path,
        project.files,
        project.saved,
        pictures: project.pictures,
        savedPictures: project.savedPictures,
      );
      if (changed.isNotEmpty) {
        if (!context.mounted) return false;
        final go = await _confirm(
          context,
          strings.changedOnDisk.replaceAll('{0}', changed.join(', ')),
          strings.overwrite,
        );
        if (!go) return false;
      }
      await writeChanged(
        folders!,
        location.path,
        project.files,
        project.saved,
        pictures: project.pictures,
        savedPictures: project.savedPictures,
      );
      project.markSaved();
      if (context.mounted) {
        _snack(context, strings.saved.replaceAll('{0}', location.path));
      }
      return true;
    } on FolderProblem catch (p) {
      if (context.mounted) await _tell(context, _describe(p));
      return false;
    }
  }

  /// Saves the open project as a new project: the user chooses a place
  /// and a name, and the project is copied into a new folder of that name
  /// (D32). Then keeps working there. Gives whether it was saved.
  Future<bool> saveAs(BuildContext context) async {
    context = _lasting(context);
    final project = _current;
    if (project.isExample) {
      final go = await _confirm(
        context,
        strings.exampleIsReadOnly,
        strings.saveCopyButton,
      );
      if (!go) return false;
    }
    if (!context.mounted) return false;
    if (folders == null) return _saveAsInBrowser(context);
    final fs = folders!;
    while (true) {
      if (!context.mounted) return false;
      final path = await _whilePicking(
        () => pickers!.saveLocation(project.project.name, strings.saveButton),
      );
      if (path == null || !context.mounted) return false;
      var name = fs.name(path);
      if (name.toLowerCase().endsWith('.gbproj')) {
        name = name.substring(0, name.length - '.gbproj'.length);
      }
      if (!isUsableProjectName(name)) {
        await _tell(context, strings.badProjectName);
        continue;
      }
      try {
        final (folder, files) = await saveCopy(
          fs,
          fs.parent(path),
          name,
          project.files,
          pictures: project.pictures,
        );
        if (project.isExample) {
          final copy = OpenProject(
            FolderLocation(folder),
            files,
            pictures: project.pictures,
          );
          _folderProject = copy;
          _show(copy);
        } else {
          project.markSaved(location: FolderLocation(folder), files: files);
          _folderProject = project;
          notifyListeners();
        }
        if (context.mounted) {
          _snack(context, strings.saved.replaceAll('{0}', folder));
        }
        return true;
      } on FolderExists {
        if (!context.mounted) return false;
        await _tell(context, strings.folderExists.replaceAll('{0}', name));
      } on FolderProblem catch (p) {
        if (context.mounted) await _tell(context, _describe(p));
        return false;
      }
    }
  }

  /// Whether the open project may be closed: it has no unsaved changes,
  /// or the user saved them or chose to lose them.
  Future<bool> mayLeave(BuildContext context) async {
    context = _lasting(context);
    await keepNow();
    if (!context.mounted) return false;
    if (!_current.isDirty) return true;
    final answer = await showDialog<_Unsaved>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: _message(
          strings.unsaved.replaceAll('{0}', _current.project.name),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, _Unsaved.discard),
            child: Text(strings.dontSave),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, _Unsaved.cancel),
            child: Text(strings.runtime.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, _Unsaved.save),
            child: Text(strings.saveButton),
          ),
        ],
      ),
    );
    if (!context.mounted) return false;
    return switch (answer) {
      _Unsaved.discard => true,
      _Unsaved.save => await save(context) && !_current.isDirty,
      _Unsaved.cancel || null => false,
    };
  }

  /// Whether a system dialog for choosing a file is open.
  bool get picking => _picking;
  var _picking = false;

  /// Runs [pick], a system file dialog, marking [picking] meanwhile: the
  /// IDE then shows the arrow cursor everywhere, so that the text cursor
  /// of the code view under the dialog does not show inside it.
  Future<T> _whilePicking<T>(Future<T> Function() pick) async {
    _picking = true;
    notifyListeners();
    try {
      return await pick();
    } finally {
      _picking = false;
      notifyListeners();
    }
  }

  /// The app's navigator's context: a command may open another project,
  /// which builds a new IDE shell, and its later dialogs must still show.
  BuildContext _lasting(BuildContext context) =>
      Navigator.of(context, rootNavigator: true).context;

  void _show(OpenProject project) {
    keepNow();
    _current.removeListener(_changed);
    _current = project;
    if (project.location is BrowserLocation) project.addListener(_changed);
    notifyListeners();
    unawaited(_remember(project));
  }

  /// Remembers [project] as the one open last (D62).
  Future<void> _remember(OpenProject project) async {
    final last = lastProject;
    if (last == null) return;
    final value = switch (project.location) {
      ExampleLocation(:final name) => 'example:$name',
      BrowserLocation(:final name) => 'browser:$name',
      FolderLocation(:final path) => switch (project.files.keys
          .where((f) => f.toLowerCase().endsWith('.gbproj'))
          .firstOrNull) {
        final file? when folders != null =>
          'folder:${folders!.join(path, file)}',
        _ => null,
      },
    };
    if (value != null) await last.write(value);
  }

  var _openedLast = false;

  /// Once, when the IDE has started: opens the project open last (D62),
  /// unless the user has opened or changed one since. Says so when it is
  /// no longer there, and an example stays open.
  Future<void> openLast(BuildContext context) async {
    if (_openedLast) return;
    _openedLast = true;
    final last = await lastProject?.read();
    if (last == null ||
        _current.location is! ExampleLocation ||
        _current.isDirty ||
        !context.mounted) {
      return;
    }
    context = _lasting(context);
    final colon = last.indexOf(':');
    final kind = colon < 0 ? '' : last.substring(0, colon);
    final value = last.substring(colon + 1);
    void gone() {
      if (context.mounted) {
        _snack(context, strings.lastProjectGone.replaceAll('{0}', value));
      }
    }

    switch (kind) {
      case 'example':
        if (examples.containsKey(value) && currentKey != last) {
          _show(_example(examples, examplePictures, value));
        }
      case 'browser':
        final stored = _kept?.read(value);
        if (stored == null) return gone();
        try {
          final project = OpenProject(
            BrowserLocation(stored.name),
            stored.files,
            pictures: await _kept!.pictures(stored.name),
          );
          _browserProject = project;
          _show(project);
        } on StorageFailed {
          gone();
        }
      case 'folder':
        final fs = folders;
        if (fs == null) return;
        try {
          final read = await readProject(fs, value);
          final project = OpenProject(
            FolderLocation(fs.parent(value)),
            read.files,
            pictures: read.pictures,
          );
          _folderProject = project;
          _show(project);
          if (context.mounted) await _tellMissing(context, read.missing);
        } on FolderProblem {
          gone();
        }
    }
  }

  /// A change to a project kept in the browser: keep it a moment later.
  void _changed() {
    _autosave?.cancel();
    if (_current.isDirty) _autosave = Timer(autosaveDelay, keepNow);
  }

  /// The page is hidden, maybe closing: the open project's text, if it
  /// has changes, goes to localStorage at once, in case the write that
  /// starts now does not finish before the page closes (D54).
  void _pageHidden() {
    if (_current.location case BrowserLocation(:final name)
        when _current.isDirty) {
      _kept!.writeUnsaved(name, _current.files);
    }
    keepNow();
  }

  /// Keeps the open project in the browser now, if it is one there with
  /// changes (when the page is hidden, and before another opens).
  Future<void> keepNow() async {
    _autosave?.cancel();
    _autosave = null;
    if (_current.location is BrowserLocation && _current.isDirty) {
      await _keep(null);
    }
  }

  /// Keeps the open project in the browser. Gives whether it was kept;
  /// tells why not when there is a [context]. What is written is the
  /// project as the call found it; changes made while it is written stay
  /// unsaved, to be kept next.
  Future<bool> _keep(BuildContext? context) async {
    final project = _current;
    final location = project.location as BrowserLocation;
    final files = project.files, pictures = project.pictures;
    try {
      await _kept!.save(location.name, files, pictures: pictures);
      project.markSavedAs(files, pictures);
      if (!project.isDirty) _kept.clearUnsaved(location.name);
      notifyListeners();
      return true;
    } on StorageFailed {
      _storageFailed = true;
      notifyListeners();
      if (context != null && context.mounted) {
        await _tell(context, strings.storageFailed);
      }
      return false;
    }
  }

  /// Whether keeping a project in the browser failed since it opened.
  bool get storageFailed => _storageFailed;
  var _storageFailed = false;

  /// Saves the open project as a new project kept in the browser.
  Future<bool> _saveAsInBrowser(BuildContext context) async {
    final project = _current;
    final name = await _askBrowserName(context, project.project.name);
    if (name == null || !context.mounted) return false;
    final files = renameProject(project.files, name);
    final pictures = project.pictures;
    try {
      await _kept!.save(name, files, pictures: pictures);
    } on StorageFailed {
      if (context.mounted) await _tell(context, strings.storageFailed);
      return false;
    }
    final copy = OpenProject(BrowserLocation(name), files, pictures: pictures);
    _browserProject = copy;
    _show(copy);
    if (!context.mounted) return true;
    _snack(context, strings.keptInBrowser);
    await _noticeOnce(context);
    return true;
  }

  /// Asks for the name of a new project in the browser, until it is a
  /// usable name that is not kept yet; null when the user cancels.
  Future<String?> _askBrowserName(BuildContext context, String initial) async {
    var name = initial;
    while (true) {
      if (!context.mounted) return null;
      final chosen = await showDialog<String>(
        context: context,
        builder: (context) => _NameDialog(strings: strings, initial: name),
      );
      if (chosen == null || !context.mounted) return null;
      name = chosen;
      if (!_kept!.contains(name)) return name;
      await _tell(
        context,
        strings.projectExistsInBrowser.replaceAll('{0}', name),
      );
    }
  }

  /// Tells, once in this browser, that projects kept here can be lost.
  Future<void> _noticeOnce(BuildContext context) async {
    if (_kept!.noticeShown) return;
    _kept.markNoticeShown();
    await _tell(context, strings.browserNotice);
  }

  /// Deletes project [name] from the browser. If it is open, the first
  /// example opens instead, so that keeping it later does not bring the
  /// deleted project back.
  Future<void> _forget(String name) async {
    await _kept!.delete(name);
    final open = _browserProject;
    if (open == null ||
        (open.location as BrowserLocation).name.toLowerCase() !=
            name.toLowerCase()) {
      return;
    }
    _browserProject = null;
    if (identical(_current, open)) {
      _autosave?.cancel();
      _autosave = null;
      _current.removeListener(_changed);
      final first = examples.keys.first;
      _current = _example(examples, examplePictures, first);
    }
    notifyListeners();
  }

  /// Shows the projects kept in this browser, to open or delete one.
  Future<void> openKept(BuildContext context) async {
    context = _lasting(context);
    if (!await mayLeave(context)) return;
    if (!context.mounted) return;
    final name = await showDialog<String>(
      context: context,
      builder: (context) => _KeptDialog(controller: this),
    );
    if (name == null) return;
    final stored = _kept!.read(name);
    if (stored == null) return;
    final Map<String, Uint8List> pictures;
    try {
      pictures = await _kept.pictures(name);
    } on StorageFailed {
      if (context.mounted) await _tell(context, strings.storageFailed);
      return;
    }
    final project = OpenProject(
      BrowserLocation(stored.name),
      stored.files,
      pictures: pictures,
    );
    _browserProject = project;
    _show(project);
  }

  /// Gives the open project as `NAME.zip`, the folder `NAME/` with its
  /// files in it (D33).
  void downloadZip(BuildContext context) {
    keepNow();
    final project = _current;
    final name = switch (project.location) {
      BrowserLocation(:final name) => name,
      _ => project.project.name,
    };
    browser!.download(
      '$name.zip',
      zipProject(name, project.files, pictures: project.pictures),
    );
    if (project.location is BrowserLocation) {
      _kept!
          .markDownloaded(name)
          .then(
            (_) => notifyListeners(),
            // The download happened; only the note of it is missing.
            onError: (Object _) {},
          );
    }
    notifyListeners();
  }

  /// Asks for a `.zip` file and keeps its project in the browser.
  Future<void> uploadZip(BuildContext context) async {
    context = _lasting(context);
    if (!await mayLeave(context)) return;
    if (!context.mounted) return;
    final bytes = await _whilePicking(pickZip!);
    if (bytes == null || !context.mounted) return;
    final UnzippedProject unzipped;
    try {
      unzipped = unzipProject(bytes);
    } on ZipProblem catch (p) {
      await _tell(context, _describeZip(p));
      return;
    }
    var name = unzipped.name;
    var files = unzipped.files;
    if (!isUsableProjectName(name) || _kept!.contains(name)) {
      if (_kept!.contains(name)) {
        if (!context.mounted) return;
        await _tell(
          context,
          strings.projectExistsInBrowser.replaceAll('{0}', name),
        );
      }
      if (!context.mounted) return;
      final chosen = await _askBrowserName(
        context,
        isUsableProjectName(name) ? name : '',
      );
      if (chosen == null || !context.mounted) return;
      name = chosen;
      files = renameProject(files, name);
    }
    try {
      await _kept.save(
        name,
        files,
        pictures: unzipped.pictures,
        fromFile: true,
      );
    } on StorageFailed {
      if (!context.mounted) return;
      await _tell(context, strings.storageFailed);
      return;
    }
    final project = OpenProject(
      BrowserLocation(name),
      files,
      pictures: unzipped.pictures,
    );
    _browserProject = project;
    _show(project);
    if (!context.mounted) return;
    await _tellMissing(context, unzipped.missing);
    if (!context.mounted) return;
    if (unzipped.ignored.isNotEmpty) {
      await _tell(
        context,
        strings.zipIgnored.replaceAll('{0}', unzipped.ignored.join(', ')),
      );
      if (!context.mounted) return;
    }
    await _noticeOnce(context);
  }

  /// Tells which of the project's files and pictures [missing] lists
  /// were not there.
  Future<void> _tellMissing(BuildContext context, List<String> missing) async {
    final pictures = [
      for (final m in missing)
        if (m.startsWith('$picturesFolder/'))
          m.substring(picturesFolder.length + 1),
    ];
    final files = [
      for (final m in missing)
        if (!m.startsWith('$picturesFolder/')) m,
    ];
    if (files.isNotEmpty) {
      await _tell(
        context,
        strings.missingFiles.replaceAll('{0}', files.join(', ')),
      );
    }
    if (pictures.isNotEmpty && context.mounted) {
      await _tell(
        context,
        strings.missingPictures.replaceAll('{0}', pictures.join(', ')),
      );
    }
  }

  /// Whether pictures can be added to projects here: where projects are
  /// kept, on disk or in the browser, and a picture can be chosen.
  bool get canAddPictures =>
      (folders != null || _kept != null) && pickers?.openPicture != null;

  /// Asks for a picture file and adds it to the open project, or replaces
  /// the picture of that name after asking (D51). Gives the picture's name
  /// in the project, or null when none was added.
  Future<String?> addPicture(BuildContext context) async {
    if (!canAddPictures) return null;
    final picked = await _whilePicking(
      () => pickers!.openPicture!(strings.addButton),
    );
    if (picked == null || !context.mounted) return null;
    // A Mac gives Hangul in file names with each syllable split (D51).
    var name = composeHangul(picked.name);
    var bytes = picked.bytes;
    final project = _current;
    if (checkPicture(name, bytes, project.files, project.pictures)
        case final refused?) {
      final room = _reducibleRoom(refused, name, bytes, project);
      if (room == null) {
        await _tell(context, _describePicture(refused));
        return null;
      }
      final reduced = await _offerReduced(context, refused, name, bytes, room);
      if (reduced == null || !context.mounted) return null;
      (name, bytes) = (reduced.name, reduced.bytes);
      if (checkPicture(name, bytes, project.files, project.pictures)
          case final refused?) {
        await _tell(context, _describePicture(refused));
        return null;
      }
      _snack(
        context,
        strings.pictureReduced
            .replaceAll('{0}', name)
            .replaceAll('{1}', '${reduced.width}')
            .replaceAll('{2}', '${reduced.height}')
            .replaceAll('{3}', _megabytes(bytes.length)),
      );
    }
    final existing = pictureNamed(project.pictures.keys, name);
    if (existing != null &&
        !await _confirm(
          context,
          strings.replacePicture.replaceAll('{0}', existing),
          strings.replaceButton,
        )) {
      return null;
    }
    project.setPicture(name, bytes);
    // In the browser a picture is kept at once, not a moment later: the
    // text kept as the page hides does not carry pictures (D54).
    if (project.location is BrowserLocation) await keepNow();
    return existing ?? name;
  }

  /// The most a smaller copy of picture [name] may take, when [refused]
  /// is a refusal that making it smaller can answer (D56): it is too
  /// large, too wide or too much for the project, and is a picture the
  /// IDE can read. Null otherwise.
  static int? _reducibleRoom(
    PictureRefused refused,
    String name,
    Uint8List bytes,
    OpenProject project,
  ) {
    if (refused is! PictureTooLarge &&
        refused is! PictureTooWide &&
        refused is! ProjectPicturesFull) {
      return null;
    }
    final replaced = pictureNamed(
      project.pictures.keys,
      reducedPictureName(name),
    );
    var room = maxProjectPictureBytes;
    for (final MapEntry(:key, :value) in project.pictures.entries) {
      if (key != replaced) room -= value.length;
    }
    room = min(room, maxPictureBytes);
    return room > 0 ? room : null;
  }

  /// Says why picture [name] is not taken, with a button that adds a
  /// smaller copy of it instead when it can be read, and makes that copy
  /// when the button is pressed. Null when it is not pressed, or no copy
  /// small enough can be made (then says so).
  Future<ReducedPicture?> _offerReduced(
    BuildContext context,
    PictureRefused refused,
    String name,
    Uint8List bytes,
    int room,
  ) async {
    final bool animated;
    try {
      animated = await isAnimatedPicture(bytes);
    } on Object {
      // Not a picture the IDE can read, so not one it can make smaller.
      if (context.mounted) await _tell(context, _describePicture(refused));
      return null;
    }
    if (!context.mounted) return null;
    final offer = [
      _describePicture(refused),
      strings.reduceOffer
          .replaceAll('{0}', '$reducedPictureSide')
          .replaceAll('{1}', reducedPictureName(name)),
      if (animated) strings.reduceFirstFrameOnly,
    ].join('\n\n');
    if (!await _confirm(context, offer, strings.reduceButton) ||
        !context.mounted) {
      return null;
    }
    // Reading a phone photo takes a moment: a dialog says it is working.
    final navigator = Navigator.of(context);
    unawaited(
      showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          content: Row(
            children: [
              const SizedBox.square(
                dimension: 24,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(width: 16),
              Expanded(child: Text(strings.reducing)),
            ],
          ),
        ),
      ),
    );
    final ReducedPicture? reduced;
    try {
      reduced = await reducePicture(name, bytes, maxBytes: room);
    } finally {
      navigator.pop();
    }
    if (reduced == null && context.mounted) {
      await _tell(context, strings.reduceFailed.replaceAll('{0}', name));
    }
    return reduced;
  }

  /// Takes picture [name] out of the open project after asking, unless a
  /// control shows it: then tells which ones. Gives whether it was taken
  /// out; its file goes when the project is saved.
  Future<bool> removePicture(BuildContext context, String name) async {
    final project = _current;
    final users = pictureUsers(project.files, name);
    if (users.isNotEmpty) {
      await _tell(
        context,
        strings.pictureInUse
            .replaceAll('{0}', name)
            .replaceAll('{1}', users.join(', ')),
      );
      return false;
    }
    if (!await _confirm(
      context,
      strings.confirmRemovePicture.replaceAll('{0}', name),
      strings.removePicture,
    )) {
      return false;
    }
    project.removePicture(name);
    if (project.location is BrowserLocation) await keepNow();
    return true;
  }

  /// Once, when the IDE has started: if text that was not kept when the
  /// page closed was brought back (D54), opens that project and says so,
  /// naming any pictures it lists that were not kept.
  Future<void> showRestored(BuildContext context) async {
    final kept = _kept;
    if (kept == null || kept.restored.isEmpty) return;
    final names = List.of(kept.restored);
    kept.restored.clear();
    context = _lasting(context);
    final stored = kept.read(names.first);
    if (stored != null) {
      try {
        final pictures = Map.of(await kept.pictures(stored.name));
        // The text decides which pictures the project has: one it no
        // longer lists was being taken out as the page closed.
        final listed = _listedPictures(stored.files);
        pictures.removeWhere((name, _) => !listed.contains(name));
        final project = OpenProject(
          BrowserLocation(stored.name),
          stored.files,
          pictures: pictures,
        );
        _browserProject = project;
        _show(project);
      } on StorageFailed {
        // Listed in the message; opened from File → Open.
      }
    }
    if (!context.mounted) return;
    await _tell(
      context,
      strings.restoredUnsaved.replaceAll('{0}', names.join(', ')),
    );
    final missing = [
      for (final p in _listedPictures(_current.files))
        if (!_current.pictures.containsKey(p)) p,
    ];
    if (missing.isNotEmpty && context.mounted) {
      await _tell(
        context,
        strings.missingPicturesKept.replaceAll('{0}', missing.join(', ')),
      );
    }
  }

  /// The pictures the `.gbproj` file of [files] lists.
  static List<String> _listedPictures(Map<String, String> files) {
    final projectFile = files.entries
        .where((e) => e.key.toLowerCase().endsWith('.gbproj'))
        .firstOrNull;
    return readProjectFile(projectFile?.value ?? '').project.pictures;
  }

  static String _megabytes(int bytes) =>
      (bytes / (1024 * 1024)).toStringAsFixed(1);

  String _describePicture(PictureRefused p) {
    final mb = _megabytes;
    return switch (p) {
      ProjectFileHasErrors() => strings.pictureProjectFileErrors,
      BadPictureName(:final name, :final problem) => switch (problem) {
        PictureNameProblem.length => strings.pictureNameTooLong,
        PictureNameProblem.character => strings.pictureNameCharacters,
        PictureNameProblem.extension => strings.pictureNotTaken,
      }.replaceAll('{0}', name),
      NotAPicture(:final name, :final format) =>
        (format == PictureFormat.heic
                ? strings.pictureIsHeic
                : strings.pictureNotTaken)
            .replaceAll('{0}', name),
      PictureTooLarge(:final name, :final bytes) =>
        strings.pictureTooLarge
            .replaceAll('{0}', name)
            .replaceAll('{1}', mb(bytes)),
      PictureTooWide(:final name, :final width, :final height) =>
        strings.pictureTooWide
            .replaceAll('{0}', name)
            .replaceAll('{1}', '$width')
            .replaceAll('{2}', '$height'),
      ProjectPicturesFull(:final name) => strings.picturesFull.replaceAll(
        '{0}',
        name,
      ),
    };
  }

  String _describeZip(ZipProblem p) => switch (p) {
    NotAZip() => strings.notAZip,
    ZipTooLarge() => strings.zipTooLarge,
    UnsafeZipPath(:final path) => strings.unsafeZipPath.replaceAll('{0}', path),
    ZipLayout() => strings.zipLayout,
    ZipProjectFiles(:final found) => strings.zipProjectFiles.replaceAll(
      '{0}',
      found.isEmpty ? strings.none : found.join(', '),
    ),
    ZipNotText(:final file) => strings.zipNotText.replaceAll('{0}', file),
  };

  @override
  void dispose() {
    _autosave?.cancel();
    _current.removeListener(_changed);
    super.dispose();
  }

  String _describe(FolderProblem p) => switch (p) {
    MissingProjectFile(:final file) => strings.missingFiles.replaceAll(
      '{0}',
      file,
    ),
    FileFailed(:final file, :final reason, :final writing) =>
      (writing ? strings.cannotWrite : strings.cannotRead)
          .replaceAll('{0}', file)
          .replaceAll('{1}', reason ?? strings.notText),
    FolderExists(:final name) => strings.folderExists.replaceAll('{0}', name),
  };

  /// Where the programs' settings are kept (SaveSetting, D48), each
  /// project's by its name; shared_preferences unless given, made only
  /// when needed.
  GbSettingsStore get settings => _settings ??= GbPreferencesSettings();
  GbSettingsStore? _settings;

  /// File → Clear Saved Settings: forgets what the open project's program
  /// saved with SaveSetting, after asking (D48).
  Future<void> clearSettings(BuildContext context) async {
    final name = current.project.name;
    if (!await _confirm(
      context,
      strings.clearSettingsQuestion.replaceAll('{0}', name),
      strings.clearSettingsYes,
    )) {
      return;
    }
    await settings.clear(name);
    if (context.mounted) {
      _snack(context, strings.settingsCleared.replaceAll('{0}', name));
    }
  }

  /// Tells [message] at the bottom for a while; the title's mark tells
  /// the rest (whether anything is unsaved), so missing it loses nothing.
  void _snack(BuildContext context, String message) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(
          content: Text(message),
          duration: const Duration(seconds: 8),
          showCloseIcon: true,
        ),
      );

  Future<void> _tell(BuildContext context, String message) => showDialog(
    context: context,
    builder: (context) => AlertDialog(
      content: _message(message),
      actions: [
        FilledButton(
          onPressed: () => Navigator.pop(context),
          child: Text(strings.runtime.ok),
        ),
      ],
    ),
  );

  Future<bool> _confirm(
    BuildContext context,
    String message,
    String yes,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: _message(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text(strings.runtime.cancel),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: Text(yes),
            ),
          ],
        ),
      ) ??
      false;
}

/// Asks for a project's name; the OK button waits for a usable one.
class _NameDialog extends StatefulWidget {
  const _NameDialog({required this.strings, required this.initial});

  final IdeStrings strings;
  final String initial;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final _field = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  bool get _usable => isUsableProjectName(_field.text);

  void _ok() {
    if (_usable) Navigator.pop(context, _field.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    return AlertDialog(
      title: Text(s.saveAsTitle),
      content: SizedBox(
        width: 400,
        child: TextField(
          controller: _field,
          autofocus: true,
          decoration: InputDecoration(
            labelText: s.projectName,
            errorText: _usable ? null : s.badProjectName,
            errorMaxLines: 3,
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _ok(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.runtime.cancel),
        ),
        FilledButton(
          onPressed: _usable ? _ok : null,
          child: Text(s.saveButton),
        ),
      ],
    );
  }
}

/// The projects kept in this browser: choosing one gives its name;
/// each can be deleted after asking.
class _KeptDialog extends StatefulWidget {
  const _KeptDialog({required this.controller});

  final ProjectController controller;

  @override
  State<_KeptDialog> createState() => _KeptDialogState();
}

class _KeptDialogState extends State<_KeptDialog> {
  Future<void> _delete(StoredProject p) async {
    final s = widget.controller.strings;
    final go = await widget.controller._confirm(
      context,
      s.confirmDelete.replaceAll('{0}', p.name),
      s.deleteProject,
    );
    if (!go) return;
    try {
      await widget.controller._forget(p.name);
    } on StorageFailed {
      if (mounted) await widget.controller._tell(context, s.storageFailed);
    }
    if (mounted) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.controller.strings;
    final projects = widget.controller._kept!.list();
    return AlertDialog(
      title: Text(s.keptProjectsTitle),
      content: SizedBox(
        width: 480,
        child: projects.isEmpty
            ? Text(s.noKeptProjects)
            : ListView(
                shrinkWrap: true,
                children: [
                  for (final p in projects)
                    ListTile(
                      title: Text(p.name),
                      subtitle: Text(
                        [
                          s.keptAt.replaceAll('{0}', formatTime(p.savedAt)),
                          if (p.changedSinceDownload) s.notDownloaded,
                        ].join(' · '),
                      ),
                      onTap: () => Navigator.pop(context, p.name),
                      trailing: IconButton(
                        tooltip: s.deleteProject,
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () => _delete(p),
                      ),
                    ),
                ],
              ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.runtime.cancel),
        ),
      ],
    );
  }
}

/// [time] as `HH:mm` today, otherwise `YYYY-MM-DD HH:mm`.
String formatTime(DateTime time, {DateTime? now}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final today = now ?? DateTime.now();
  final clock = '${two(time.hour)}:${two(time.minute)}';
  if (time.year == today.year &&
      time.month == today.month &&
      time.day == today.day) {
    return clock;
  }
  return '${time.year}-${two(time.month)}-${two(time.day)} $clock';
}

/// A dialog's message, kept to a width that reads well on wide windows.
Widget _message(String text) => ConstrainedBox(
  constraints: const BoxConstraints(maxWidth: 440),
  child: Text(text),
);
