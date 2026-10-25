@TestOn('vm')
library;

import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/src/forms/components.g.dart';
import 'package:test/test.dart';

/// Every components/NAME/component.yaml is embedded unchanged in
/// components.g.dart (tool/embed_components.dart) and describes NAME.
void main() {
  final folders = Directory('../../components')
      .listSync()
      .whereType<Directory>()
      .map((d) => d.uri.pathSegments.where((s) => s.isNotEmpty).last)
      .toList()
    ..sort();

  test('the embedded files are the component.yaml files', () {
    expect(builtinComponentFiles.keys.toList()..sort(), folders);
    for (final name in folders) {
      expect(builtinComponentFiles[name],
          File('../../components/$name/component.yaml').readAsStringSync(),
          reason: '$name: run dart run tool/embed_components.dart');
    }
  });

  test('each component is named after its folder', () {
    for (final name in folders) {
      expect(builtinComponents[name.toLowerCase()]?.name, name);
    }
  });

  test('stage 1 built-ins: properties and events (docs/LANGUAGE.md §11)', () {
    String describe(String name) {
      final c = builtinComponents[name.toLowerCase()]!;
      final props = [
        for (final p in c.properties.values)
          '${p.name} As ${p.type.displayName} = ${p.defaultValue}'
      ];
      final events = c.events.values.map((e) => e.handlerSignature('x'));
      return '${props.join(', ')} | ${events.join(', ')} | '
          'default ${c.defaultEvent}';
    }

    expect(
        describe('Form'),
        'Caption As String = , Width As Integer = 480, Height As Integer = 360'
        ' | x_Load() | default Load');
    expect(
        describe('Button'),
        'Caption As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 96, Height As Integer = 32, Anchor As String = Left Top | '
        'x_Click() | '
        'default Click');
    expect(
        describe('Label'),
        'Caption As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 120, Height As Integer = 24, Anchor As String = Left Top | '
        'x_Click() | '
        'default Click');
    expect(
        describe('TextBox'),
        'Text As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 160, Height As Integer = 32, Anchor As String = Left Top | '
        'x_Changed() | '
        'default Changed');
    expect(
        describe('CheckBox'),
        'Caption As String = , Checked As Boolean = false, '
        'Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 120, Height As Integer = 32, Anchor As String = Left Top | '
        'x_Changed() | '
        'default Changed');
    expect(builtinComponents['checkbox']!.properties['checked']!.changeEvent,
        'Changed');
  });

  test('ranges and change events', () {
    final box = builtinComponents['textbox']!;
    expect(box.properties['text']!.changeEvent, 'Changed');
    expect(box.properties['left']!.changeEvent, isNull);
    expect([box.properties['left']!.min, box.properties['left']!.max],
        [integerPropertyMin, integerPropertyMax]);
    for (final c in builtinComponents.values) {
      expect(c.properties['width']!.min, 0, reason: c.name);
      expect(c.properties['height']!.min, 0, reason: c.name);
    }
    expect(
        () => readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
            'properties: [{name: P, type: String, default: "", '
            'changeEvent: B}]\nevents: [A()]\n'),
        throwsFormatException);
    expect(
        () => readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
            'properties: [{name: P, type: Integer, default: -1, min: 0}]\n'
            'events: [A()]\n'),
        throwsFormatException);
  });

  test('Label is drawn in the graphic layer, the others in front (D41)', () {
    expect(builtinComponents['label']!.layer, ComponentLayer.graphic);
    for (final name in ['button', 'textbox', 'checkbox', 'form']) {
      expect(builtinComponents[name]!.layer, ComponentLayer.control,
          reason: name);
    }
    expect(
        () => readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
            'layer: top\nproperties: []\nevents: [A()]\n'),
        throwsFormatException);
  });

  test('methods and property flags (D45)', () {
    final c = readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
        'properties:\n'
        '  - { name: P, type: Integer, default: 0, designTime: false }\n'
        '  - { name: R, type: String, default: "", readOnly: true }\n'
        '  - { name: S, type: List(Of String), default: [a], internal: true }\n'
        'events: [A()]\n'
        'methods:\n'
        '  - Go()\n'
        '  - Get(i As Integer, s As String) As Boolean\n');
    expect(c.designProperties, isEmpty);
    expect(c.properties['r']!.isStored, isFalse);
    expect(c.properties['s']!.defaultValue, ['a']);
    expect(c.methods['get']!.parameters.map((p) => p.name), ['i', 's']);
    expect(c.methods['get']!.returnType, GbType.boolean);
    expect(c.methods['go']!.returnType, GbType.void_);
    String yaml(String rest) =>
        'name: X\nversion: 1\ndefaultEvent: A\nevents: [A()]\n$rest';
    for (final bad in [
      'properties: []\nmethods: [Go]\n',
      'properties: []\nmethods: ["Go() As Thing"]\n',
      'properties: [{name: P, type: String, default: "", readOnly: true, '
          'changeEvent: A}]\n',
      'properties: [{name: P, type: List(Of String), default: []}]\n',
      'properties: [{name: P, type: Integer, default: 0, readOnly: 1}]\n',
    ]) {
      expect(() => readComponentFile(yaml(bad)), throwsFormatException,
          reason: bad);
    }
  });

  test('other names point to members (A036, D50)', () {
    final c = readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
        'properties:\n'
        '  - { name: P, type: Integer, default: 0 }\n'
        '  - { name: S, type: List(Of String), default: [], internal: true }\n'
        'events: [A()]\n'
        'methods: [Go()]\n'
        'otherNames:\n'
        '  Value: P\n'
        '  S: [Go, P]\n');
    expect(c.otherNames, {
      'value': ['P'],
      's': ['Go', 'P'],
    });
    expect(builtinComponents['button']!.otherNames, {
      'text': ['Caption'],
    });
    String yaml(String others) => 'name: X\nversion: 1\ndefaultEvent: A\n'
        'properties: [{ name: P, type: Integer, default: 0 }]\n'
        'events: [A()]\notherNames:\n$others';
    for (final bad in [
      '  P: P\n', // a member already
      '  Value: Nope\n', // not a member
      '  Value: A\n', // an event, not a member
      '  Value: []\n',
      '  Value: 3\n',
    ]) {
      expect(() => readComponentFile(yaml(bad)), throwsFormatException,
          reason: bad);
    }
  });

  test('a broken component.yaml is refused', () {
    expect(
        () => readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
            'properties: []\nevents: [B()]\n'),
        throwsFormatException);
    expect(
        () => readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
            'properties: [{name: P, type: Integer, default: "1"}]\n'
            'events: [A()]\n'),
        throwsFormatException);
  });

  test('event parameters are read', () {
    final c = readComponentFile('name: Scanner\nversion: 1\n'
        'defaultEvent: Detected\nproperties: []\n'
        'events: ["Detected(code As String, count As Integer)"]\n');
    expect(c.events['detected']!.handlerSignature('qr1'),
        'qr1_Detected(code As String, count As Integer)');
  });
}
