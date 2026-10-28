import 'package:gubasic_lang/gubasic_lang.dart';

/// Why a form cannot take a name (D88).
sealed class FormNameRefused {
  const FormNameRefused(this.name);

  final String name;
}

/// Not an ASCII name, a keyword or `Form` ([isUsableName]).
class FormNameNotUsable extends FormNameRefused {
  const FormNameNotUsable(super.name);
}

/// Another form or module of the project has it, in any case.
class FormNameTaken extends FormNameRefused {
  const FormNameTaken(super.name);
}

/// The code uses the name already: it would turn into a use of the form,
/// as a control is renamed only to a name the code does not use (D35).
class FormNameUsedInCode extends FormNameRefused {
  const FormNameUsedInCode(super.name, this.uses);

  /// Where, as `Form1.gbas:3`.
  final List<String> uses;
}

/// The project's forms, as its `.gbproj` file lists them; empty when there
/// is not exactly one, or it has errors.
List<String> projectForms(Map<String, String> files) =>
    _projectFile(files)?.$2.project.forms ?? const [];

/// The form the project starts with, or null; null too when it starts
/// with Sub Main (D102).
String? startupFormOf(Map<String, String> files) =>
    switch (_projectFile(files)?.$2.project) {
      final p? when !p.startsWithMain => p.startupForm,
      _ => null,
    };

/// The project's modules (D102), as its `.gbproj` file lists them.
List<String> projectModules(Map<String, String> files) =>
    _projectFile(files)?.$2.project.modules ?? const [];

/// Whether the project starts with Sub Main of a module (D102).
bool startsWithMainOf(Map<String, String> files) =>
    _projectFile(files)?.$2.project.startsWithMain ?? false;

/// Whether module [name]'s code has a `Sub Main()` (D102).
bool moduleHasMain(Map<String, String> files, String name) {
  final code = files['$name.gbas'] ?? '';
  return parse(code).unit.members.any(
    (m) =>
        m is ProcedureDecl &&
        !m.isFunction &&
        m.parameters.isEmpty &&
        m.name.name.toLowerCase() == 'main',
  );
}

/// The name a new module gets: `Module1`, `Module2`, … the first that no
/// form, module or file of the project has (D102).
String newModuleName(Map<String, String> files) {
  final taken = {
    for (final f in [...projectForms(files), ...projectModules(files)])
      f.toLowerCase(),
    for (final f in files.keys) f.toLowerCase().split('.').first,
  };
  for (var n = 1; ; n++) {
    if (!taken.contains('module$n')) return 'Module$n';
  }
}

/// The name a new form gets: `Form2`, `Form3`, … the first that no form
/// and no file of the project has.
String newFormName(Map<String, String> files) {
  final taken = {
    for (final f in projectForms(files)) f.toLowerCase(),
    for (final f in files.keys) f.toLowerCase().split('.').first,
  };
  for (var n = 2; ; n++) {
    if (!taken.contains('form$n')) return 'Form$n';
  }
}

/// Why form [from] cannot be renamed [to], or a new form be named [to]
/// when [from] is null; null when it can.
FormNameRefused? formNameRefusal(
  Map<String, String> files,
  String to, {
  String? from,
}) {
  if (!isUsableName(to)) return FormNameNotUsable(to);
  final lower = to.toLowerCase();
  if ([...projectForms(files), ...projectModules(files)].any(
    (f) => f.toLowerCase() == lower && f.toLowerCase() != from?.toLowerCase(),
  )) {
    return FormNameTaken(to);
  }
  if (from != null && from.toLowerCase() == lower) return null;
  final uses = formUsesIn(files, to);
  return uses.isEmpty ? null : FormNameUsedInCode(to, uses);
}

/// Where the code of the project's forms and modules uses [name] as a
/// form or a module, as `Form1.gbas:3` ([formUses]), but for [name]'s own
/// code.
List<String> formUsesIn(Map<String, String> files, String name) => [
  for (final form in [...projectForms(files), ...projectModules(files)])
    if (form.toLowerCase() != name.toLowerCase())
      for (final line in formUses(files['$form.gbas'] ?? '', name))
        '$form.gbas:$line',
];

/// [files] with a new form [name]: an empty form of the startup form's
/// size, with [name] as its Caption, empty code, and the `.gbproj` file
/// listing it last. Null when the `.gbproj` file cannot be written.
Map<String, String>? withFormAdded(Map<String, String> files, String name) {
  final project = _projectFile(files);
  if (project == null || project.$2.hasErrors) return null;
  final startup = project.$2.project.startupForm;
  final size = startup == null
      ? null
      : readFormFile(files['$startup.form.yaml'] ?? '', name: startup).form;
  final form = FormFile(
    name: name,
    properties: {
      'Caption': name,
      if (size != null) ...{
        'Width': size.valueOf('Width'),
        'Height': size.valueOf('Height'),
      },
    },
    controls: const [],
  );
  return {
    ...files,
    project.$1: _written(project.$2.project, (p) => [...p.forms, name]),
    '$name.form.yaml': writeFormFile(form),
    '$name.gbas': '',
  };
}

