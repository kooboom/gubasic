import 'package:gubasic_lang/gubasic_lang.dart';

/// The few file operations the IDE needs (D32). The app uses the disk
/// (`folders_io.dart`); tests use memory, so the same logic is tested
/// without touching the disk.
abstract interface class ProjectFolders {
  /// The names of the files directly in [folder] (not its subfolders).
  Future<List<String>> list(String folder);

  /// The text of the file at [path], or null when there is none.
  Future<String?> read(String path);

  /// Writes [text] to [path] so that the file is always either the old
  /// one or the new one, never half written.
  Future<void> write(String path, String text);

  Future<bool> exists(String path);
  Future<void> createFolder(String path);
  String join(String folder, String name);

  /// The folder [path] is in.
  String parent(String path);

  /// The last part of [path]: a file's or a folder's name.
  String name(String path);
}

/// A file operation that failed: [path] and the system's reason.
class FolderIoException implements Exception {
  const FolderIoException(this.path, this.reason);

  /// The file is not text in UTF-8.
  const FolderIoException.notText(this.path) : reason = null;

  final String path;

  /// The system's words, or null when the file is not UTF-8 text.
  final String? reason;

  @override
  String toString() => '$path: $reason';
}

/// Why a folder cannot be opened, or a project not saved.
sealed class FolderProblem implements Exception {
  const FolderProblem();
}

/// The `.gbproj` file is gone (deleted after it was chosen).
class MissingProjectFile extends FolderProblem {
  const MissingProjectFile(this.file);

  final String file;
}

/// A file could not be read or written.
class FileFailed extends FolderProblem {
  const FileFailed(this.file, this.reason, {required this.writing});

  final String file;

  /// The system's words, or null when the file is not UTF-8 text.
  final String? reason;
  final bool writing;
}

/// Save As would write into a folder that is already there.
class FolderExists extends FolderProblem {
  const FolderExists(this.name);

  final String name;
}

/// A project read from disk. [missing] lists the files its `.gbproj`
/// names that are not there.
class ProjectOnDisk {
  const ProjectOnDisk(this.files, this.missing);

  final Map<String, String> files;
  final List<String> missing;
}

/// Reads the project whose `.gbproj` file is [projectFile]: that file
/// and, for each form it lists, `FORM.form.yaml` and `FORM.gbas` next to
/// it. Other files in the folder are left alone. Throws a [FolderProblem].
Future<ProjectOnDisk> readProject(ProjectFolders fs, String projectFile) async {
  final folder = fs.parent(projectFile);
  final files = <String, String>{};
  final missing = <String>[];
  Future<void> add(String name) async {
    final text = await _io(
      name,
      writing: false,
      () => fs.read(fs.join(folder, name)),
    );
    if (text == null) {
      missing.add(name);
    } else {
      files[name] = text;
    }
  }

  final projectName = fs.name(projectFile);
  await add(projectName);
  if (missing.isNotEmpty) throw MissingProjectFile(projectName);
  for (final form in readProjectFile(files[projectName]!).project.forms) {
    await add('$form.form.yaml');
    await add('$form.gbas');
  }
  return ProjectOnDisk(files, missing);
}

/// The files of [files] whose text on disk is no longer what was read or
/// last saved ([saved]): changed by another program since.
Future<List<String>> changedOnDisk(
  ProjectFolders fs,
  String folder,
  Map<String, String> files,
  Map<String, String> saved,
) async {
  final changed = <String>[];
  for (final name in files.keys) {
    if (files[name] == saved[name]) continue;
    final onDisk = await _io(
      name,
      writing: false,
      () => fs.read(fs.join(folder, name)),
    );
    if (onDisk != saved[name]) changed.add(name);
  }
  return changed;
}

/// Writes the files of [files] that differ from [saved] into [folder].
Future<void> writeChanged(
  ProjectFolders fs,
  String folder,
  Map<String, String> files,
  Map<String, String> saved,
) async {
  for (final MapEntry(key: name, value: text) in files.entries) {
    if (saved[name] == text) continue;
    await _io(name, writing: true, () => fs.write(fs.join(folder, name), text));
  }
}

/// Saves a copy of [files] as project [name] in a new folder [name] inside
/// [parent]. The `.gbproj` file is renamed `NAME.gbproj` and, when it
/// reads without errors, its `name:` becomes [name]. Gives the new folder
/// and the files written.
Future<(String, Map<String, String>)> saveCopy(
  ProjectFolders fs,
  String parent,
  String name,
  Map<String, String> files,
) async {
  final folder = fs.join(parent, name);
  if (await _io(name, writing: true, () => fs.exists(folder))) {
    throw FolderExists(name);
  }
  final copy = <String, String>{};
  for (final MapEntry(key: file, value: text) in files.entries) {
    if (!file.toLowerCase().endsWith('.gbproj')) {
      copy[file] = text;
      continue;
    }
    final read = readProjectFile(text);
    copy['$name.gbproj'] = read.hasErrors
        ? text
        : writeProjectFile(
            ProjectFile(
              name: name,
              forms: read.project.forms,
              startup: read.project.startup,
            ),
          );
  }
  await _io(name, writing: true, () => fs.createFolder(folder));
  await writeChanged(fs, folder, copy, const {});
  return (folder, copy);
}

/// Characters a folder name cannot have on macOS or Windows.
final _badNameCharacters = RegExp(r'[/\\:*?"<>|\x00-\x1f]');

/// Whether [name] can be a project's name, and so its folder's.
bool isUsableProjectName(String name) =>
    name.trim() == name &&
    name.isNotEmpty &&
    !name.startsWith('.') &&
    !name.endsWith('.') &&
    !_badNameCharacters.hasMatch(name);

Future<T> _io<T>(
  String file,
  Future<T> Function() action, {
  required bool writing,
}) async {
  try {
    return await action();
  } on FolderIoException catch (e) {
    throw FileFailed(file.isEmpty ? e.path : file, e.reason, writing: writing);
  }
}
