import 'project_file.dart';
import 'yaml_text.dart';

/// Writes [project] as a project file (docs/LANGUAGE.md §11.3), in one
/// layout as form files are (D31): [readProjectFile] reads back the same
/// project.
String writeProjectFile(ProjectFile project) {
  // The oldest version that holds the project, so that older GuBASICs
  // still open it (D51, D102).
  final version = project.modules.isNotEmpty || project.startsWithMain
      ? 3
      : project.pictures.isNotEmpty
          ? 2
          : 1;
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
  if (project.modules.isNotEmpty) {
    out.writeln('modules:');
    for (final m in project.modules) {
      out.writeln('  - ${yamlString(m)}');
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
