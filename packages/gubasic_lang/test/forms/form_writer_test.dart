import 'dart:io';
import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// A form with one Label whose Caption is [caption].
FormFile labelWith(String caption) => FormFile(
      name: 'Form1',
      properties: {},
      controls: [
        ControlDecl(
            name: 'lblText',
            component: builtinComponents['label']!,
            properties: {'Caption': caption},
            line: 0),
      ],
    );

/// [form] written, then read back; fails on any diagnostic.
FormFile roundTrip(FormFile form) {
  final r = readFormFile(writeFormFile(form), name: form.name);
  expect(r.diagnostics, isEmpty, reason: writeFormFile(form));
  return r.form;
}

void main() {
  for (final example in ['hello', 'typing']) {
    test('examples/$example/Form1.form.yaml is written back byte for byte', () {
      final text =
          File('../../examples/$example/Form1.form.yaml').readAsStringSync();
      final form = readFormFile(text, name: 'Form1');
      expect(form.diagnostics, isEmpty);
      expect(writeFormFile(form.form), text);
    });
  }

  test('an empty form is only its version', () {
    expect(writeFormFile(FormFile(name: 'Form1', properties: {}, controls: [])),
        'formatVersion: 1\n');
  });

  test('defaults are left out, the rest in component.yaml order', () {
    final form = FormFile(
      name: 'Form1',
      properties: {'height': 200, 'Width': 480, 'caption': 'Quiz'},
      controls: [
        ControlDecl(
            name: 'btnOk',
            component: builtinComponents['button']!,
            properties: {'Height': 40, 'Width': 96, 'Top': -8, 'Caption': ''},
            line: 0),
        ControlDecl(
            name: 'txtName',
            component: builtinComponents['textbox']!,
            properties: {},
            line: 0),
      ],
    );
    expect(writeFormFile(form), '''
formatVersion: 1
properties:
  Caption: Quiz
  Height: 200
controls:
  - name: btnOk
    type: Button
    properties:
      Top: -8
      Height: 40
  - name: txtName
    type: TextBox
''');
    final back = roundTrip(form);
    expect(back.valueOf('Width'), 480);
    expect(back.control('btnOk')!.valueOf('Top'), -8);
  });

  test('the Integer range is written as it is', () {
    final form = FormFile(name: 'Form1', properties: {}, controls: [
      ControlDecl(
          name: 'lblFar',
          component: builtinComponents['label']!,
          properties: {
            'Left': integerPropertyMin,
            'Top': integerPropertyMax,
            'Width': 0,
          },
          line: 0),
    ]);
    final back = roundTrip(form).control('lblFar')!;
    expect(back.valueOf('Left'), integerPropertyMin);
    expect(back.valueOf('Top'), integerPropertyMax);
    expect(back.valueOf('Width'), 0);
  });

  test('a hand-written file comes back in the one written layout', () {
    const hand = '''
# The quiz form
formatVersion: 1
controls:
  - type: label     # the title
    NAME: lblTitle
    properties: {top: 8, CAPTION: "Quiz"}
properties:
  width: 320
''';
    expect(writeFormFile(readFormFile(hand, name: 'Form1').form), '''
formatVersion: 1
properties:
  Width: 320
controls:
  - name: lblTitle
    type: Label
    properties:
      Caption: Quiz
      Top: 8
''');
  });

  group('text is quoted only where YAML needs it', () {
    const plain = [
      'Hello',
      'Say hello',
      '안녕하세요',
      'a:b',
      'C#',
      'x-y',
      '100%',
      'Hello, world!',
      'it\'s',
      'say "hi"',
      '😀',
    ];
    for (final text in plain) {
      test(text, () {
        expect(writeFormFile(labelWith(text)), contains('Caption: $text\n'));
        expect(roundTrip(labelWith(text)).controls.single.valueOf('Caption'),
            text);
      });
    }

    const quoted = {
      '2026': '"2026"',
      '1.5': '"1.5"',
      '0x1F': '"0x1F"',
      'true': '"true"',
      'False': '"False"',
      'null': '"null"',
      '~': '"~"',
      ' leading': '" leading"',
      'trailing ': '"trailing "',
      'a: b': '"a: b"',
      '이름: 홍길동': '"이름: 홍길동"',
      '\u2029': r'"\u2029"',
      'a #b': '"a #b"',
      '#hash': '"#hash"',
      '- item': '"- item"',
      '[x]': '"[x]"',
      '{x}': '"{x}"',
      '"q"': r'"\"q\""',
      "'q'": '"\'q\'"',
      'x:': '"x:"',
      '? x': '"? x"',
      '!tag': '"!tag"',
      '&anchor': '"&anchor"',
      '*alias': '"*alias"',
      '|': '"|"',
      '>': '">"',
      '@at': '"@at"',
      '`tick': '"`tick"',
      '%pct': '"%pct"',
      'two\nlines': r'"two\nlines"',
      'tab\there': r'"tab\there"',
      r'back\slash ': r'"back\\slash "',
      'bell\u0007': r'"bell\u0007"',
      '\u2028': r'"\u2028"',
    };
    for (final MapEntry(key: text, value: written) in quoted.entries) {
      test(written, () {
        expect(writeFormFile(labelWith(text)), contains('Caption: $written\n'));
        expect(roundTrip(labelWith(text)).controls.single.valueOf('Caption'),
            text);
      });
    }
  });

  test('any text reads back as itself', () {
    const alphabet = ' \t\n\r:#-[]{}"\'\\,?!&*|>@`%~ab1.가😀\u0085\u00a0\ufeff';
    final random = Random(14);
    for (var i = 0; i < 2000; i++) {
      final runes = alphabet.runes.toList();
      final text = String.fromCharCodes([
        for (var n = random.nextInt(8) + 1; n > 0; n--)
          runes[random.nextInt(runes.length)]
      ]);
      expect(
          roundTrip(labelWith(text)).controls.single.valueOf('Caption'), text,
          reason: writeFormFile(labelWith(text)));
    }
  });

  test('a name YAML would misread is quoted', () {
    final form = FormFile(name: 'Form1', properties: {}, controls: [
      ControlDecl(
          name: 'null',
          component: builtinComponents['button']!,
          properties: {},
          line: 0),
    ]);
    expect(writeFormFile(form), contains('- name: "null"\n'));
  });
}
