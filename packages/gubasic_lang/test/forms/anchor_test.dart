import 'dart:math';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

void main() {
  group('normalAnchor', () {
    test('names the edges in one order, each once', () {
      expect(normalAnchor('Left Top'), 'Left Top');
      expect(normalAnchor('bottom, RIGHT'), 'Right Bottom');
      expect(normalAnchor('  top  top left '), 'Left Top');
      expect(normalAnchor('Bottom Right Top Left'), 'Left Top Right Bottom');
      expect(normalAnchor(''), '');
      expect(normalAnchor(' , '), '');
    });

    test('null for a word that is not an edge', () {
      expect(normalAnchor('Rihgt'), isNull);
      expect(normalAnchor('Left Middle'), isNull);
      expect(normalAnchor('None'), isNull);
    });
  });

  group('anchoredRect', () {
    const base = (left: 100, top: 50, width: 80, height: 20);
    AnchorRect at(String anchor, int width, int height) => anchoredRect(
          base,
          anchor,
          baseWidth: 300,
          baseHeight: 200,
          width: width,
          height: height,
        );

    test('keeps the distance to the edges it names', () {
      expect(at('Left Top', 400, 260), base);
      expect(at('Right Bottom', 400, 260),
          (left: 200, top: 110, width: 80, height: 20));
      expect(at('Left Right', 400, 260),
          (left: 100, top: 80, width: 180, height: 20));
      expect(at('Left Top Right Bottom', 250, 150),
          (left: 100, top: 50, width: 30, height: 0));
    });

    test('with no edge, moves half as much, rounded down', () {
      expect(at('', 400, 260), (left: 150, top: 80, width: 80, height: 20));
      expect(at('', 301, 199), (left: 100, top: 49, width: 80, height: 20));
      expect(at('', 299, 201), (left: 99, top: 50, width: 80, height: 20));
    });

    test(
        'a size made larger or smaller and then as it was puts the control '
        'back exactly', () {
      final random = Random(7);
      const anchors = [
        '',
        'Left Top',
        'Right',
        'Bottom',
        'Left Right',
        'Top Bottom',
        'Left Top Right Bottom'
      ];
      for (var i = 0; i < 500; i++) {
        final anchor = anchors[random.nextInt(anchors.length)];
        final w = random.nextInt(1200), h = random.nextInt(1200);
        // Going there and back is worked out from the same base.
        at(anchor, w, h);
        expect(at(anchor, 300, 200), base);
      }
    });
  });

  group('form file', () {
    String form(String anchor) => 'formatVersion: 1\ncontrols:\n'
        '  - name: btnOk\n    type: Button\n'
        '    properties:\n      Anchor: $anchor\n';

    test(
        'Anchor is read as normalAnchor keeps it, and written only when '
        'not the default', () {
      final r = readFormFile(form('"bottom, right"'), name: 'Form1');
      expect(r.diagnostics, isEmpty);
      expect(r.form.controls.single.valueOf('Anchor'), 'Right Bottom');
      expect(writeFormFile(r.form), contains('Anchor: Right Bottom'));

      final drawn = readFormFile(form('top left'), name: 'Form1');
      expect(drawn.form.controls.single.valueOf('Anchor'), defaultAnchor);
      expect(writeFormFile(drawn.form), isNot(contains('Anchor')));

      final none = readFormFile(form('""'), name: 'Form1');
      expect(none.form.controls.single.valueOf('Anchor'), '');
      expect(writeFormFile(none.form), contains('Anchor: ""'));
    });

    test('a word that is not an edge is F017', () {
      final r = readFormFile(form('Rihgt'), name: 'Form1');
      expect(r.diagnostics.map((d) => '${d.code.code}@${d.line}'), ['F017@6']);
      expect(
          r.diagnostics.single.formatMessage(koreanMessages),
          '"Rihgt" 값은 Anchor 값이 아닙니다. 폼의 가장자리를 "Right Bottom"처럼 '
          'Left, Top, Right, Bottom으로 적거나, 없으면 ""로 적어 주세요.');
    });
  });

  group('code', () {
    final form = readFormFile(
            'formatVersion: 1\ncontrols:\n  - { name: btnOk, type: Button }\n',
            name: 'Form1')
        .form;
    List<String> codes(String body) =>
        compile('Sub W()\n$body\nEnd Sub\n', form: form)
            .diagnostics
            .map((d) => d.code.code)
            .toList();

    test('text with a word that is not an edge is a warning (A038)', () {
      expect(codes('btnOk.Anchor = "Right Botom"'), ['A038']);
      expect(codes('btnOk.Anchor = "right, bottom"'), isEmpty);
      expect(codes('btnOk.Anchor = ""'), isEmpty);
      expect(codes('Dim a As String = "x"\nbtnOk.Anchor = a'), isEmpty);
    });

    test(
        'setting it to such text stops the program (R014); good text is '
        'kept as normalAnchor gives it', () async {
      const source = 'Sub btnOk_Click()\n'
          '    btnOk.Anchor = "bottom right"\n'
          '    Debug.Print("[" & btnOk.Anchor & "]")\n'
          '    Dim a As String = "Middle"\n'
          '    btnOk.Anchor = a\n'
          'End Sub\n';
      expect(await runEventScript(source, form, 'btnOk.Click'), [
        '> btnOk.Click',
        'Set btnOk.Anchor: Right Bottom',
        'Debug.Print: [Right Bottom]',
        'Error R014 @ 5',
      ]);
    });
  });

  test('an anchor property is a String whose default names edges', () {
    String yaml(String p) => 'name: X\nversion: 1\ndefaultEvent: A\n'
        'properties: [$p]\nevents: [A()]\n';
    expect(
        readComponentFile(yaml(
                '{ name: Anchor, type: String, default: "Left Top", anchor: true }'))
            .properties['anchor']!
            .anchor,
        isTrue);
    for (final bad in [
      '{ name: Anchor, type: Integer, default: 0, anchor: true }',
      '{ name: Anchor, type: String, default: "top left", anchor: true }',
      '{ name: Anchor, type: String, default: "Up", anchor: true }',
    ]) {
      expect(() => readComponentFile(yaml(bad)), throwsFormatException,
          reason: bad);
    }
  });

  test('every control has Anchor, Left Top by default', () {
    for (final name in [
      'Button',
      'Label',
      'TextBox',
      'CheckBox',
      'ListBox',
      'Image'
    ]) {
      final anchor =
          builtinComponents[name.toLowerCase()]!.properties['anchor'];
      expect(anchor?.anchor, isTrue, reason: name);
      expect(anchor?.defaultValue, defaultAnchor, reason: name);
    }
    expect(builtinComponents['form']!.properties['anchor'], isNull);
  });
}
