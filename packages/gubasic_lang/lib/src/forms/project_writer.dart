import 'project_file.dart';
import 'yaml_text.dart';

/// Writes [project] as a project file (docs/LANGUAGE.md §11.3), in one
/// layout as form files are (D31): [readProjectFile] reads back the same
/// project.
String writeProjectFile(ProjectFile project) {
  final out = StringBuffer('formatVersion: $projectFileVersion\n')
    ..writeln('name: ${yamlString(project.name)}');
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
  return '$out';
}
