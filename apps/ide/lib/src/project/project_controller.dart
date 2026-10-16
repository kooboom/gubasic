import 'dart:async';

import 'package:flutter/material.dart';

import '../strings.dart';
import 'browser.dart';
import 'folders.dart';
import 'open_project.dart';
import 'project_zip.dart';

/// The system's dialogs for choosing where projects are (D32).
class ProjectPickers {
  const ProjectPickers({
    required this.openProjectFile,
    required this.saveLocation,
  });

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
    required this.strings,
    this.folders,
    this.pickers,
    this.browser,
    this.pickZip,
    this.autosaveDelay = const Duration(seconds: 2),
    String open = 'hello',
  }) : _current = OpenProject(ExampleLocation(open), examples[open]!) {
    if (browser case final browser?) {
      _kept = BrowserProjects(browser.storage);
      browser.guardUnload(() => changedSinceDownload);
      browser.onHidden(keepNow);
    }
  }

  /// The built-in projects: name → file name → text.
  final Map<String, Map<String, String>> examples;
  final IdeStrings strings;

  /// The disk, or null where projects cannot be opened or saved (the web,
  /// for now).
  final ProjectFolders? folders;
  final ProjectPickers? pickers;

  /// The web browser, or null on the desktop.
  final Browser? browser;

  /// Asks for a `.zip` file: its bytes, or null when the user cancels.
  final Future<List<int>?> Function()? pickZip;

  /// How long after a change a project in the browser is kept.
  final Duration autosaveDelay;

  OpenProject _current;
  OpenProject? _folderProject;
  OpenProject? _browserProject;
  BrowserProjects? _kept;
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
      _show(OpenProject(ExampleLocation(name), examples[name]!));
    }
  }

  /// Asks for a `.gbproj` file and opens its project.
  Future<void> open(BuildContext context) async {
    context = _lasting(context);
    if (!await mayLeave(context)) return;
    if (!context.mounted) return;
    final file = await pickers!.openProjectFile(strings.openButton);
    if (file == null || !context.mounted) return;
    try {
      final read = await readProject(folders!, file);
      final project = OpenProject(
        FolderLocation(folders!.parent(file)),
        read.files,
      );
      _folderProject = project;
      _show(project);
      if (read.missing.isNotEmpty && context.mounted) {
        await _tell(
          context,
          strings.missingFiles.replaceAll('{0}', read.missing.join(', ')),
        );
      }
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
      final kept = _keep(context);
      if (kept) _snack(context, strings.keptInBrowser);
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
      await writeChanged(folders!, location.path, project.files, project.saved);
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
      final path = await pickers!.saveLocation(
        project.project.name,
        strings.saveButton,
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
        );
        if (project.isExample) {
          final copy = OpenProject(FolderLocation(folder), files);
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
    keepNow();
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
  }

  /// A change to a project kept in the browser: keep it a moment later.
  void _changed() {
    _autosave?.cancel();
    if (_current.isDirty) _autosave = Timer(autosaveDelay, keepNow);
  }

  /// Keeps the open project in the browser now, if it is one there with
  /// changes (when the page is hidden, and before another opens).
  void keepNow() {
    _autosave?.cancel();
    _autosave = null;
    if (_current.location is BrowserLocation && _current.isDirty) {
      _keep(null);
    }
  }

  /// Keeps the open project in the browser. Gives whether it was kept;
  /// tells why not when there is a [context].
  bool _keep(BuildContext? context) {
    final project = _current;
    final location = project.location as BrowserLocation;
    try {
      _kept!.save(location.name, project.files);
      project.markSaved();
      return true;
    } on StorageFailed {
      _storageFailed = true;
      notifyListeners();
      if (context != null && context.mounted) {
        _tell(context, strings.storageFailed);
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
    try {
      _kept!.save(name, files);
    } on StorageFailed {
      await _tell(context, strings.storageFailed);
      return false;
    }
    final copy = OpenProject(BrowserLocation(name), files);
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
    _kept!.markNoticeShown();
    await _tell(context, strings.browserNotice);
  }

  /// Deletes project [name] from the browser. If it is open, the first
  /// example opens instead, so that keeping it later does not bring the
  /// deleted project back.
  void _forget(String name) {
    _kept!.delete(name);
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
      _current = OpenProject(ExampleLocation(first), examples[first]!);
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
    final project = OpenProject(BrowserLocation(stored.name), stored.files);
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
    browser!.download('$name.zip', zipProject(name, project.files));
    if (project.location is BrowserLocation) {
      try {
        _kept!.markDownloaded(name);
      } on StorageFailed {
        // The download happened; only the note of it is missing.
      }
    }
    notifyListeners();
  }

  /// Asks for a `.zip` file and keeps its project in the browser.
  Future<void> uploadZip(BuildContext context) async {
    context = _lasting(context);
    if (!await mayLeave(context)) return;
    if (!context.mounted) return;
    final bytes = await pickZip!();
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
      _kept!.save(name, files, fromFile: true);
    } on StorageFailed {
      if (!context.mounted) return;
      await _tell(context, strings.storageFailed);
      return;
    }
    final project = OpenProject(BrowserLocation(name), files);
    _browserProject = project;
    _show(project);
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
    widget.controller._forget(p.name);
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
