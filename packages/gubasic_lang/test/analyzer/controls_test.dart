import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// What replaces control arrays (docs/DESIGN.md D98): Handles for several
/// controls, the handler's sender, the Control type, Me.Controls, TypeOf,
/// CType, controls made with New, AddHandler. How they run is in the
/// parity programs handles_shared, controls_loop, controls_new and
/// controls_cast_error.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnA, type: Button }
  - { name: btnB, type: Button }
  - { name: lblShow, type: Label }
  - { name: txtName, type: TextBox }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

List<String> _inSub(String body) => [
      for (final c in _codes('Sub Work()\n$body\nEnd Sub\n')) c.split('@')[0],
    ];

String _handlers(String source) => compile(source, form: _form)
    .analysis
    .handlers
    .entries
    .expand((e) => e.value.map((h) =>
        '${e.key.name.name}: ${h.control?.name ?? 'Form'}.${h.event.name}'))
    .join(', ');

Future<String> _run(String source, String script) async =>
    (await runEventScript(source, _form, script)).join('\n');

void main() {
  group('Handles', () {
    test('a procedure handles exactly what it lists, whatever its name', () {
      expect(
          _handlers('Sub Pressed() Handles btnA.Click, btnB.click, Me.Load\n'
              'End Sub\n'),
          'Pressed: btnA.Click, Pressed: btnB.Click, Pressed: Form.Load');
      expect(_codes('Sub Pressed() Handles btnA.Click\nEnd Sub\n'), isEmpty);
    });

    test('a name like another event\'s handler is warned about (A042)', () {
      expect(
          _codes('Sub btnA_Click() Handles btnB.Click\nEnd Sub\n'), ['A042@1']);
      expect(_handlers('Sub btnA_Click() Handles btnB.Click\nEnd Sub\n'),
          'btnA_Click: btnB.Click');
      // Listing its own event as well is fine.
      expect(
          _codes('Sub btnA_Click() Handles btnA.Click, btnB.Click\nEnd Sub\n'),
          isEmpty);
    });

    test('unknown controls (A001) and events (A040)', () {
      expect(_codes('Sub P() Handles btnC.Click\nEnd Sub\n'), ['A002@1']);
      expect(_codes('Sub P() Handles btnA.Changed\nEnd Sub\n'), ['A040@1']);
      expect(_codes('Sub P() Handles Me.Click\nEnd Sub\n'), ['A040@1']);
    });

    test('one event has one handler (A041)', () {
      expect(
          _codes('Sub btnA_Click()\nEnd Sub\n'
              'Sub Other() Handles btnA.Click\nEnd Sub\n'),
          ['A041@3']);
      expect(
          _codes('Sub One() Handles btnA.Click\nEnd Sub\n'
              'Sub Two() Handles btnB.Click, btnA.Click\nEnd Sub\n'),
          ['A041@3']);
    });

    test('without a form there are no controls to handle', () {
      expect(
          compile('Sub P() Handles btnA.Click\nEnd Sub\n')
              .diagnostics
              .map((d) => d.code.code),
          ['A003']);
    });
  });

  group('sender', () {
    test('of the controls\' type, Control, or none', () {
      for (final params in [
        '',
        'sender As Button',
        'sender As Control',
      ]) {
        expect(
            _codes('Sub P($params) Handles btnA.Click, btnB.Click\nEnd Sub\n'),
            isEmpty,
            reason: params);
      }
      expect(
          _codes('Sub P(sender As Control) Handles btnA.Click, lblShow.Click\n'
              'End Sub\n'),
          isEmpty);
      expect(_codes('Sub btnA_Click(sender As Button)\nEnd Sub\n'), isEmpty);
      expect(_codes('Sub Form_Load(sender As Form)\nEnd Sub\n'), isEmpty);
    });

    test('that cannot hold one of the controls (A043)', () {
      expect(
          _codes('Sub P(sender As Button) Handles btnA.Click, lblShow.Click\n'
              'End Sub\n'),
          ['A043@1']);
      expect(_codes('Sub btnA_Click(sender As Label)\nEnd Sub\n'), ['A043@1']);
    });

    test('written as in Visual Basic .NET (A044)', () {
      final r = compile(
          'Sub P(sender As Object, e As EventArgs) Handles btnA.Click\n'
          'End Sub\n',
          form: _form);
      expect(r.diagnostics.map((d) => d.code.code), contains('A044'));
      expect(r.diagnostics.firstWhere((d) => d.code.code == 'A044').args,
          ['P', 'sender As Button']);
      expect(_codes('Sub btnA_Click(sender As Object)\nEnd Sub\n'), ['A044@1']);
    });

    test('anything else is written differently from the event (A032)', () {
      expect(_codes('Sub btnA_Click(n As Integer)\nEnd Sub\n'), ['A032@1']);
      expect(
          _codes('Function P() As Integer Handles btnA.Click\n'
              'Return 1\nEnd Function\n'),
          ['A032@1']);
    });
  });

  group('Control, Name, Tag and Me.Controls', () {
    test('any control is a Control; back only through CType (A046)', () {
      expect(_inSub('Dim c As Control = btnA\nc.Left = 3'), isEmpty);
      expect(
          _inSub('Dim c As Control = btnA\nDim b As Button = c\n'
              'b.Caption = "x"'),
          ['A046']);
      expect(
          _inSub('Dim c As Control = btnA\n'
              'Dim b As Button = CType(c, Button)\nb.Caption = "x"'),
          isEmpty);
      expect(_inSub('Dim c As Control = Me\nc.Left = 1'), ['A008']);
      expect(_inSub('Dim c As Control = btnA\nc.Caption = "x"'), ['A019']);
    });

    test(
        'Name and Tag; the Name of a drawn control or a form is read only '
        '(A034)', () {
      expect(
          _inSub('Debug.Print(btnA.Name & Me.Name & btnA.Tag)\n'
              'btnA.Tag = "x"\nMe.Tag = "y"'),
          isEmpty);
      expect(_inSub('btnA.Name = "x"'), ['A034']);
      expect(_inSub('Me.Name = "x"'), ['A034']);
      expect(_inSub('Dim b As New Button\nb.Name = "btnNew"'), isEmpty);
    });

    test('Me.Controls: counted, numbered, looped over, added to', () {
      expect(
          _inSub('Debug.Print(Me.Controls.Count)\n'
              'Dim c As Control = Me.Controls(0)\nc.Top = 1\n'
              'For Each d As Control In Me.Controls\nd.Left = 0\nNext\n'
              'Dim b As New Button\nMe.Controls.Add(b)\n'
              'Me.Controls.Remove(btnA)'),
          isEmpty);
      expect(_inSub('Me.Controls.Add(Me)'), ['A008']);
      expect(_inSub('Me.Controls = Nothing'), ['A034']);
    });
  });

  group('TypeOf and CType', () {
    test('take controls and control types (A045)', () {
      expect(
          _inSub('Dim c As Control = btnA\n'
              'Debug.Print(TypeOf c Is TextBox)\n'
              'Debug.Print(TypeOf btnA Is Control)'),
          isEmpty);
      expect(
          _inSub('Dim c As Control = btnA\n'
              'Debug.Print(TypeOf c Is Integer)'),
          ['A045']);
      expect(_inSub('Dim n As Integer = CType("3", Integer)\nDebug.Print(n)'),
          ['A008', 'A045']);
      expect(_inSub('Debug.Print(TypeOf 3 Is Button)'), ['A008']);
    });

    test('DirectCast and TryCast are read as CType (P026)', () {
      expect(
          _inSub('Dim c As Control = btnA\n'
              'Dim t As TextBox = DirectCast(c, TextBox)\nt.Text = ""'),
          ['P026']);
      expect(
          _inSub('Dim c As Control = btnA\n'
              'Dim t As TextBox = TryCast(c, TextBox)\nt.Text = ""'),
          ['P026']);
    });
  });

  group('AddHandler', () {
    test('a Sub of this code written as the event\'s handler', () {
      expect(
          _codes('Sub Work()\nDim b As New Button\n'
              'AddHandler b.Click, AddressOf Pressed\nEnd Sub\n'
              'Sub Pressed(sender As Button)\nEnd Sub\n'),
          isEmpty);
      expect(
          _codes('Sub Work()\nAddHandler btnA.Click, AddressOf Pressed\n'
              'End Sub\nSub Pressed()\nEnd Sub\n'),
          isEmpty);
    });

    test('what does not fit', () {
      String source(String line, [String rest = '']) =>
          'Sub Work()\nDim b As New Button\n$line\nEnd Sub\n$rest';
      expect(
          _codes(source(
              'AddHandler b.Changed, AddressOf P', 'Sub P()\nEnd Sub\n')),
          ['A040@3']);
      expect(_codes(source('AddHandler b.Click, AddressOf Nope')), ['A001@3']);
      expect(
          _codes('Dim count As Integer\n${source('AddHandler b.Click, '
              'AddressOf count')}'),
          ['A048@4']);
      expect(
          _codes(source('AddHandler b.Click, AddressOf P',
              'Sub P(sender As Label)\nEnd Sub\n')),
          ['A043@3']);
      expect(
          _codes(source('AddHandler b.Click, AddressOf P',
              'Sub P(n As Integer)\nEnd Sub\n')),
          ['A032@5']);
      expect(
          _codes('Sub Work()\nDim n As Integer = 1\n'
              'AddHandler n.Click, AddressOf P\nEnd Sub\nSub P()\nEnd Sub\n'),
          ['A008@3']);
    });
  });

  group('while the program runs', () {
    test('a control\'s Name is set only before it is added (R019, R020)',
        () async {
      expect(
          await _run(
              'Sub Form_Load()\nDim b As New Button\nb.Name = "1x"\nEnd Sub\n',
              'Close'),
          endsWith('Error R020 @ 3'));
      expect(
          await _run(
              'Sub Form_Load()\nDim b As New Button\nMe.Controls.Add(b)\n'
                  'b.Name = "btnZ"\nEnd Sub\n',
              'Close'),
          endsWith('Error R019 @ 4'));
    });

    test('Controls.Add and Remove: names, forms (R016, R017, R018)', () async {
      expect(
          await _run(
              'Sub Form_Load()\nDim b As New Button\nb.Name = "BTNA"\n'
                  'Me.Controls.Add(b)\nEnd Sub\n',
              'Close'),
          endsWith('Error R016 @ 4'));
      expect(
          await _run(
              'Sub Form_Load()\nMe.Controls.Add(btnA)\nEnd Sub\n', 'Close'),
          endsWith('Error R017 @ 2'));
      expect(
          await _run(
              'Sub Form_Load()\nDim b As New Button\nMe.Controls.Remove(b)\n'
                  'End Sub\n',
              'Close'),
          endsWith('Error R018 @ 3'));
      expect(
          await _run(
              'Sub Form_Load()\nDim b As Button\nMe.Controls.Add(b)\n'
                  'End Sub\n',
              'Close'),
          endsWith('Error R004 @ 3'));
    });

    test('a drawn control taken off and put back keeps its handler', () async {
      expect(
          await _run(
              'Sub btnA_Click()\nDebug.Print("A")\nEnd Sub\n'
                  'Sub btnB_Click()\nMe.Controls.Remove(btnA)\n'
                  'Debug.Print(Me.Controls.Count)\nMe.Controls.Add(btnA)\n'
                  'Debug.Print(Me.Controls(3).Name)\nEnd Sub\n',
              'btnB.Click\nbtnA.Click\nClose'),
          '> btnB.Click\nRemove btnA\nDebug.Print: 3\nAdd btnA (Button)\n'
          'Debug.Print: btnA\n> btnA.Click\nDebug.Print: A\n> Close\nClosed');
    });

    test('an event has one handler (R021)', () async {
      expect(
          await _run(
              'Sub btnA_Click()\nEnd Sub\nSub Other()\nEnd Sub\n'
                  'Sub Form_Load()\nAddHandler btnA.Click, AddressOf Other\n'
                  'End Sub\n',
              'Close'),
          endsWith('Error R021 @ 6'));
      // The same handler again is no change.
      expect(
          await _run(
              'Sub Form_Load()\nAddHandler btnA.Click, AddressOf P\n'
                  'AddHandler btnA.Click, AddressOf P\nEnd Sub\n'
                  'Sub P()\nDebug.Print("P")\nEnd Sub\n',
              'btnA.Click\nClose'),
          endsWith('Debug.Print: P\n> Close\nClosed'));
    });

    test('TypeOf Nothing is False; CType of Nothing is Nothing', () async {
      expect(
          await _run(
              'Sub Form_Load()\nDim c As Control\n'
                  'Debug.Print(TypeOf c Is Button)\n'
                  'Dim b As Button = CType(c, Button)\n'
                  'Debug.Print(b Is Nothing)\nEnd Sub\n',
              'Close'),
          'Debug.Print: False\nDebug.Print: True\n> Close\nClosed');
    });
  });

  group('from control arrays and On Error (D99)', () {
    test('a control array\'s handler (A049)', () {
      final r =
          compile('Sub btnA_Click(Index As Integer)\nEnd Sub\n', form: _form);
      expect(r.diagnostics.map((d) => d.code.code), ['A049']);
      expect(r.diagnostics.single.args, ['btnA_Click', 'btnA.Click', 'Button']);
      expect(
          r.diagnostics.single.message,
          'GuBASIC has no control arrays, so a handler gets no Index. To '
          'handle several controls with btnA_Click, list them after Handles '
          'and take the one clicked as sender: Sub Pressed(sender As Button) '
          'Handles btnA.Click, … A Tag can number them.');
    });

    test('a control as an array (A050); Index is Tag (A036)', () {
      expect(_inSub('btnA(0).Caption = "x"'), ['A050']);
      expect(_inSub('Dim b As Button = btnA\nDebug.Print(b(1).Caption)'),
          ['A050']);
      final d = compile(
              'Sub P(sender As Button) Handles btnA.Click\n'
              'Debug.Print(sender.Index)\nEnd Sub\n',
              form: _form)
          .diagnostics
          .single;
      expect(d.code.code, 'A036');
      expect(d.replacements, ['Tag']);
    });

    test(
        'Load and Unload of an element (P027, P028), of a form (P025, '
        'P024)', () {
      List<String> parsed(String line) => [
            for (final d in parse('Sub P()\n$line\nEnd Sub\n').diagnostics)
              d.code.code
          ];
      expect(parsed('Load btnA(1)'), ['P027']);
      expect(parsed('Unload btnA(1)'), ['P028']);
      expect(parsed('Load Form2'), ['P025']);
      expect(parsed('Unload Form2'), ['P024']);
    });

    test('On Error says how to write Try … Catch (P013)', () {
      final d =
          parse('Sub P()\nOn Error Resume Next\nEnd Sub\n').diagnostics.single;
      expect(d.code.code, 'P013');
      expect(d.message, contains('Catch ex As Exception'));
      expect(
          d.formatMessage(koreanMessages), contains('Catch ex As Exception'));
    });
  });
}
