import '../ast/ast.dart';
import '../forms/form_file.dart';
import '../lexer/keyword.dart';
import 'compile.dart';
import 'symbols.dart';

/// What the code of a project's forms can use of a form besides its
/// component's properties and methods (docs/DESIGN.md D88): its controls,
/// its `Public` variables and constants, and its procedures that are not
/// `Private`, as `Form2.txtName`, `Form2.Score` and `Form2.Start("Kim")`.
class FormInterface {
  FormInterface(this.name, this.file, this.variables, this.procedures);

  /// The form's name (`Form2`), as its files are named.
  final String name;
  final FormFile file;

  /// By lower-case name.
  final Map<String, Symbol> variables;

  /// By lower-case name.
  final Map<String, Symbol> procedures;
}

/// One form of a project, compiled.
class FormProgram {
  FormProgram(this.name, this.file, this.program);

  final String name;
  final FormFile file;
  final CompileResult program;

  /// The file the form's code is in (`Form1.gbas`), for run-time errors.
  String get codeFile => '$name.gbas';
}

/// A project's forms, compiled so that each knows the others (D88).
class ProjectProgram {
  ProjectProgram(this.forms, this.startup);

  /// In the project's order.
  final List<FormProgram> forms;

  /// The form the program starts with.
  final FormProgram startup;

  bool get hasErrors => forms.any((f) => f.program.hasErrors);

  /// The form named [name] (any case), or null.
  FormProgram? form(String name) {
    final lower = name.toLowerCase();
    for (final f in forms) {
      if (f.name.toLowerCase() == lower) return f;
    }
    return null;
  }
}

/// A form of a project before it is compiled: its file and its code.
typedef FormSource = ({FormFile file, String source});

/// What each of [forms] shows the others, by lower-case form name. Each
/// form's code is compiled on its own first, without the others, to learn
/// the types of its variables and procedures; a variable whose type comes
/// from another form's member is then not known (`Dim n = Form2.Score`:
/// give it `As Integer`).
Map<String, FormInterface> formInterfaces(
  List<FormSource> forms, {
  List<String>? pictures,
}) {
  final interfaces = <String, FormInterface>{};
  for (final f in forms) {
    final alone = compile(f.source, form: f.file, pictures: pictures);
    final symbols = alone.analysis.symbols;
    final variables = <String, Symbol>{};
    final procedures = <String, Symbol>{};
    for (final member in alone.parseResult.unit.members) {
      switch (member) {
        case FieldDecl(:final modifier, :final declarator)
            when modifier == Keyword.kwPublic:
          if (symbols[declarator.name] case final s?) {
            variables[s.name.toLowerCase()] = s;
          }
        case ProcedureDecl(:final modifier, :final name)
            when modifier != Keyword.kwPrivate:
          if (symbols[name] case final s? when s.procedure == member) {
            procedures[s.name.toLowerCase()] = s;
          }
        default:
      }
    }
    interfaces[f.file.name.toLowerCase()] =
        FormInterface(f.file.name, f.file, variables, procedures);
  }
  return interfaces;
}

/// Compiles a project's [forms], each knowing the others (D88), to start
/// with [startup] (the first form when it names none of them).
ProjectProgram compileProject(
  List<FormSource> forms, {
  String? startup,
  List<String>? pictures,
}) {
  final interfaces = formInterfaces(forms, pictures: pictures);
  final programs = [
    for (final f in forms)
      FormProgram(
        f.file.name,
        f.file,
        compile(f.source, form: f.file, pictures: pictures, forms: interfaces),
      ),
  ];
  final lower = startup?.toLowerCase();
  return ProjectProgram(
    programs,
    programs.firstWhere((p) => p.name.toLowerCase() == lower,
        orElse: () => programs.first),
  );
}
