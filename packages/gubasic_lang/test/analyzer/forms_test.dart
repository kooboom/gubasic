import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Code analyzed with a form holding lblMessage (Label), btnSave (Button)
/// and txtName (TextBox) (docs/LANGUAGE.md §8, §11).
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lblMessage, type: Label }
  - { name: btnSave, type: Button }
  - { name: txtName, type: TextBox }
''', name: 'Form1').form;

/// A form with a ListBox and a CheckBox too, for their members.
final _formWithList = readFormFile('''
formatVersion: 1
controls:
  - { name: lstCity, type: ListBox }
  - { name: chkShow, type: CheckBox }
''', name: 'Form1').form;

CompileResult _compile(String source) => compile(source, form: _form);

List<String> diagnose(String source) => _compile(source)
    .diagnostics
    .map((d) => '${d.code.code}@${d.line}')
    .toList();

List<String> inSub(String body) => diagnose('Sub Work()\n$body\nEnd Sub\n')
    .map((c) => c.split('@')[0])
    .toList();

void main() {
  group('controls', () {
    test('are known by name, in any case, with their types', () {
      final r = _compile('Sub Work()\nlblMessage.Caption = "Hi"\n'
          'BTNSAVE.caption = txtname.TEXT\nEnd Sub\n');
      expect(r.diagnostics, isEmpty);
      final kinds = r.analysis.symbols.values
          .where((s) => s.kind == SymbolKind.control)
          .map((s) => '${s.name}: ${s.type.displayName}')
          .toSet();
      expect(kinds, {
        'lblMessage: Label',
        'btnSave: Button',
        'txtName: TextBox',
      });
    });

    test('properties have types and follow the usual conversions', () {
      expect(inSub('lblMessage.Caption = 5'), isEmpty, reason: '→ text');
      expect(inSub('btnSave.Left = btnSave.Left + 8'), isEmpty);
      expect(inSub('btnSave.Left = 1.5'), ['A010']);
      expect(inSub('btnSave.Width = txtName.Text'), ['A009']);
      expect(inSub('Dim n As Integer = txtName.Text'), ['A026', 'A009']);
    });

    test('A019: a property the control does not have', () {
      expect(inSub('txtName.Caption = "x"'), ['A019']);
      expect(inSub('lblMessage.Size = 3'), ['A019']);
    });

    test('A035: a member close to one the control has', () {
      final d = compile('Sub W()\nDebug.Print(lstCity.ListIndx)\nEnd Sub\n',
              form: _formWithList)
          .diagnostics
          .single;
      expect(d.code.code, 'A035');
      expect(d.args, ['ListBox', 'ListIndx', 'ListIndex']);
      expect(d.replacements, ['ListIndex']);
      expect(d.formatMessage(koreanMessages),
          'ListBox 타입에는 ListIndx 멤버가 없습니다. 비슷한 멤버로 ListIndex 멤버가 있으니 철자를 확인해 주세요.');
    });

    test('A036: a name other versions of BASIC use (otherNames)', () {
      expect(inSub('lblMessage.Text = "x"'), ['A036']);
      expect(inSub('btnSave.Text = "x"'), ['A036']);
      final d = compile(
              'Sub W()\nlstCity.Items.Add("a")\nchkShow.Value = 1\nEnd Sub\n',
              form: _formWithList)
          .diagnostics;
      expect(d.map((d) => d.code.code), ['A036', 'A036']);
      expect(d[0].replacements, ['AddItem', 'List', 'ListCount']);
      expect(
          d[0].message,
          'ListBox has no member named "Items". GuBASIC '
          'calls it differently: use AddItem, List, ListCount.');
      expect(d[1].replacements, ['Checked']);
      expect(d[1].formatMessage(koreanMessages),
          'CheckBox 타입에는 Value 멤버가 없습니다. GuBASIC에서는 이름이 달라서 Checked 멤버를 씁니다.');
    });

    test('a control itself cannot be assigned, called or used as a value', () {
      expect(inSub('btnSave = Nothing'), ['A020']);
      expect(inSub('btnSave()'), ['A018']);
      expect(inSub('Debug.Print(btnSave.Caption & lblMessage)'), ['A013']);
    });

    test('controls are objects: Is, Nothing, Object and typed variables', () {
      expect(
          inSub('Dim b As Button = btnSave\n'
              'If b Is btnSave Then b = Nothing\n'
              'Dim o As Object = lblMessage\nDebug.Print(o Is Nothing)'),
          isEmpty);
      expect(inSub('Dim b As Button = lblMessage\nb = Nothing'), ['A008']);
    });

    test('a misspelled control is a typo, with a suggestion (A002)', () {
      expect(inSub('lblMesage.Caption = "x"'), ['A002']);
      expect(
          _compile('Sub W()\nlblMesage.Caption = "x"\nEnd Sub')
              .diagnostics
              .single
              .args,
          ['lblMesage', 'lblMessage']);
      expect(inSub('nothingLikeIt.Caption = "x"'), ['A001']);
    });
  });

  group('Me', () {
    test('is the form, with the form\'s properties', () {
      expect(inSub('Me.Caption = "Score"\nMe.Width = Me.Height * 2'), isEmpty);
      expect(inSub('Me.Text = "x"'), ['A036']);
      expect(inSub('Me.Size = 3'), ['A019']);
    });

    test('without a form it is reported (A003), as are controls', () {
      final r = compile('Sub W()\nMe.Caption = "x"\nbtnSave.Caption = "y"\n'
          'End Sub\n');
      expect(r.diagnostics.map((d) => '${d.code.code} ${d.args}'),
          ['A003 [Me]', 'A003 [btnSave]']);
    });
  });

  group('names', () {
    test('A030: a form-level name that is a control\'s name', () {
      expect(diagnose('Dim btnSave As Integer\nSub txtName()\nEnd Sub\n'),
          ['A030@1', 'A030@2']);
    });

    test('A031: a local hiding a control is a warning', () {
      final r = _compile('Sub W()\nDim lblMessage = 1\n'
          'Debug.Print(lblMessage)\nEnd Sub\n');
      expect(r.diagnostics.map((d) => d.code.code), ['A031']);
      expect(r.hasErrors, isFalse);
    });
  });

  group('event handlers', () {
    String handlers(String source) => _compile(source)
        .analysis
        .handlers
        .entries
        .map((e) => '${e.key.name.name}: ${e.value.control?.name ?? 'Form'}.'
            '${e.value.event.name}')
        .join(', ');

    test('Control_Event and Form_Event, in any case', () {
      expect(
          handlers('Sub Form_Load()\nEnd Sub\nSub btnSave_Click()\nEnd Sub\n'
              'Sub TXTNAME_changed()\nEnd Sub\nSub lblMessage_Click()\n'
              'End Sub\n'),
          'Form_Load: Form.Load, btnSave_Click: btnSave.Click, '
          'TXTNAME_changed: txtName.Changed, '
          'lblMessage_Click: lblMessage.Click');
    });

    test('other names are ordinary procedures', () {
      expect(
          handlers('Sub btnSave_Clicked()\nEnd Sub\nSub Save_Click()\n'
              'End Sub\nSub btnSaveClick()\nEnd Sub\n'),
          '');
    });

    test('A032: a handler written differently from its event', () {
      expect(
          diagnose('Sub btnSave_Click(x As Integer)\nEnd Sub\n'
              'Function Form_Load() As Integer\nReturn 1\nEnd Function\n'),
          ['A032@1', 'A032@3']);
      final d = _compile('Sub btnSave_Click(x As Integer)\nEnd Sub\n')
          .diagnostics
          .single;
      expect(d.args, ['btnSave_Click', 'btnSave.Click', 'Sub btnSave_Click()']);
      expect(d.formatMessage(koreanMessages),
          contains('btnSave_Click 프로시저는 btnSave.Click 이벤트 때'));
    });

    test('without a form, nothing is a handler and Form_Load is not checked',
        () {
      final r = compile('Function Form_Load() As Integer\nReturn 1\n'
          'End Function\n');
      expect(r.diagnostics, isEmpty);
      expect(r.analysis.handlers, isEmpty);
    });
  });
}
