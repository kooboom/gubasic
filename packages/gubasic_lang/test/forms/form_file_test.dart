import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// `code@line:column` for every diagnostic of a form file.
List<String> diagnose(String text) => readFormFile(text, name: 'Form1')
    .diagnostics
    .map((d) => '${d.code.code}@${d.line}:${d.column}')
    .toList();

void main() {
  const valid = '''
formatVersion: 1
properties:
  Caption: Score Book
  Width: 400
controls:
  - name: lblTitle
    type: Label
    properties:
      Caption: Welcome
      Left: 8
  - name: txtName
    type: TextBox
''';

  test('a form, its properties and controls', () {
    final r = readFormFile(valid, name: 'Form1');
    expect(r.diagnostics, isEmpty);
    final form = r.form;
    expect(form.name, 'Form1');
    expect(form.valueOf('Caption'), 'Score Book');
    expect(form.valueOf('width'), 400);
    expect(form.valueOf('Height'), 360, reason: 'the default');
    expect(form.controls.map((c) => '${c.name}: ${c.component.name}'),
        ['lblTitle: Label', 'txtName: TextBox']);
    final title = form.control('LBLTITLE')!;
    expect(title.line, 6);
    expect(title.valueOf('Caption'), 'Welcome');
    expect(title.valueOf('Left'), 8);
    expect(title.valueOf('Width'), 120);
    expect(form.control('txtName')!.valueOf('Text'), '');
    expect(form.control('nothing'), isNull);
  });

  test('property and key names are not case-sensitive', () {
    final r = readFormFile(
        'FormatVersion: 1\nControls:\n  - Name: b\n    TYPE: button\n'
        '    Properties: { caption: OK, LEFT: 3 }\n',
        name: 'F');
    expect(r.diagnostics, isEmpty);
    final b = r.form.controls.single;
    expect(b.component.name, 'Button');
    expect(b.properties, {'Caption': 'OK', 'Left': 3});
  });

  test('a String property takes a single value as it is written', () {
    final r = readFormFile(
        'formatVersion: 1\ncontrols:\n'
        '  - { name: a, type: Label, properties: { Caption: 2026 } }\n'
        '  - { name: b, type: Label, properties: { Caption: true } }\n'
        '  - { name: c, type: Label, properties: { Caption: } }\n'
        '  - { name: d, type: Label, properties: { Caption: "07" } }\n',
        name: 'F');
    expect(r.diagnostics, isEmpty);
    expect(r.form.controls.map((c) => c.valueOf('Caption')),
        ['2026', 'true', '', '07']);
  });

  test('an empty form', () {
    final r = readFormFile('formatVersion: 1\n', name: 'F');
    expect(r.diagnostics, isEmpty);
    expect(r.form.controls, isEmpty);
  });

  test('F001: not readable', () {
    expect(
        diagnose('formatVersion: 1\ncontrols:\n  - name: [a\n'), ['F001@4:1']);
    expect(diagnose('just text\n'), ['F001@1:1']);
  });

  test('F002: formatVersion missing or not a number; the rest is read', () {
    expect(diagnose(''), ['F002@1:1']);
    expect(diagnose('formatVersion: one\n'), ['F002@1:16']);
    final r =
        readFormFile('controls:\n  - { name: a, type: Label }\n', name: 'F');
    expect(r.diagnostics.map((d) => d.code.code), ['F002']);
    expect(r.form.controls, hasLength(1));
  });

  test('F003: newer than this GuBASIC; nothing else is read', () {
    final r = readFormFile(
        'formatVersion: 4\ncontrols:\n  - { name: a, type: Lable }\n',
        name: 'F');
    expect(
        r.diagnostics.map((d) => '${d.code.code} ${d.args}'), ['F003 [4, 3]']);
    expect(r.form.controls, isEmpty);
  });

  test('F004: an unknown key is a warning and is ignored', () {
    final r = readFormFile('formatVersion: 1\ncolor: red\n', name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), ['F004@2']);
    expect(r.hasErrors, isFalse);
  });

  test('F005: a value in the wrong form', () {
    expect(diagnose('formatVersion: 1\ncontrols: btnOk\n'), ['F005@2:11']);
    expect(diagnose('formatVersion: 1\ncontrols:\n  - btnOk\n'), ['F005@3:5']);
    expect(diagnose('formatVersion: 1\nproperties: big\n'), ['F005@2:13']);
    expect(diagnose('formatVersion: 1\ncontrols:\n  - name: a\n'), ['F005@3:5'],
        reason: 'type is missing');
  });

  test('F006: a missing or unusable name', () {
    expect(
        diagnose('formatVersion: 1\ncontrols:\n'
            '  - { type: Label }\n'
            '  - { name: Dim, type: Label }\n'
            '  - { name: Form, type: Label }\n'
            '  - { name: 버튼, type: Label }\n'
            '  - { name: 1st, type: Label }\n'
            '  - { name: _x, type: Label }\n'),
        [
          'F006@3:5',
          'F006@4:13',
          'F006@5:13',
          'F006@6:13',
          'F006@7:13',
          'F006@8:13'
        ]);
  });

  test('F007: two controls with the same name, in any case', () {
    final r = readFormFile(
        'formatVersion: 1\ncontrols:\n'
        '  - { name: btnOk, type: Button }\n'
        '  - { name: BTNOK, type: Label }\n',
        name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line} ${d.args}'),
        ['F007@4 [BTNOK, 3]']);
    expect(r.form.controls, hasLength(1));
  });

  test('F008: an unknown control type, Form included', () {
    final r = readFormFile(
        'formatVersion: 1\ncontrols:\n'
        '  - { name: a, type: Buton }\n'
        '  - { name: b, type: Form }\n',
        name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'),
        ['F008@3', 'F008@4']);
    expect(r.diagnostics.first.args, [
      'Buton',
      'Button, CheckBox, ComboBox, Frame, Image, Label, ListBox, OpenFileDialog, OptionButton, '
          'SaveFileDialog, TextBox, Timer',
    ]);
    expect(r.form.controls, isEmpty);
  });

  test('F009: a property the type does not have', () {
    final r = readFormFile(
        'formatVersion: 1\nproperties: { Left: 1 }\ncontrols:\n'
        '  - { name: t, type: TextBox, properties: { Caption: Hi } }\n',
        name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code}@${d.line} ${d.args}'), [
      'F009@2 [Left, Form, Caption, Width, Height, Tag, KeyPreview]',
      'F009@4 [Caption, TextBox, Text, Left, Top, Width, Height, Anchor, Tag]',
    ]);
    expect(r.form.controls.single.properties, isEmpty,
        reason: 'the control is kept without it');
  });

  test('F010: a property value of the wrong type', () {
    final r = readFormFile(
        'formatVersion: 1\ncontrols:\n'
        '  - { name: b, type: Button, properties: { Left: 1.5, Top: x } }\n',
        name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code} ${d.args}'),
        ['F010 [Left, Integer]', 'F010 [Top, Integer]']);
    expect(r.form.controls.single.valueOf('Left'), 0);
  });

  test('F012: an Integer property value outside its range', () {
    final r = readFormFile(
        'formatVersion: 1\ncontrols:\n'
        '  - { name: b, type: Button, properties: { Width: -1, '
        'Left: 2147483648, Top: -2147483648 } }\n',
        name: 'F');
    expect(r.diagnostics.map((d) => '${d.code.code} ${d.args}'), [
      'F012 [Width, 0, 2147483647]',
      'F012 [Left, -2147483648, 2147483647]',
    ]);
    expect(r.form.controls.single.properties, {'Top': -2147483648});
  });

  test('messages exist in both languages', () {
    final d = readFormFile(
            'formatVersion: 1\ncontrols:\n'
            '  - { name: a, type: Buton }\n',
            name: 'F')
        .diagnostics
        .single;
    expect(d.message, contains('Buton'));
    expect(d.formatMessage(koreanMessages), contains('Buton 컨트롤 타입이'));
  });
}
