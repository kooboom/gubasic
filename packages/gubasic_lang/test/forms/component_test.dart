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
        'Width As Integer = 96, Height As Integer = 32 | x_Click() | '
        'default Click');
    expect(
        describe('Label'),
        'Caption As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 120, Height As Integer = 24 | x_Click() | '
        'default Click');
    expect(
        describe('TextBox'),
        'Text As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 160, Height As Integer = 32 | x_Changed() | '
        'default Changed');
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
