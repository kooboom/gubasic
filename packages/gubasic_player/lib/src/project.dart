import 'package:gubasic_lang/gubasic_lang.dart';

/// A problem found in one of a project's files.
class FileDiagnostic {
  const FileDiagnostic(this.file, this.diagnostic);

  final String file;
  final Diagnostic diagnostic;
}

/// A project read from its files: `NAME.gbproj`, and for each form
/// `FORM.form.yaml` and `FORM.gbas` next to it (docs/LANGUAGE.md §11.3).
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
      final formName = read.project.startupForm;
      StartupForm? startup;
      if (!read.hasErrors && formName != null) {
        final formFile = '$formName.form.yaml';
        final codeFile = '$formName.gbas';
        final pictures = read.project.pictures;
        final form = readFormFile(
          files[formFile] ?? '',
          name: formName,
          pictures: pictures,
        );
        diagnostics.addAll([
          for (final d in form.diagnostics) FileDiagnostic(formFile, d),
        ]);
        final source = files[codeFile] ?? '';
        final program = compile(source, form: form.form, pictures: pictures);
        diagnostics.addAll([
          for (final d in program.diagnostics) FileDiagnostic(codeFile, d),
        ]);
        if (!form.hasErrors && files.containsKey(formFile)) {
          startup = StartupForm(form.form, codeFile, program);
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
  const StartupForm(this.form, this.codeFile, this.program);

  final FormFile form;

  /// The file the code is in (`Form1.gbas`), for run-time errors.
  final String codeFile;
  final CompileResult program;
}
