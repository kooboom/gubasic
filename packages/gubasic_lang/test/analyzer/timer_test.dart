import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// The Timer (docs/DESIGN.md D82, D100). How it ticks is in the parity
/// programs timer_clock and timer_turns.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: tmrClock, type: Timer, properties: { Interval: 250 } }
  - { name: txtName, type: TextBox }
  - { name: lstCity, type: ListBox }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('a Timer in its component.yaml: not seen on the form', () {
    final timer = builtinComponents['timer']!;
    expect(timer.visual, isFalse);
    expect(timer.defaultEvent, 'Tick');
    expect(timer.designProperties.map((p) => p.name),
        ['Interval', 'Enabled', 'Tag']);
    expect(timer.properties['interval']!.min, 1);
    expect(timer.properties['interval']!.defaultValue, 100);
    expect(timer.properties['enabled']!.defaultValue, false);
    expect(timer.methods.keys, ['start', 'stop']);
    expect(_form.control('tmrClock')!.valueOf('Interval'), 250);
  });

  test('its handler, members and methods', () {
    expect(
        _codes('Sub tmrClock_Tick()\n'
            'tmrClock.Interval = tmrClock.Interval * 2\n'
            'If tmrClock.Enabled Then tmrClock.Stop Else tmrClock.Start\n'
            'Debug.Print(tmrClock.Name & tmrClock.Tag)\nEnd Sub\n'),
        isEmpty);
    expect(_codes('Sub P(sender As Timer) Handles tmrClock.Tick\nEnd Sub\n'),
        isEmpty);
  });

  test('events under other versions\' names (A051)', () {
    final d = compile('Sub tmrClock_Timer()\nEnd Sub\n', form: _form)
        .diagnostics
        .single;
    expect(d.code.code, 'A051');
    expect(
        d.message,
        'GuBASIC calls the event tmrClock.Timer differently: it is Tick. '
        'Write tmrClock_Tick.');
    expect(_codes('Sub txtName_TextChanged()\nEnd Sub\n'), ['A051@1']);
    expect(_codes('Sub lstCity_SelectedIndexChanged()\nEnd Sub\n'), ['A051@1']);
    expect(_codes('Sub P() Handles tmrClock.Timer\nEnd Sub\n'), ['A051@1']);
    // Not an event of another version: an ordinary procedure.
    expect(_codes('Sub tmrClock_Tock()\nEnd Sub\n'), isEmpty);
  });

  test('it is put on the form in the designer (A052), and is not a Control',
      () {
    expect(
        _codes('Sub P()\nDim t As New Timer\nt.Start\nEnd Sub\n'), ['A052@2']);
    expect(
        _codes('Sub P()\nDim c As Control = tmrClock\nc.Tag = ""\nEnd Sub\n'),
        ['A008@2']);
  });

  test('Me.Controls leaves it out; it ticks only while Enabled', () async {
    final lines = await runEventScript(
        'Sub Form_Load()\nDebug.Print(Me.Controls.Count)\nEnd Sub\n'
            'Sub tmrClock_Tick()\nDebug.Print("tick")\nEnd Sub\n',
        _form,
        'tmrClock.Tick\nClose');
    expect(lines, [
      'Debug.Print: 2',
      '> tmrClock.Tick',
      'Disabled: tmrClock.Tick',
      '> Close',
      'Closed',
    ]);
  });
}
