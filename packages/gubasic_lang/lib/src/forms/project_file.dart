import 'dart:math';

import 'package:yaml/yaml.dart';

import '../diagnostics/diagnostic.dart';
import 'pictures.dart';
import 'yaml_reader.dart';

/// The newest project file layout this GuBASIC reads
/// (docs/LANGUAGE.md §11.3). Version 2 added `pictures`, version 3
/// `modules` and `startup: Sub Main` (D102). A project is written in the
/// oldest version that holds it, so that older GuBASICs open it, and
/// refuse (F003) one whose pictures or modules they would drop when
/// saving (D51).
const projectFileVersion = 3;

/// The `startup` of a project that starts with `Sub Main` of a module
/// (D102).
const startupSubMain = 'Sub Main';

/// A project (`App.gbproj`): its name, its forms and the one it starts
/// with, and its pictures. Form `F` lives in `F.form.yaml` and `F.gbas`
/// next to it; picture `P` in `pictures/P`.
class ProjectFile {
  ProjectFile({
    required this.name,
    required this.forms,
    this.startup,
    this.pictures = const [],
    this.id,
    this.modules = const [],
  });

  final String name;

  /// The app ID (docs/DESIGN.md D83): made the first time the project is
  /// exported as an app and kept, so that the app exported again is the
  /// same app (its settings stay); a copy of the project gets a new one.
  /// Null until the first export.
  final String? id;
  final List<String> forms;

  /// The modules (D102): module `M` lives in `M.gbas`.
  final List<String> modules;

  /// The pictures' file names, as written, with Hangul as syllables.
  final List<String> pictures;

  /// The startup form as written, [startupSubMain], or null for the first
  /// form.
  final String? startup;

  /// Whether the program starts with `Sub Main` of a module (D102).
  bool get startsWithMain => startup == startupSubMain;

  /// The form the program starts with, or null if there are no forms. A
  /// program that starts with Sub Main has its first form here, which it
  /// does not show by itself.
  String? get startupForm {
    if (startup != null && !startsWithMain) {
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
  final modules = <String>[];
  final pictures = <String>[];
  var name = '';
  String? startup;
  String? id;
  ProjectFileResult result() => ProjectFileResult(
      ProjectFile(
          name: name,
          forms: forms,
          startup: startup,
          pictures: pictures,
          id: id,
          modules: modules),
      r.diagnostics);

  final doc = r.load(text);
  if (doc == null) return result();
  final top = r.entries(doc, {
    'formatversion',
    'id',
    'name',
    'startup',
    'forms',
    'modules',
    'pictures',
  });
  if (!r.checkVersion(doc, top, projectFileVersion)) return result();

  if (top['name'] != null) {
    name = r.text(top['name']!, 'name', 'name: Hello') ?? '';
  }
  if (top['id'] case final node?) {
    final value =
        node is YamlScalar && node.value != null ? '${node.value}' : '';
    if (isProjectId(value)) {
      id = value;
    } else {
      r.report(node.span, DiagnosticCode.badProjectId, [value]);
    }
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

  // Modules (D102): a name no form or other module has.
  final moduleList = top['modules'] == null
      ? null
      : r.list(top['modules']!, 'modules', '- Module1');
  for (final node in moduleList?.nodes ?? const <YamlNode>[]) {
    final module = r.name(node);
    if (module == null) continue;
    if (!seen.add(module.toLowerCase())) {
      r.report(node.span, DiagnosticCode.duplicateControlName,
          [module, '${node.span.start.line + 1}']);
      continue;
    }
    modules.add(module);
  }

  final pictureList = top['pictures'] == null
      ? null
      : r.list(top['pictures']!, 'pictures', '- triangle.png');
  final pictureLines = <String, (String, int)>{};
  for (final node in pictureList?.nodes ?? const <YamlNode>[]) {
    final value = node.value;
    final picture =
        composeHangul(node is YamlScalar && value != null ? '$value' : '');
    if (pictureNameProblem(picture) != null) {
      r.report(node.span, DiagnosticCode.invalidPictureName, [picture]);
      continue;
    }
    final line = node.span.start.line + 1;
    final first = pictureLines[pictureKey(picture)];
    if (first != null) {
      r.report(node.span, DiagnosticCode.duplicatePicture,
          [picture, first.$1, '${first.$2}']);
      continue;
    }
    pictureLines[pictureKey(picture)] = (picture, line);
    pictures.add(picture);
  }

  final startupNode = top['startup'];
  if (startupNode != null) {
    final written = startupNode is YamlScalar ? '${startupNode.value}' : '';
    if (written.toLowerCase() == startupSubMain.toLowerCase()) {
      startup = startupSubMain;
    } else {
      startup = r.name(startupNode);
      if (startup != null &&
          (!seen.contains(startup.toLowerCase()) ||
              modules.any((m) => m.toLowerCase() == startup!.toLowerCase()))) {
        r.report(
            startupNode.span, DiagnosticCode.unknownStartupForm, [startup]);
      }
    }
  }
  return result();
}

/// Whether [value] is an app ID: 8 to 32 lowercase letters and digits.
bool isProjectId(String value) => RegExp(r'^[a-z0-9]{8,32}$').hasMatch(value);

/// A new app ID: 16 random lowercase letters and digits.
String newProjectId([Random? random]) {
  final r = random ?? Random.secure();
  const digits = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return String.fromCharCodes(
      List.generate(16, (_) => digits.codeUnitAt(r.nextInt(digits.length))));
}

int _lineOf(YamlList list, String form) =>
    list.nodes
        .firstWhere((n) => '${n.value}'.toLowerCase() == form.toLowerCase())
        .span
        .start
        .line +
    1;
