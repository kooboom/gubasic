import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';

import 'project_pictures.dart' show samePictures;

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

  /// The bytes of the file at [path], or null when there is none.
  Future<Uint8List?> readBytes(String path);

  /// Writes [bytes] to [path], as [write] does.
  Future<void> writeBytes(String path, Uint8List bytes);

  /// Deletes the file at [path], if it is there.
  Future<void> delete(String path);

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
  const ProjectOnDisk(this.files, this.missing, {this.pictures = const {}});

  final Map<String, String> files;

  /// Picture name → bytes (D51).
  final Map<String, Uint8List> pictures;
  final List<String> missing;
}

/// The path of picture [name] of the project in [folder].
String picturePath(ProjectFolders fs, String folder, String name) =>
    fs.join(fs.join(folder, picturesFolder), name);

/// Reads the project whose `.gbproj` file is [projectFile]: that file
/// and, for each form it lists, `FORM.form.yaml` and `FORM.gbas` next to
/// it, and the pictures it lists from `pictures/` (D51). Other files in
/// the folder are left alone. Throws a [FolderProblem].
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
  final project = readProjectFile(files[projectName]!).project;
  for (final form in project.forms) {
    await add('$form.form.yaml');
    await add('$form.gbas');
  }
  // Its modules (D102).
  for (final module in project.modules) {
    await add('$module.gbas');
  }
  final pictures = <String, Uint8List>{};
  for (final name in project.pictures) {
    final file = '$picturesFolder/$name';
    final bytes = await _io(
      file,
      writing: false,
      () => fs.readBytes(picturePath(fs, folder, name)),
    );
    if (bytes == null) {
      missing.add(file);
    } else {
      pictures[name] = bytes;
    }
  }
  return ProjectOnDisk(files, missing, pictures: pictures);
}

/// The files of [files] whose text on disk is no longer what was read or
/// last saved ([saved]): changed by another program since. The same for
/// the [pictures] that would be written or deleted ([savedPictures]).
Future<List<String>> changedOnDisk(
  ProjectFolders fs,
  String folder,
  Map<String, String> files,
  Map<String, String> saved, {
  Map<String, Uint8List> pictures = const {},
  Map<String, Uint8List> savedPictures = const {},
}) async {
  final changed = <String>[];
  // A form's files taken out of the project are deleted (D88).
  for (final name in {...files.keys, ..._formFilesGone(files, saved)}) {
    if (files[name] == saved[name]) continue;
    final onDisk = await _io(
      name,
      writing: false,
      () => fs.read(fs.join(folder, name)),
    );
    if (onDisk != saved[name]) changed.add(name);
  }
  for (final name in {...pictures.keys, ...savedPictures.keys}) {
    final now = pictures[name], before = savedPictures[name];
    if (_samePicture(now, before)) continue;
    final file = '$picturesFolder/$name';
    final onDisk = await _io(
      file,
      writing: false,
      () => fs.readBytes(picturePath(fs, folder, name)),
    );
    if (!_samePicture(onDisk, before)) changed.add(file);
  }
  return changed;
}

/// Writes the files of [files] that differ from [saved] into [folder],
/// and the [pictures] that differ from [savedPictures] into its
/// `pictures/`. The pictures come first and those taken out of the
/// project are deleted last, so that the `.gbproj` file never lists a
/// picture that is not on disk, whichever write fails.
Future<void> writeChanged(
  ProjectFolders fs,
  String folder,
  Map<String, String> files,
  Map<String, String> saved, {
  Map<String, Uint8List> pictures = const {},
  Map<String, Uint8List> savedPictures = const {},
}) async {
  final written = [
    for (final MapEntry(:key, :value) in pictures.entries)
      if (!_samePicture(value, savedPictures[key])) key,
  ];
  if (written.isNotEmpty) {
    final dir = fs.join(folder, picturesFolder);
    await _io(picturesFolder, writing: true, () async {
      if (!await fs.exists(dir)) await fs.createFolder(dir);
    });
  }
  for (final name in written) {
    await _io(
      '$picturesFolder/$name',
      writing: true,
      () => fs.writeBytes(picturePath(fs, folder, name), pictures[name]!),
    );
  }
  for (final MapEntry(key: name, value: text) in files.entries) {
    if (saved[name] == text) continue;
    await _io(name, writing: true, () => fs.write(fs.join(folder, name), text));
  }
  // Only the forms' files the project had: the IDE put them there (D88).
  for (final name in _formFilesGone(files, saved)) {
    await _io(name, writing: true, () => fs.delete(fs.join(folder, name)));
  }
  // Only pictures the project had: the IDE put them there.
  for (final name in savedPictures.keys) {
    if (pictures.containsKey(name)) continue;
    await _io(
      '$picturesFolder/$name',
      writing: true,
      () => fs.delete(picturePath(fs, folder, name)),
    );
  }
}

/// The forms' files that [saved] has and [files] no longer has, in any
/// case: a form deleted or renamed (D88). A file renamed only in case is
/// not one: on a disk that ignores case, deleting the old name would
/// delete the new file.
Iterable<String> _formFilesGone(
  Map<String, String> files,
  Map<String, String> saved,
) {
  final kept = {for (final f in files.keys) f.toLowerCase()};
  return saved.keys.where(
    (name) =>
        !kept.contains(name.toLowerCase()) &&
        (name.endsWith('.form.yaml') || name.toLowerCase().endsWith('.gbas')),
  );
}

/// Writes [bytes] to the file at [path], such as an exported app (D84).
Future<void> writeFileBytes(ProjectFolders fs, String path, Uint8List bytes) =>
    _io(path, writing: true, () => fs.writeBytes(path, bytes));

bool _samePicture(Uint8List? a, Uint8List? b) =>
    a == null || b == null ? a == b : samePictures({'': a}, {'': b});

/// Saves a copy of [files] as project [name] in a new folder [name] inside
/// [parent]. The `.gbproj` file is renamed `NAME.gbproj` and, when it
/// reads without errors, its `name:` becomes [name]. Gives the new folder
/// and the files written.
Future<(String, Map<String, String>)> saveCopy(
  ProjectFolders fs,
  String parent,
  String name,
  Map<String, String> files, {
  Map<String, Uint8List> pictures = const {},
}) async {
  final folder = fs.join(parent, name);
  if (await _io(name, writing: true, () => fs.exists(folder))) {
    throw FolderExists(name);
  }
  final copy = renameProject(files, name);
  await _io(name, writing: true, () => fs.createFolder(folder));
  await writeChanged(fs, folder, copy, const {}, pictures: pictures);
  return (folder, copy);
}

/// [files] as project [name]: the `.gbproj` file is renamed `NAME.gbproj`
/// and, when it reads without errors, its `name:` becomes [name]. A copy
/// is another app, so an app ID it had is replaced by a new one (D83).
Map<String, String> renameProject(Map<String, String> files, String name) {
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
              pictures: read.project.pictures,
              id: read.project.id == null ? null : newProjectId(),
              modules: read.project.modules,
            ),
          );
  }
  return copy;
}

/// Characters a project's name cannot have: those a folder name cannot
/// have on macOS or Windows, and the dot, because macOS may show a
/// folder named like `MyQuiz.band` as a document of another program.
final _badNameCharacters = RegExp(r'[./\\:*?"<>|\x00-\x1f]');

/// Whether [name] can be a project's name, and so its folder's.
bool isUsableProjectName(String name) =>
    name.trim() == name &&
    name.isNotEmpty &&
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
