import '../ast/ast.dart';
import '../ast/line_map.dart';
import '../diagnostics/diagnostic.dart';
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

/// What the code of a project can use of a module (docs/DESIGN.md D102):
/// its `Public` variables and constants, and its procedures that are not
/// `Private`, by their names (`Total`) or with the module's
/// (`Module1.Total`). The symbols are from compiling the module on its
/// own; [ProjectProgram.canonical] gives the ones that run.
class ModuleInterface {
  ModuleInterface(this.name, this.variables, this.procedures);

  /// The module's name (`Module1`), as its file is named.
  final String name;

  /// By lower-case name.
  final Map<String, Symbol> variables;

  /// By lower-case name.
  final Map<String, Symbol> procedures;
}

/// One module of a project, compiled (D102).
class ModuleProgram {
  ModuleProgram(this.name, this.program);

  final String name;
  final CompileResult program;

  /// The file the module is (`Module1.gbas`).
  String get codeFile => '$name.gbas';
}

/// A module of a project before it is compiled: its name and its code.
typedef ModuleSource = ({String name, String source});

/// One form of a project, compiled.
class FormProgram {
  FormProgram(this.name, this.file, this.program);

  final String name;
  final FormFile file;
  final CompileResult program;

  /// The file the form's code is in (`Form1.gbas`), for run-time errors.
  String get codeFile => '$name.gbas';
}

/// A project's forms and modules, compiled so that each knows the others
/// (D88, D102).
class ProjectProgram {
  ProjectProgram(
    this.forms,
    this.startup, {
    this.modules = const [],
    this.startsWithMain = false,
    Map<Symbol, Symbol>? canonical,
  }) : canonical = canonical ?? Map.identity();

  /// In the project's order.
  final List<FormProgram> forms;

  /// The form the program starts with: shown first, unless it starts with
  /// `Sub Main`.
  final FormProgram startup;

  /// In the project's order (D102).
  final List<ModuleProgram> modules;

  /// Whether the program starts with `Sub Main` of a module (D102).
  final bool startsWithMain;

  /// For each symbol of a module's [ModuleInterface], the one of its
  /// compiled code, which is what runs.
  final Map<Symbol, Symbol> canonical;

  /// `Sub Main()` of a module, and its module; null when there is none.
  (ModuleProgram, ProcedureDecl)? get main {
    for (final m in modules) {
      if (m.program.analysis.fileScope.symbols['main']?.procedure case final p?
          when !p.isFunction && p.parameters.isEmpty) {
        return (m, p);
      }
    }
    return null;
  }

  /// Whether a form or module has errors, or the program is to start with
  /// a `Sub Main` no module has (F019).
  bool get hasErrors =>
      forms.any((f) => f.program.hasErrors) ||
      modules.any((m) => m.program.hasErrors) ||
      (startsWithMain && main == null);

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
/// What each of [modules] shows the others and the forms (D102), by
/// lower-case module name: each compiled on its own first, as forms are.
Map<String, ModuleInterface> moduleInterfaces(List<ModuleSource> modules) => {
      for (final m in modules)
        m.name.toLowerCase(): _interfaceOf(m.name, compile(m.source)),
    };

ModuleInterface _interfaceOf(String name, CompileResult alone) {
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
  return ModuleInterface(name, variables, procedures);
}

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

/// Compiles a project's [forms] and [modules], each knowing the others
/// (D88, D102), to start with [startup] (the first form when it names none
/// of them), or with `Sub Main` of a module when [startsWithMain].
ProjectProgram compileProject(
  List<FormSource> forms, {
  String? startup,
  List<String>? pictures,
  List<ModuleSource> modules = const [],
  bool startsWithMain = false,
}) {
  final interfaces = formInterfaces(forms, pictures: pictures);
  final moduleFaces = moduleInterfaces(modules);
  final programs = [
    for (final f in forms)
      FormProgram(
        f.file.name,
        f.file,
        compile(f.source,
            form: f.file,
            pictures: pictures,
            forms: interfaces,
            modules: moduleFaces),
      ),
  ];
  final modulePrograms = [
    for (final m in modules)
      ModuleProgram(
        m.name,
        compile(m.source,
            pictures: pictures, forms: interfaces, modules: moduleFaces),
      ),
  ];
  final canonical = Map<Symbol, Symbol>.identity();
  for (final m in modulePrograms) {
    final face = moduleFaces[m.name.toLowerCase()]!;
    final scope = m.program.analysis.fileScope.symbols;
    for (final MapEntry(:key, :value)
        in {...face.variables, ...face.procedures}.entries) {
      if (scope[key] case final s?) canonical[value] = s;
    }
  }
  // Sub Main in two modules: each says where the other is (A055).
  final mains = [
    for (final m in modulePrograms)
      if (m.program.analysis.fileScope.symbols['main']?.procedure case final p?
          when !p.isFunction && p.parameters.isEmpty)
        (m, p),
  ];
  if (mains.length > 1) {
    for (final (m, p) in mains) {
      final other = mains.firstWhere((o) => o.$1 != m).$1;
      final (line, column) =
          LineMap(m.program.parseResult.source).locate(p.name.start);
      m.program.analysis.diagnostics.add(Diagnostic(
        code: DiagnosticCode.mainTwice,
        line: line,
        column: column,
        offset: p.name.start,
        length: p.name.end - p.name.start,
        args: [other.name],
      ));
    }
  }
  final lower = startup?.toLowerCase();
  return ProjectProgram(
    programs,
    programs.firstWhere((p) => p.name.toLowerCase() == lower,
        orElse: () => programs.first),
    modules: modulePrograms,
    startsWithMain: startsWithMain,
    canonical: canonical,
  );
}
