import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// A form's menu bar (docs/DESIGN.md D106): written under `menus:`, read
/// as Menu controls, each naming the menu it is in. How the items behave
/// is in the parity program events_menu.
const _menus = '''
formatVersion: 3
controls:
  - name: btnOk
    type: Button
menus:
  - name: mnuFile
    properties:
      Caption: File
    menus:
      - name: mnuFileOpen
        properties:
          Caption: Open
          Shortcut: Ctrl+O
      - name: mnuFileLine
        properties:
          Caption: "-"
  - name: mnuHelp
    properties:
      Caption: Help
''';

void main() {
  test('normalShortcut: modifiers in order, then a key', () {
    expect(normalShortcut(''), '');
    expect(normalShortcut('ctrl+o'), 'Ctrl+O');
    expect(normalShortcut(' Shift + ctrl + s '), 'Ctrl+Shift+S');
    expect(normalShortcut('alt+1'), 'Alt+1');
    expect(normalShortcut('f5'), 'F5');
    expect(normalShortcut('Shift+F12'), 'Shift+F12');
    expect(normalShortcut('del'), 'Delete');
    expect(normalShortcut('Ctrl+Ins'), 'Ctrl+Insert');
    for (final bad in [
      'O', // typing it would choose the item
      'Shift+O',
      'Ctrl+Ctrl+O',
      'Ctrl+',
      'Ctrl+F13',
      'Ctrl+Home',
      'Ctrl+O+P',
      'Cmd+O',
    ]) {
      expect(normalShortcut(bad), isNull, reason: bad);
    }
  });

  test('a Menu in its component.yaml: a menu item, not seen on the form', () {
    final menu = builtinComponents['menu']!;
    expect(menu.menu, isTrue);
    expect(menu.visual, isFalse);
    expect(menu.designProperties.map((p) => p.name),
        ['Caption', 'Checked', 'Enabled', 'Visible', 'Shortcut', 'Tag']);
    expect(menu.properties['shortcut']!.shortcut, isTrue);
  });

  test(
      'menus: read after the controls, each in its menu, and written back '
      'the same, as version 3', () {
    final r = readFormFile(_menus, name: 'Form1');
    expect(r.diagnostics, isEmpty);
    expect([
      for (final c in r.form.controls) '${c.name} in ${c.container}'
    ], [
      'btnOk in null',
      'mnuFile in null',
      'mnuFileOpen in mnuFile',
      'mnuFileLine in mnuFile',
      'mnuHelp in null',
    ]);
    expect(r.form.control('mnuFileOpen')!.component, menuComponent);
    expect(writeFormFile(r.form), _menus);
  });

  test('F022: a Shortcut that is not one; a type or controls in a menu', () {
    final r = readFormFile('''
formatVersion: 3
menus:
  - name: mnuFile
    type: Menu
    properties: { Caption: File, Shortcut: O }
    controls: []
''', name: 'Form1');
    expect([for (final d in r.diagnostics) '${d.code.code}@${d.line}'],
        ['F004@4', 'F004@6', 'F022@5']);
    expect(
        r.diagnostics.last.message,
        '"O" is not a shortcut. Write Ctrl, Shift or Alt and a key, joined '
        'by +, as in "Ctrl+O" or "F5", or "" for none. A letter or digit '
        'needs Ctrl or Alt.');
    // A Menu is not a type of control to put under controls:.
    expect(
        readFormFile(
                'formatVersion: 3\ncontrols:\n  - { name: m, type: Menu }\n',
                name: 'Form1')
            .diagnostics
            .single
            .code
            .code,
        'F008');
  });

  test('A057 and R024: a Shortcut set in code', () async {
    final form = readFormFile(_menus, name: 'Form1').form;
    final program = compile(
        'Sub btnOk_Click()\nmnuFileOpen.Shortcut = "ctrl+p"\n'
        'mnuFileOpen.Shortcut = "P"\nEnd Sub\n',
        form: form);
    expect([for (final d in program.diagnostics) '${d.code.code}@${d.line}'],
        ['A057@3']);
    expect(
        await runEventScript(
            'Sub btnOk_Click()\nmnuFileOpen.Shortcut = "ctrl+p"\n'
                'Dim s As String = "P"\nmnuFileOpen.Shortcut = s\nEnd Sub\n',
            form,
            'btnOk.Click'),
        [
          '> btnOk.Click',
          'Set mnuFileOpen.Shortcut: Ctrl+P',
          'Error R024 @ 4',
        ]);
  });

  test(
      'menus are not among Me.Controls, and a script cannot choose a '
      'menu with items or a line', () async {
    final form = readFormFile(_menus, name: 'Form1').form;
    expect(
        await runEventScript(
            'Sub Form_Load()\nDebug.Print(Me.Controls.Count)\nEnd Sub\n',
            form,
            'Close'),
        ['Debug.Print: 1', '> Close', 'Closed']);
    for (final step in ['mnuFile.Click', 'mnuFileLine.Click']) {
      expect(() => runEventScript('', form, step), throwsStateError,
          reason: step);
    }
  });

  test('PopupMenu: a menu of the form with items (R025, R026, A008)', () async {
    final form = readFormFile(_menus, name: 'Form1').form;
    expect([
      for (final d in compile(
              'Sub btnOk_Click()\nMe.PopupMenu(btnOk)\nEnd Sub\n',
              form: form)
          .diagnostics)
        d.code.code
    ], [
      'A008'
    ]);
    expect(
        await runEventScript(
            'Sub btnOk_Click()\nMe.PopupMenu(mnuFileOpen)\nEnd Sub\n',
            form,
            'btnOk.Click'),
        ['> btnOk.Click', 'Error R025 @ 2']);
    final other = readFormFile(
            'formatVersion: 1\ncontrols:\n  - { name: btnGo, type: Button }\n',
            name: 'Form2')
        .form;
    expect(
        await runProjectScript([
          (file: form, source: 'Sub btnOk_Click()\nForm2.Show\nEnd Sub\n'),
          (
            file: other,
            source: 'Sub btnGo_Click()\nMe.PopupMenu(Form1.mnuFile)\nEnd Sub\n'
          ),
        ], 'btnOk.Click\nForm2.btnGo.Click'),
        contains('Error R026 @ Form2.gbas:2'));
  });

  test('A058 and P029: a form method without Me., VB6\'s PopupMenu mnuEdit',
      () {
    final form = readFormFile(_menus, name: 'Form1').form;
    List<String> codes(String line) => [
          for (final d
              in compile('Sub btnOk_Click()\n$line\nEnd Sub\n', form: form)
                  .diagnostics)
            '${d.code.code} ${d.replacements}'
        ];
    expect(codes('Hide'), ['A058 [Me.Hide]']);
    expect(codes('PopupMenu(mnuFile)'), ['A058 [Me.PopupMenu]']);
    expect(codes('PopupMenu mnuFile'), ['P029 []']);
    expect(codes('Me.PopupMenu(mnuFile)'), isEmpty);
    final d =
        compile('Sub btnOk_Click()\nPopupMenu mnuFile\nEnd Sub\n', form: form)
            .diagnostics
            .single;
    expect(
        d.message,
        'GuBASIC calls PopupMenu as a method of the form, with parentheses: '
        'write Me.PopupMenu(mnuFile).');
    expect(
        compile('Sub btnOk_Click()\nHide\nEnd Sub\n', form: form)
            .diagnostics
            .single
            .message,
        'Hide is a method of the form: write Me.Hide, as GuBASIC writes '
        'every form method.');
  });
}