/// [files] with form [from] renamed [to]: its files, the `.gbproj` file's
/// list and startup, and its uses in the code of every form
/// ([renameFormInCode]). [formNameRefusal] must have found no problem.
Map<String, String> withFormRenamed(
  Map<String, String> files,
  String from,
  String to,
) {
  final (file, read) = _projectFile(files)!;
  final lower = from.toLowerCase();
  final p = read.project;
  // In the same order, so that the project list keeps its order.
  final renamed = <String, String>{};
  for (final MapEntry(key: name, value: text) in files.entries) {
    if (name == file) {
      renamed[file] = _written(
        p,
        (p) => [for (final f in p.forms) f.toLowerCase() == lower ? to : f],
        startup: !p.startsWithMain && p.startupForm?.toLowerCase() == lower
            ? to
            : p.startup,
      );
      continue;
    }
    final base = name.split('.').first;
    final ext = name.substring(base.length);
    final own =
        base.toLowerCase() == lower &&
        (ext == '.form.yaml' || ext.toLowerCase() == '.gbas');
    final newName = own ? '$to$ext' : name;
    renamed[newName] = ext.toLowerCase() == '.gbas'
        ? renameFormInCode(text, from, to)
        : text;
  }
  return renamed;
}

/// [files] without form [name]: its files go, and the `.gbproj` file no
/// longer lists it; when it was the startup form, the first form left
/// starts. The project must keep a form.
Map<String, String> withFormDeleted(Map<String, String> files, String name) {
  final (file, read) = _projectFile(files)!;
  final lower = name.toLowerCase();
  final left = [
    for (final f in read.project.forms)
      if (f.toLowerCase() != lower) f,
  ];
  final startup =
      !read.project.startsWithMain &&
          read.project.startupForm?.toLowerCase() == lower
      ? left.first
      : read.project.startup;
  return {
    for (final MapEntry(:key, :value) in files.entries)
      if (key == file)
        file: _written(read.project, (_) => left, startup: startup)
      else if (key.toLowerCase() != '$lower.form.yaml' &&
          key.toLowerCase() != '$lower.gbas')
        key: value,
  };
}

/// [files] with the project starting with form [name].
Map<String, String> withStartupForm(Map<String, String> files, String name) {
  final (file, read) = _projectFile(files)!;
  return {
    ...files,
    file: _written(read.project, (p) => p.forms, startup: name),
  };
}

/// [p] written with the forms [forms] gives and the modules [modules]
/// gives, starting with [startup] (or as it did); its other entries are
/// kept.
String _written(
  ProjectFile p,
  List<String> Function(ProjectFile) forms, {
  String? startup,
  List<String> Function(ProjectFile)? modules,
}) => writeProjectFile(
  ProjectFile(
    name: p.name,
    forms: forms(p),
    startup: startup ?? p.startup,
    pictures: p.pictures,
    id: p.id,
    modules: modules?.call(p) ?? p.modules,
  ),
);

/// [files] with a new module [name] (D102): its code, empty but for a
/// comment, and the `.gbproj` file listing it last. Null when the
/// `.gbproj` file cannot be written.
Map<String, String>? withModuleAdded(
  Map<String, String> files,
  String name, {
  required String comment,
}) {
  final project = _projectFile(files);
  if (project == null || project.$2.hasErrors) return null;
  return {
    ...files,
    project.$1: _written(
      project.$2.project,
      (p) => p.forms,
      modules: (p) => [...p.modules, name],
    ),
    '$name.gbas': "' $comment\n",
  };
}

/// [files] with module [from] renamed [to]: its file, the `.gbproj` file's
/// list, and its uses in the code (`Module1.Total`). [formNameRefusal]
/// must have found no problem.
Map<String, String> withModuleRenamed(
  Map<String, String> files,
  String from,
  String to,
) {
  final (file, read) = _projectFile(files)!;
  final lower = from.toLowerCase();
  return {
    for (final MapEntry(key: name, value: text) in files.entries)
      if (name == file)
        file: _written(
          read.project,
          (p) => p.forms,
          modules: (p) => [
            for (final m in p.modules) m.toLowerCase() == lower ? to : m,
          ],
        )
      else if (name.toLowerCase() == '$lower.gbas')
        '$to.gbas': renameFormInCode(text, from, to)
      else if (name.toLowerCase().endsWith('.gbas'))
        name: renameFormInCode(text, from, to)
      else
        name: text,
  };
}

/// [files] without module [name]: its file goes, and the `.gbproj` file no
/// longer lists it; a project that started with its Sub Main starts with
/// the first form.
Map<String, String> withModuleDeleted(Map<String, String> files, String name) {
  final (file, read) = _projectFile(files)!;
  final lower = name.toLowerCase();
  final p = read.project;
  final startup = p.startsWithMain && moduleHasMain(files, name)
      ? p.forms.first
      : p.startup;
  return {
    for (final MapEntry(:key, :value) in files.entries)
      if (key == file)
        file: _written(
          p,
          (p) => p.forms,
          startup: startup,
          modules: (p) => [
            for (final m in p.modules)
              if (m.toLowerCase() != lower) m,
          ],
        )
      else if (key.toLowerCase() != '$lower.gbas')
        key: value,
  };
}

/// [files] with the project starting with Sub Main of a module (D102).
Map<String, String> withStartupMain(Map<String, String> files) {
  final (file, read) = _projectFile(files)!;
  return {
    ...files,
    file: _written(read.project, (p) => p.forms, startup: startupSubMain),
  };
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
