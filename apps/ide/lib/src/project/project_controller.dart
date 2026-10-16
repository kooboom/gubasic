import 'package:flutter/material.dart';

import '../strings.dart';
import 'folders.dart';
import 'open_project.dart';

/// Asks the user for a folder; null when they cancel. [confirm] is the
/// word on the dialog's button.
typedef PickFolder = Future<String?> Function(String confirm);

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
    this.pickFolder,
    String open = 'hello',
  }) : _current = OpenProject(ExampleLocation(open), examples[open]!);

  /// The built-in projects: name → file name → text.
  final Map<String, Map<String, String>> examples;
  final IdeStrings strings;

  /// The disk, or null where projects cannot be opened or saved (the web,
  /// for now).
  final ProjectFolders? folders;
  final PickFolder? pickFolder;

  OpenProject _current;
  OpenProject? _folderProject;

  /// The open project.
  OpenProject get current => _current;

  /// Whether the File menu is offered.
  bool get canUseFolders => folders != null && pickFolder != null;

  /// The project menu's entries, a key and the words shown: the examples
  /// by name, then the folder project last opened or saved, if any.
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

  /// Asks for a project folder and opens it.
  Future<void> open(BuildContext context) async {
    if (!await mayLeave(context)) return;
    if (!context.mounted) return;
    final folder = await pickFolder!(strings.openFolderButton);
    if (folder == null || !context.mounted) return;
    try {
      final read = await readProjectFolder(folders!, folder);
      final project = OpenProject(FolderLocation(folder), read.files);
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
    if (!project.isDirty) return true;
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
      if (context.mounted) _snack(context, location.path);
      return true;
    } on FolderProblem catch (p) {
      if (context.mounted) await _tell(context, _describe(p));
      return false;
    }
  }

  /// Saves the open project as a new project in a new folder, then keeps
  /// working there. Gives whether it was saved.
  Future<bool> saveAs(BuildContext context) async {
    final project = _current;
    if (project.isExample) {
      final go = await _confirm(
        context,
        strings.exampleIsReadOnly,
        strings.chooseFolderButton,
      );
      if (!go) return false;
    }
    if (!context.mounted) return false;
    final parent = await pickFolder!(strings.chooseFolderButton);
    if (parent == null || !context.mounted) return false;
    var name = project.project.name;
    while (true) {
      if (!context.mounted) return false;
      final chosen = await _askName(context, parent, name);
      if (chosen == null) return false;
      name = chosen;
      try {
        final (folder, files) = await saveCopy(
          folders!,
          parent,
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
        if (context.mounted) _snack(context, folder);
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
    NoProjectFile() => strings.noProjectFile,
    ManyProjectFiles(:final files) => strings.manyProjectFiles.replaceAll(
      '{0}',
      files.join(', '),
    ),
    FileFailed(:final file, :final reason, :final writing) =>
      (writing ? strings.cannotWrite : strings.cannotRead)
          .replaceAll('{0}', file)
          .replaceAll('{1}', reason ?? strings.notText),
    FolderExists(:final name) => strings.folderExists.replaceAll('{0}', name),
  };

  void _snack(BuildContext context, String folder) =>
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(strings.saved.replaceAll('{0}', folder))),
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

  Future<String?> _askName(
    BuildContext context,
    String parent,
    String initial,
  ) => showDialog<String>(
    context: context,
    builder: (context) =>
        _NameDialog(strings: strings, parent: parent, initial: initial),
  );
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.strings,
    required this.parent,
    required this.initial,
  });

  final IdeStrings strings;
  final String parent;
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
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
            const SizedBox(height: 12),
            Text(s.saveAsHint.replaceAll('{0}', widget.parent)),
          ],
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
