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
        'Caption As String = , Width As Integer = 480, Height As Integer = 360, '
        'FontSize As Double = (unset), FontBold As Boolean = (unset), '
        'ForeColor As Color = (unset), BackColor As Color = (unset), '
        'Tag As String = , KeyPreview As Boolean = false, '
        'DialogResult As Integer = 0 | x_Load(), '
        'x_Resize(), x_Closed(), x_KeyDown(e As KeyEventArgs), '
        'x_KeyUp(e As KeyEventArgs), x_MouseDown(e As MouseEventArgs), '
        'x_MouseUp(e As MouseEventArgs) | default Load');
    expect(
        describe('Button'),
        'Caption As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 96, Height As Integer = 32, Anchor As String = Left Top, '
        'Enabled As Boolean = true, Visible As Boolean = true, FontSize As Double = (unset), FontBold As Boolean = (unset), ForeColor As Color = (unset), BackColor As Color = (unset), '
        'Tag As String =  | '
        'x_Click(), x_MouseDown(e As MouseEventArgs), '
        'x_MouseUp(e As MouseEventArgs) | '
        'default Click');
    expect(
        describe('Label'),
        'Caption As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 120, Height As Integer = 24, Anchor As String = Left Top, '
        'Enabled As Boolean = true, Visible As Boolean = true, FontSize As Double = (unset), FontBold As Boolean = (unset), ForeColor As Color = (unset), BackColor As Color = (unset), '
        'Tag As String =  | '
        'x_Click(), x_MouseDown(e As MouseEventArgs), '
        'x_MouseUp(e As MouseEventArgs) | '
        'default Click');
    expect(
        describe('TextBox'),
        'Text As String = , Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 160, Height As Integer = 32, Anchor As String = Left Top, '
        'Enabled As Boolean = true, Visible As Boolean = true, FontSize As Double = (unset), FontBold As Boolean = (unset), ForeColor As Color = (unset), BackColor As Color = (unset), '
        'Tag As String =  | '
        'x_Changed(), x_MouseDown(e As MouseEventArgs), '
        'x_MouseUp(e As MouseEventArgs) | '
        'default Changed');
    expect(
        describe('CheckBox'),
        'Caption As String = , Checked As Boolean = false, '
        'Left As Integer = 0, Top As Integer = 0, '
        'Width As Integer = 120, Height As Integer = 32, Anchor As String = Left Top, '
        'Enabled As Boolean = true, Visible As Boolean = true, FontSize As Double = (unset), FontBold As Boolean = (unset), ForeColor As Color = (unset), BackColor As Color = (unset), '
        'Tag As String =  | '
        'x_Changed(), x_MouseDown(e As MouseEventArgs), '
        'x_MouseUp(e As MouseEventArgs) | '
        'default Changed');
    expect(builtinComponents['checkbox']!.properties['checked']!.changeEvent,
        'Changed');
  });

  test('Http is a built-in object through the component channel (D125)', () {
    final http = builtinComponents['http']!;
    expect(http.object, isTrue);
    expect(http.visual, isFalse);
    expect(http.platforms, ['web', 'macos', 'windows']);
    expect(http.defaultEvent, '');
    expect(http.events, isEmpty);
    expect(controlComponents.containsKey('http'), isFalse);
    expect(objectComponents.keys, ['database', 'http', 'sound']);
    expect(lookupNamedType('http'), isNull);
    expect([for (final m in http.methods.values) m.name],
        ['Get', 'Post', 'GetJson', 'PostJson', 'Send', 'Header']);
    expect(http.methods['send']!.returnType, GbType.httpResponse);
    expect(http.methods['postjson']!.parameters[1].type, GbType.json);
    expect(http.methods['header']!.settable, isTrue);
    expect(http.properties['timeout']!.defaultValue, 30);
    expect(builtinObjectMembers('Http').keys,
        ['timeout', 'get', 'post', 'getjson', 'postjson', 'send', 'header']);
    // An object is not visual, and only an object names its platforms.
    expect(
        () => readComponentFile('name: X\nversion: 1\nobject: true\n'
            'visual: true\nproperties: []\nevents: []\n'),
        throwsFormatException);
    expect(
        () => readComponentFile('name: X\nversion: 1\ndefaultEvent: A\n'
            'platforms: [web]\nproperties: []\nevents: [A()]\n'),
        throwsFormatException);
    expect(
        () => readComponentFile('name: X\nversion: 1\nobject: true\n'
            'platforms: [linux]\nproperties: []\nevents: []\n'),
        throwsFormatException);
  });

  test('Database takes the SQL and then any values (ParamArray, D126)', () {
    final db = builtinComponents['database']!;
    expect(db.object, isTrue);
    expect(db.platforms, ['web', 'macos', 'windows']);
    expect([for (final m in db.methods.values) m.name],
        ['Open', 'Execute', 'Query', 'Scalar', 'Close', 'Export', 'Import']);
    final execute = db.methods['execute']!;
    expect(execute.parameters.map((p) => p.name), ['sql', 'values']);
    expect(execute.parameters.last.variadic, isTrue);
    expect(execute.parameters.last.kind, ArgKind.sqlValue);
    expect(execute.returnType, GbType.integer);
    expect(db.methods['query']!.returnType, GbType.table);
    expect(db.methods['scalar']!.returnType, GbType.string);
    expect(db.methods['close']!.parameters, isEmpty);
    expect(db.properties['path']!.readOnly, isTrue);
    expect(db.properties['lastwasnull']!.type, GbType.boolean);
    expect(db.properties['lastid']!.type, GbType.integer);
    expect(db.otherNames['openrecordset'], ['Query']);
    // ParamArray takes Value or String (D135), and comes last.
    expect(
        () => readComponentFile('name: X\nversion: 1\nobject: true\n'
            'properties: []\nevents: []\n'
            'methods: [A(ParamArray v As Value, b As String)]\n'),
        throwsFormatException);
    expect(
        () => readComponentFile('name: X\nversion: 1\nobject: true\n'
            'properties: []\nevents: []\n'
            'methods: [A(ParamArray v As Integer)]\n'),
        throwsFormatException);
    final send = readComponentFile('name: X\nversion: 1\nobject: true\n'
            'properties: []\nevents: []\n'
            'methods:\n  - A(b As String, ParamArray h As String)\n')
        .methods['a']!;
    expect(send.parameters.last.variadic, isTrue);
    expect(send.parameters.last.kind, ArgKind.typed);
    expect(send.parameters.last.type, GbType.string);
  });

  test('ranges and change events', () {
    final box = builtinComponents['textbox']!;
    expect(box.properties['text']!.changeEvent, 'Changed');
    expect(box.properties['left']!.changeEvent, isNull);
    expect([box.properties['left']!.min, box.properties['left']!.max],
        [integerPropertyMin, integerPropertyMax]);
    for (final c in builtinComponents.values.where((c) => c.visual)) {
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

  test('pictures under Labels, Labels under the others (D41, D139)', () {
    expect(builtinComponents['image']!.layer, ComponentLayer.picture);
    expect(builtinComponents['sprite']!.layer, ComponentLayer.picture);
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
      'index': ['Tag'],
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
