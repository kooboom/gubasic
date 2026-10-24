import 'dart:typed_data';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart' show GbPictureSource;

/// Why a picture cannot be added to a project (D51).
sealed class PictureRefused {
  const PictureRefused();
}

/// The `.gbproj` file has errors, so its list of pictures cannot be
/// written.
class ProjectFileHasErrors extends PictureRefused {
  const ProjectFileHasErrors();
}

/// A name a picture cannot have (F014).
class BadPictureName extends PictureRefused {
  const BadPictureName(this.name, this.problem);

  final String name;
  final PictureNameProblem problem;
}

/// Not a PNG, JPEG or GIF picture, whatever its name says.
class NotAPicture extends PictureRefused {
  const NotAPicture(this.name, this.format);

  final String name;

  /// [PictureFormat.heic] or [PictureFormat.unknown].
  final PictureFormat format;
}

/// Larger than [maxPictureBytes].
class PictureTooLarge extends PictureRefused {
  const PictureTooLarge(this.name, this.bytes);

  final String name;
  final int bytes;
}

/// Wider or taller than [maxPictureSide] pixels.
class PictureTooWide extends PictureRefused {
  const PictureTooWide(this.name, this.width, this.height);

  final String name;
  final int width;
  final int height;
}

/// The project's pictures would take more than [maxProjectPictureBytes].
class ProjectPicturesFull extends PictureRefused {
  const ProjectPicturesFull(this.name);

  final String name;
}

/// The name of [pictures] that is [name] as names in code are compared
/// (`pictureKey`), or null.
String? pictureNamed(Iterable<String> pictures, String name) {
  final key = pictureKey(name);
  for (final p in pictures) {
    if (pictureKey(p) == key) return p;
  }
  return null;
}

/// [pictures] for the runtime to draw, found by name in any case.
GbPictureSource pictureSource(Map<String, Uint8List> pictures) {
  final byKey = {
    for (final MapEntry(:key, :value) in pictures.entries)
      pictureKey(key): value,
  };
  return (name) => byKey[pictureKey(name)];
}

/// Why picture [name] with [bytes] cannot be added to a project with
/// [files] and [pictures], or null when it can. A picture of the same name
/// is replaced, so its bytes do not count.
PictureRefused? checkPicture(
  String name,
  Uint8List bytes,
  Map<String, String> files,
  Map<String, Uint8List> pictures,
) {
  final project = _projectFile(files);
  if (project == null || project.$2.hasErrors) {
    return const ProjectFileHasErrors();
  }
  if (pictureNameProblem(name) case final problem?) {
    return BadPictureName(name, problem);
  }
  final format = pictureFormat(bytes);
  if (format == PictureFormat.heic || format == PictureFormat.unknown) {
    return NotAPicture(name, format);
  }
  if (bytes.length > maxPictureBytes) {
    return PictureTooLarge(name, bytes.length);
  }
  if (pictureSize(bytes) case (final w, final h)
      when w > maxPictureSide || h > maxPictureSide) {
    return PictureTooWide(name, w, h);
  }
  final replaced = pictureNamed(pictures.keys, name);
  var total = bytes.length;
  for (final MapEntry(:key, :value) in pictures.entries) {
    if (key != replaced) total += value.length;
  }
  if (total > maxProjectPictureBytes) return ProjectPicturesFull(name);
  return null;
}

/// [files] with the `.gbproj` file listing [pictures]; its other entries
/// are kept. The `.gbproj` file must read without errors.
Map<String, String> withPictureList(
  Map<String, String> files,
  List<String> pictures,
) {
  final (file, read) = _projectFile(files)!;
  final p = read.project;
  return {
    ...files,
    file: writeProjectFile(
      ProjectFile(
        name: p.name,
        forms: p.forms,
        startup: p.startup,
        pictures: pictures,
      ),
    ),
  };
}

/// The controls of the project's forms that show picture [name]: each as
/// `Form1.imgShape`.
List<String> pictureUsers(Map<String, String> files, String name) {
  final project = _projectFile(files);
  if (project == null) return const [];
  final key = pictureKey(name);
  return [
    for (final form in project.$2.project.forms)
      for (final c in readFormFile(
        files['$form.form.yaml'] ?? '',
        name: form,
      ).form.controls)
        if (c.component.properties.values.any(
          (p) => p.picture && pictureKey('${c.valueOf(p.name)}') == key,
        ))
          '$form.${c.name}',
  ];
}

/// The `.gbproj` file of [files] and what it reads as, or null when there
/// is not exactly one.
(String, ProjectFileResult)? _projectFile(Map<String, String> files) {
  final names = [
    for (final f in files.keys)
      if (f.toLowerCase().endsWith('.gbproj')) f,
  ];
  if (names.length != 1) return null;
  return (names.single, readProjectFile(files[names.single]!));
}

/// Whether [a] and [b] have the same pictures, byte for byte.
bool samePictures(Map<String, Uint8List> a, Map<String, Uint8List> b) =>
    a.length == b.length &&
    a.entries.every((e) => _sameBytes(e.value, b[e.key]));

bool _sameBytes(Uint8List a, Uint8List? b) {
  if (identical(a, b)) return true;
  if (b == null || a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
