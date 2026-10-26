import 'project_file.dart';
import 'yaml_text.dart';

/// Writes [project] as a project file (docs/LANGUAGE.md §11.3), in one
/// layout as form files are (D31): [readProjectFile] reads back the same
/// project.
String writeProjectFile(ProjectFile project) {
  // Version 1 while there are no pictures, so that older GuBASICs still
  // open the project (D51).
  final version = project.pictures.isEmpty ? 1 : projectFileVersion;
  final out = StringBuffer('formatVersion: $version\n');
  if (project.id case final id?) out.writeln('id: $id');
  out.writeln('name: ${yamlString(project.name)}');
  if (project.startup case final startup?) {
    out.writeln('startup: ${yamlString(startup)}');
  }
  if (project.forms.isEmpty) {
    out.writeln('forms: []');
  } else {
    out.writeln('forms:');
    for (final f in project.forms) {
      out.writeln('  - ${yamlString(f)}');
    }
  }
  if (project.pictures.isNotEmpty) {
    out.writeln('pictures:');
    for (final p in project.pictures) {
      out.writeln('  - ${yamlString(p)}');
    }
  }
  return '$out';
}
