import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A Sprite (docs/DESIGN.md D138): the frame of its Frames that Frame
/// names, drawn filling it; nothing without frames; its name outlined
/// in the designer; mirrored about its middle with FlipX (D139).
void main() {
  // A 1 x 1 PNG, the smallest picture that decodes.
  final png = Uint8List.fromList([
    0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x48, 0x44, 0x52, //
    0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01, //
    0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, //
    0x00, 0x00, 0x00, 0x0D, 0x49, 0x44, 0x41, 0x54, //
    0x78, 0x9C, 0x63, 0x60, 0x60, 0x60, 0xF8, 0x0F, 0x00, 0x01, 0x04, 0x01, //
    0x00, 0x5C, 0xCD, 0xFF, 0x69, //
    0x00, 0x00, 0x00, 0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82, //
  ]);

  GbControlState sprite(String frames, int frame) =>
      GbControlState('sprShip', GbControlKind.sprite, {
        'Frames': frames, 'Frame': frame, 'Left': 10, 'Top': 20, //
        'Width': 64, 'Height': 64,
      }, layer: GbLayer.picture);

  Future<GbFormModel> pump(
    WidgetTester tester,
    GbControlState state, {
    bool designing = false,
  }) async {
    final model = GbFormModel(
      form: {'Caption': '', 'Width': 200, 'Height': 100},
      controls: [state],
      onEvent: (_, _) {},
      designing: designing,
      pictures: (name) => name == 'ship.png' ? png : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GbFormView(model: model)),
      ),
    );
    await tester.pump();
    return model;
  }

  testWidgets('draws the frame Frame names, filling it', (tester) async {
    final state = sprite('boom.png, ship.png', 1);
    await pump(tester, state);
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.fit, BoxFit.fill);
    expect(tester.getSize(find.byType(GbSprite)), const Size(64, 64));
    expect(find.byType(GbMissingPicture), findsNothing);
    // The first frame is a picture the project does not have.
    state.set('Frame', 0);
    await tester.pump();
    expect(find.byType(Image), findsNothing);
    expect(find.byType(GbMissingPicture), findsOneWidget);
    expect(find.text('boom.png'), findsOneWidget);
  });

  testWidgets('nothing without frames; its name in the designer', (
    tester,
  ) async {
    await pump(tester, sprite('', 0));
    expect(find.byType(Image), findsNothing);
    expect(find.byType(GbMissingPicture), findsNothing);
    await pump(tester, sprite('', 0), designing: true);
    expect(find.text('sprShip'), findsOneWidget);
  });

  test('the names in Frames', () {
    expect(gbFrameNames(' a.png , b.png,, '), ['a.png', 'b.png']);
    expect(gbFrameNames(''), isEmpty);
  });

  testWidgets('FlipX mirrors the frame about its middle, in the same place', (
    tester,
  ) async {
    final state = sprite('ship.png', 0);
    await pump(tester, state);
    final before = tester.getRect(find.byType(GbSprite));
    Matrix4 transform() => tester
        .widget<Transform>(
          find.ancestor(
            of: find.byType(Image),
            matching: find.byType(Transform),
          ),
        )
        .transform;
    expect(transform().isIdentity(), isTrue);
    state.set('FlipX', true);
    await tester.pump();
    // x' = -x about the middle: a scale of -1 across, nothing else.
    final m = transform();
    expect(m.entry(0, 0), -1);
    expect(m.entry(1, 1), 1);
    expect(tester.getRect(find.byType(GbSprite)), before);
    final image = tester.getRect(find.byType(Image));
    expect(image, before, reason: 'the frame fills the same rectangle');
    state.set('FlipX', false);
    await tester.pump();
    expect(transform().isIdentity(), isTrue);
  });
}
