import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// A project's modules (docs/DESIGN.md D102): their Public names used
/// anywhere, with or without the module's name, and Sub Main. How they run
/// is in the parity programs modules_shared, modules_main,
/// modules_main_ends and modules_error.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblTotal, type: Label }
''', name: 'Form1').form;

ProjectProgram _project(String form, Map<String, String> modules,
        {bool main = false}) =>
    compileProject([
      (file: _form, source: form)
    ], modules: [
      for (final MapEntry(:key, :value) in modules.entries)
        (name: key, source: value),
    ], startsWithMain: main);

List<String> _codes(ProjectProgram p) => [
      for (final (file, program) in [
        for (final f in p.forms) (f.codeFile, f.program),
        for (final m in p.modules) (m.codeFile, m.program),
      ])
        for (final d in program.diagnostics) '${d.code.code}@$file:${d.line}',
    ];

const _module1 = 'Public Total As Integer\nDim secret As Integer\n'
    'Public Const Limit As Integer = 10\n'
    'Sub AddUp(n As Integer)\nTotal = Total + n\nsecret = secret + 1\n'
    'End Sub\nPrivate Sub Hidden()\nEnd Sub\n';

void main() {
  test('Public names by themselves and with the module\'s name', () {
    final p = _project(
        'Sub Form_Load()\nAddUp(Limit)\nModule1.AddUp(1)\n'
        'Module1.Total = Total + 1\nlblTotal.Caption = CStr(Module1.Total)\n'
        'End Sub\n',
        {'Module1': _module1});
    expect(_codes(p), isEmpty);
  });

  test('a module\'s Dim and Private stay its own; a Const cannot change', () {
    expect(
        _codes(_project(
            'Sub Form_Load()\nsecret = 1\nEnd Sub\n', {'Module1': _module1})),
        ['A001@Form1.gbas:2']);
    expect(
        _codes(_project('Sub Form_Load()\nModule1.Hidden()\nEnd Sub\n',
            {'Module1': _module1})),
        ['A019@Form1.gbas:2']);
    expect(
        _codes(_project('Sub Form_Load()\nModule1.Limit = 3\nEnd Sub\n',
            {'Module1': _module1})),
        ['A034@Form1.gbas:2']);
  });

  test('a module uses the forms, the other modules, and no Me', () {
    expect(
        _codes(_project('', {
          'Module1': _module1,
          'Tools': 'Sub Show()\nForm1.Show\nForm1.lblTotal.Caption = '
              'CStr(Total)\nAddUp(2)\nEnd Sub\n',
        })),
        isEmpty);
    expect(
        _codes(_project('', {
          'Tools': 'Sub Show()\nMe.Caption = ""\n'
              'End Sub\n'
        })),
        ['A003@Tools.gbas:2']);
  });

  test('a name Public in two modules is written with its module (A054)', () {
    final p = _project(
        'Sub Form_Load()\nTotal = 1\nModule2.Total = 2\n'
        'End Sub\n',
        {
          'Module1': 'Public Total As Integer\n',
          'Module2': 'Public Total As Integer\n',
        });
    expect(_codes(p), ['A054@Form1.gbas:2']);
    final d = p.forms.single.program.diagnostics.single;
    expect(d.args, ['Total', 'Module1, Module2', 'Module1.Total']);
  });

  test(
      'Sub Main: in one module (A055); the project starting with it needs '
      'one (F019)', () {
    final twice = _project(
        '',
        {
          'Module1': 'Sub Main()\nEnd Sub\n',
          'Module2': 'Sub Main()\nEnd Sub\n',
        },
        main: true);
    expect(_codes(twice), ['A055@Module1.gbas:1', 'A055@Module2.gbas:1']);
    final none = _project('', {'Module1': 'Sub Main(n As Integer)\nEnd Sub\n'},
        main: true);
    expect(none.main, isNull);
    expect(none.hasErrors, isTrue, reason: 'F019');
    final one = _project('', {'Module1': 'Sub Main()\nEnd Sub\n'}, main: true);
    expect(one.main!.$1.name, 'Module1');
    expect(one.hasErrors, isFalse);
  });

  group('the project file', () {
    test('modules and startup: Sub Main, written as version 3', () {
      final r = readProjectFile('formatVersion: 3\nname: Demo\n'
          'startup: Sub Main\nforms:\n  - Form1\nmodules:\n  - Module1\n'
          '  - Tools\n');
      expect(r.diagnostics, isEmpty);
      expect(r.project.modules, ['Module1', 'Tools']);
      expect(r.project.startsWithMain, isTrue);
      expect(r.project.startupForm, 'Form1');
      expect(
          writeProjectFile(r.project),
          'formatVersion: 3\nname: Demo\nstartup: Sub Main\nforms:\n'
          '  - Form1\nmodules:\n  - Module1\n  - Tools\n');
    });

    test('without modules, as before', () {
      final p = ProjectFile(name: 'Demo', forms: const ['Form1']);
      expect(writeProjectFile(p), startsWith('formatVersion: 1\n'));
    });

    test('a module cannot share a name, or start the program (F007, F011)', () {
      String codes(String text) => [
            for (final d in readProjectFile(text).diagnostics) d.code.code
          ].join(' ');
      expect(
          codes('formatVersion: 3\nname: D\nforms:\n  - Form1\n'
              'modules:\n  - form1\n'),
          'F007');
      expect(
          codes('formatVersion: 3\nname: D\nstartup: Module1\nforms:\n'
              '  - Form1\nmodules:\n  - Module1\n'),
          'F011');
      expect(codes('formatVersion: 4\nname: D\nforms:\n  - Form1\n'), 'F003');
    });
  });
}
