import 'package:gubasic_lang/gubasic_lang.dart';

/// A problem found in one of a project's files.
class FileDiagnostic {
  const FileDiagnostic(this.file, this.diagnostic);

  final String file;
  final Diagnostic diagnostic;
}

/// A project read from its files: `NAME.gbproj`, for each form
/// `FORM.form.yaml` and `FORM.gbas` next to it, and for each module
/// `MODULE.gbas` (docs/LANGUAGE.md §11.3).
/// Reading never throws: problems are in [diagnostics].
class Project {
  Project._(this.name, this.files, this._compile);

  /// Reads the project from [files] (file name → text). Its name is read
  /// at once; the forms and the code are read and compiled the first time
  /// [diagnostics] or [startup] is asked for, so that showing the project
  /// as it is typed in does not compile it at every key (D36).
  factory Project.read(Map<String, String> files) {
    final projectFiles = files.keys.where((f) => f.endsWith('.gbproj'));
    if (projectFiles.length != 1) {
      return Project._('', files, () => (const <FileDiagnostic>[], null));
    }
    final projectName = projectFiles.single;
    final read = readProjectFile(files[projectName]!);
    return Project._(read.project.name, files, () {
      final diagnostics = <FileDiagnostic>[
        for (final d in read.diagnostics) FileDiagnostic(projectName, d),
      ];
      StartupForm? startup;
      if (!read.hasErrors && read.project.startupForm != null) {
        // Every form, each knowing the others (D88).
        final pictures = read.project.pictures;
        final sources = <FormSource>[];
        var readable = true;
        for (final name in read.project.forms) {
          final formFile = '$name.form.yaml';
          final form = readFormFile(
            files[formFile] ?? '',
            name: name,
            pictures: pictures,
          );
          diagnostics.addAll([
            for (final d in form.diagnostics) FileDiagnostic(formFile, d),
          ]);
          readable &= !form.hasErrors && files.containsKey(formFile);
          sources.add((file: form.form, source: files['$name.gbas'] ?? ''));
        }
        // Its modules (D102): MODULE.gbas each.
        final modules = <ModuleSource>[
          for (final name in read.project.modules)
            (name: name, source: files['$name.gbas'] ?? ''),
        ];
        for (final name in read.project.modules) {
          if (!files.containsKey('$name.gbas')) readable = false;
        }
        final compiled = compileProject(
          sources,
          startup: read.project.startupForm,
          pictures: pictures,
          modules: modules,
          startsWithMain: read.project.startsWithMain,
        );
        for (final f in compiled.forms) {
          diagnostics.addAll([
            for (final d in f.program.diagnostics)
              FileDiagnostic(f.codeFile, d),
          ]);
        }
        for (final m in compiled.modules) {
          diagnostics.addAll([
            for (final d in m.program.diagnostics)
              FileDiagnostic(m.codeFile, d),
          ]);
        }
        if (compiled.startsWithMain && compiled.main == null) {
          // `startup: Sub Main` with no Sub Main() in a module (F019).
          final text = files[projectName]!;
          final at = RegExp(r'^startup:', multiLine: true).firstMatch(text);
          final offset = at?.start ?? 0;
          diagnostics.add(
            FileDiagnostic(
              projectName,
              Diagnostic(
                code: DiagnosticCode.noSubMain,
                line: '\n'.allMatches(text.substring(0, offset)).length + 1,
                column: 1,
                offset: offset,
                length: at == null ? 0 : at.end - at.start,
              ),
            ),
          );
        }
        if (readable) {
          final s = compiled.startup;
          startup = StartupForm(s.file, s.codeFile, s.program, compiled);
        }
      }
      return (diagnostics, startup);
    });
  }

  final String name;

  /// The project's files, file name → text.
  final Map<String, String> files;

  final (List<FileDiagnostic>, StartupForm?) Function() _compile;
  late final (List<FileDiagnostic>, StartupForm?) _compiled = _compile();

  List<FileDiagnostic> get diagnostics => _compiled.$1;

  /// The form the project starts with, compiled; null when the project
  /// files have errors.
  StartupForm? get startup => _compiled.$2;

  /// Whether the project can run: its startup form was read and its code
  /// has no errors (warnings do not count, D23).
  bool get canRun =>
      startup != null && !diagnostics.any((d) => d.diagnostic.isError);
}

/// The form a project starts with, and its compiled code.
class StartupForm {
  const StartupForm(this.form, this.codeFile, this.program, [this.project]);

  final FormFile form;

  /// The file the code is in (`Form1.gbas`), for run-time errors.
  final String codeFile;
  final CompileResult program;

  /// All the project's forms and modules, compiled (D88, D102); null for a
  /// form on its own.
  final ProjectProgram? project;

  /// The project's forms' files, this one first.
  List<FormFile> get forms => [
    form,
    for (final f in project?.forms ?? const <FormProgram>[])
      if (f.file != form) f.file,
  ];
}
