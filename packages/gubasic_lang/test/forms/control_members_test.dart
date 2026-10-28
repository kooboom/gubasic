import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// Control methods, read-only and run-time-only properties (docs/DESIGN.md
/// D45), with the ListBox (D46). Its behaviour while a program runs is in
/// the parity program events_listbox.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: lstCity, type: ListBox }
''', name: 'Form1').form;

List<String> _codes(String body) => [
      for (final d in compile('Sub Form_Load()\n$body\nEnd Sub\n', form: _form)
          .diagnostics)
        d.code.code,
    ];

Future<String> _run(String body) async =>
    (await runEventScript('Sub Form_Load()\n$body\nEnd Sub\n', _form, 'Close'))
        .last;

void main() {
  test('the ListBox in its component.yaml', () {
    final c = builtinComponents['listbox']!;
    expect(c.defaultEvent, 'Changed');
    expect(c.designProperties.map((p) => p.name),
        ['Left', 'Top', 'Width', 'Height', 'Anchor', 'Tag']);
    expect(c.properties['listindex']!.changeEvent, 'Changed');
    expect(c.properties['listindex']!.designTime, isFalse);
    expect(c.properties['listcount']!.readOnly, isTrue);
    expect(c.properties['listcount']!.isStored, isFalse);
    expect(c.properties['items']!.internal, isTrue);
    expect(
        c.methods.values.map((m) => '${m.name}(${[
              for (final p in m.parameters)
                '${p.name} As ${p.type!.displayName}'
            ].join(', ')}) As ${m.returnType.displayName}'),
        [
          'AddItem(item As String) As (no value)',
          'RemoveItem(index As Integer) As (no value)',
          'Clear() As (no value)',
          'List(index As Integer) As String',
        ]);
  });

  test('methods are checked like other calls', () {
    expect(_codes('lstCity.AddItem("Seoul")\nlstCity.Clear\nlstCity.Clear()'),
        isEmpty);
    expect(_codes('Debug.Print(lstCity.List(0))'), isEmpty);
    expect(_codes('lstCity.RemoveItem("one")'), ['A009']);
    expect(_codes('lstCity.AddItem()'), ['A015']);
  });

  test('read-only properties cannot be given a value (A034)', () {
    expect(_codes('lstCity.ListCount = 3'), ['A034']);
    expect(_codes('lstCity.Text = "Seoul"'), ['A034']);
    expect(_codes('lstCity.ListIndex = 0'), isEmpty);
    expect(
        _codes('Dim names As New List(Of String)\nnames.Count = 0'), ['A034']);
  });

  test('the items are not a property programs see', () {
    // Pointed to the methods that reach them (A036).
    expect(_codes('Debug.Print(lstCity.Items)'), ['A036']);
  });

  test('the form file sets only design-time properties (F013, F009)', () {
    List<String> codes(String props) => [
          for (final d in readFormFile(
                  'formatVersion: 1\ncontrols:\n'
                  '  - { name: lstCity, type: ListBox, properties: '
                  '{ $props } }\n',
                  name: 'Form1')
              .diagnostics)
            d.code.code,
        ];
    expect(codes('Top: 8'), isEmpty);
    expect(codes('ListIndex: 0'), ['F013']);
    expect(codes('ListCount: 3'), ['F013']);
    expect(codes('Items: x'), ['F009']);
  });

  test('ListIndex must name an item, or be -1', () async {
    expect(await _run('lstCity.AddItem("Seoul")\nlstCity.ListIndex = 0'),
        'Closed');
    expect(await _run('lstCity.AddItem("Seoul")\nlstCity.ListIndex = 1'),
        'Error R003 @ 3');
    expect(await _run('lstCity.ListIndex = -2'), 'Error R010 @ 2');
    expect(await _run('lstCity.RemoveItem(0)'), 'Error R003 @ 2');
  });

  test('methods with arguments through an Object', () async {
    expect(await runEventScript('''
Sub Form_Load()
    Dim names As New List(Of Integer)
    Dim o As Object = names
    o.Add(3)
    Dim s As Object = "abc"
    Debug.Print(o.Count & " " & o(0) & " " & s.Substring(1))
End Sub
''', _form, 'Close'), ['Debug.Print: 1 3 bc', '> Close', 'Closed']);
  });
}
