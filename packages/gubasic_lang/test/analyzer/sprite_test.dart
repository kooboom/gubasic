import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The Sprite control (docs/DESIGN.md D138) as the analyzer and the form
/// file see it; what it does when it runs is in the parity programs
/// sprite_move and sprite_frames.
void main() {
  final form = readFormFile(
      '''
formatVersion: 1
controls:
  - { name: sprShip, type: Sprite, properties: { Frames: "Ship.png, ship2.png" } }
''',
      name: 'Form1',
      pictures: ['ship.png', 'ship2.png']).form;

  List<String> codes(String source) => [
        for (final d
            in compile(source, form: form, pictures: ['ship.png']).diagnostics)
          '${d.code.code}@${d.line}',
      ];

  test('the form file reads Frames with the project\'s spelling (F016)', () {
    expect(form.control('sprShip')!.valueOf('Frames'), 'ship.png, ship2.png');
    final r = readFormFile(
        '''
formatVersion: 1
controls:
  - { name: sprShip, type: Sprite, properties: { Frames: "ship.png, gone.png" } }
''',
        name: 'Form1',
        pictures: ['ship.png']);
    expect(r.diagnostics.map((d) => d.code.code), ['F016']);
    expect(r.diagnostics.single.message, contains('gone.png'));
  });

  test('its members, and Move', () {
    expect(codes('''
Sub Form_Load()
    sprShip.X = sprShip.X + sprShip.SpeedX / 2
    sprShip.Y = 10
    sprShip.Frame = 1
    sprShip.FrameTime = 80
    sprShip.Move(16)
    Dim s As New Sprite With {.Frames = "ship.png", .SpeedY = -400}
    Me.Controls.Add(s)
End Sub
'''), isEmpty);
  });

  test('each name in Frames written as text is checked (A037)', () {
    expect(
        codes('Sub Form_Load()\n'
            'sprShip.Frames = "ship.png, gone.png, other.png"\n'
            'End Sub\n'),
        ['A037@2', 'A037@2']);
  });

  test('the component: pictures, X and Y not in the designer, no colour', () {
    final c = builtinComponents['sprite']!;
    expect(c.properties['frames']!.pictures, isTrue);
    expect(c.properties['x']!.designTime, isFalse);
    expect(c.properties['fracx']!.internal, isTrue);
    expect(c.properties.containsKey('backcolor'), isFalse);
    expect(c.layer, ComponentLayer.graphic);
    expect(c.methods['move']!.parameters.single.name, 'ms');
    expect(splitPictureNames(' a.png ,, b.png,'), ['a.png', 'b.png']);
    expect(joinPictureNames(['a.png', 'b.png']), 'a.png, b.png');
  });
}
