import 'package:flutter/material.dart';

import '../strings.dart';
import 'folders.dart';
import 'open_project.dart';

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

/// Opens and saves projects (D32): the built-in examples and project
/// folders on disk. The commands ask the user through dialogs shown in
/// the given context.
class ProjectController extends ChangeNotifier {
  ProjectController({
    required this.examples,
    required this.strings,
    this.folders,
    this.pickers,
    String open = 'hello',
  }) : _current = OpenProject(ExampleLocation(open), examples[open]!);

  /// The built-in projects: name → file name → text.
  final Map<String, Map<String, String>> examples;
  final IdeStrings strings;

  /// The disk, or null where projects cannot be opened or saved (the web,
  /// for now).
  final ProjectFolders? folders;
  final ProjectPickers? pickers;

  OpenProject _current;
  OpenProject? _folderProject;

  /// The open project.
  OpenProject get current => _current;

  /// Whether the File menu is offered.
  bool get canUseFolders => folders != null && pickers != null;

  /// The project menu's entries, a key and the words shown: the examples
  /// by name, then the project on disk last opened or saved, if any.
  List<(String, String)> get menuEntries => [
    for (final name in examples.keys) ('example:$name', name),
    if (_folderProject case final p?) ('folder', p.project.name),
  ];

  /// The menu key of the open project.
  String get currentKey => switch (_current.location) {
    ExampleLocation(:final name) => 'example:$name',
    FolderLocation() => 'folder',
  };

  /// Opens the menu entry [key], after asking about unsaved changes.
  Future<void> choose(BuildContext context, String key) async {
    if (key == currentKey) return;
    if (!await mayLeave(context)) return;
    if (key == 'folder') {
      _show(_folderProject!);
    } else {
      final name = key.substring('example:'.length);
      _show(OpenProject(ExampleLocation(name), examples[name]!));
    }
  }

  /// Asks for a `.gbproj` file and opens its project.
  Future<void> open(BuildContext context) async {
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
    final project = _current;
    final location = project.location;
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
    final project = _current;
    if (project.isExample) {
      final go = await _confirm(
        context,
        strings.exampleIsReadOnly,
        strings.saveCopyButton,
      );
      if (!go) return false;
    }
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
    if (!_current.isDirty) return true;
    final answer = await showDialog<_Unsaved>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Text(strings.unsaved.replaceAll('{0}', _current.project.name)),
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

  void _show(OpenProject project) {
    _current = project;
    notifyListeners();
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
      content: Text(message),
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
          content: Text(message),
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
