import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// A project read from its files (docs/LANGUAGE.md §11.3) with modules and
/// Sub Main (docs/DESIGN.md D102).
void main() {
  const form = 'formatVersion: 1\n';

  test('modules are read and compiled; errors name their files', () {
    final p = Project.read({
      'Demo.gbproj':
          'formatVersion: 3\nname: Demo\nforms:\n  - Form1\n'
          'modules:\n  - Module1\n',
      'Form1.form.yaml': form,
      'Form1.gbas': 'Sub Form_Load()\nDebug.Print(Twice(2))\nEnd Sub\n',
      'Module1.gbas':
          'Function Twice(n As Integer) As Integer\n'
          'Return n * "x"\nEnd Function\n',
    });
    expect(p.diagnostics.map((d) => '${d.file} ${d.diagnostic.code.code}'), [
      'Module1.gbas A013',
    ]);
    expect(p.startup!.project!.modules.single.name, 'Module1');
  });

  test('starting with Sub Main needs one in a module (F019)', () {
    Map<String, String> files(String module) => {
      'Demo.gbproj':
          'formatVersion: 3\nname: Demo\nstartup: Sub Main\nforms:\n'
          '  - Form1\nmodules:\n  - Module1\n',
      'Form1.form.yaml': form,
      'Form1.gbas': '',
      'Module1.gbas': module,
    };
    final none = Project.read(files('Sub Start()\nEnd Sub\n'));
    expect(none.canRun, isFalse);
    final d = none.diagnostics.single;
    expect(
      [d.file, d.diagnostic.code.code, d.diagnostic.line],
      ['Demo.gbproj', 'F019', 3],
    );
    final one = Project.read(files('Sub Main()\nForm1.Show\nEnd Sub\n'));
    expect(one.canRun, isTrue);
    expect(one.startup!.project!.startsWithMain, isTrue);
  });

  test('a module the project lists but has no file of cannot run', () {
    final p = Project.read({
      'Demo.gbproj':
          'formatVersion: 3\nname: Demo\nforms:\n  - Form1\n'
          'modules:\n  - Module1\n',
      'Form1.form.yaml': form,
      'Form1.gbas': '',
    });
    expect(p.canRun, isFalse);
  });
}
