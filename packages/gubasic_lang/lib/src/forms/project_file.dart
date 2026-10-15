import 'package:yaml/yaml.dart';

import '../diagnostics/diagnostic.dart';
import 'yaml_reader.dart';

/// The newest project file layout this GuBASIC reads
/// (docs/LANGUAGE.md §11.3).
const projectFileVersion = 1;

/// A project (`App.gbproj`): its name, its forms and the one it starts
/// with. Form `F` lives in `F.form.yaml` and `F.gbas` next to it.
class ProjectFile {
  ProjectFile({required this.name, required this.forms, this.startup});

  final String name;
  final List<String> forms;

  /// The startup form as written, or null for the first form.
  final String? startup;

  /// The form the program starts with, or null if there are no forms.
  String? get startupForm {
    if (startup != null) {
      for (final f in forms) {
        if (f.toLowerCase() == startup!.toLowerCase()) return f;
      }
      return null;
    }
    return forms.isEmpty ? null : forms.first;
  }
}

class ProjectFileResult {
  ProjectFileResult(this.project, this.diagnostics);

  final ProjectFile project;
  final List<Diagnostic> diagnostics;

  bool get hasErrors => diagnostics.any((d) => d.isError);
}

/// Reads a project file. Never throws: problems are F diagnostics.
ProjectFileResult readProjectFile(String text) {
  final r = YamlReader();
  final forms = <String>[];
  var name = '';
  String? startup;
  ProjectFileResult result() => ProjectFileResult(
      ProjectFile(name: name, forms: forms, startup: startup), r.diagnostics);

  final doc = r.load(text);
  if (doc == null) return result();
  final top = r.entries(doc, {'formatversion', 'name', 'startup', 'forms'});
  if (!r.checkVersion(doc, top, projectFileVersion)) return result();

  if (top['name'] != null) {
    name = r.text(top['name']!, 'name', 'name: Hello') ?? '';
  }

  final seen = <String>{};
  final list =
      top['forms'] == null ? null : r.list(top['forms']!, 'forms', '- Form1');
  if (list == null && top['forms'] == null) {
    r.report(doc.span, DiagnosticCode.wrongValueForm, ['forms', '- Form1']);
  }
  for (final node in list?.nodes ?? const <YamlNode>[]) {
    final form = r.name(node);
    if (form == null) continue;
    if (!seen.add(form.toLowerCase())) {
      r.report(node.span, DiagnosticCode.duplicateControlName,
          [form, '${_lineOf(list!, form)}']);
      continue;
    }
    forms.add(form);
  }
  if (list != null && list.nodes.isEmpty) {
    r.report(top['forms']!.span, DiagnosticCode.wrongValueForm,
        ['forms', '- Form1']);
  }

  final startupNode = top['startup'];
  if (startupNode != null) {
    startup = r.name(startupNode);
    if (startup != null && !seen.contains(startup.toLowerCase())) {
      r.report(startupNode.span, DiagnosticCode.unknownStartupForm, [startup]);
    }
  }
  return result();
}

int _lineOf(YamlList list, String form) =>
    list.nodes
        .firstWhere((n) => '${n.value}'.toLowerCase() == form.toLowerCase())
        .span
        .start
        .line +
    1;
