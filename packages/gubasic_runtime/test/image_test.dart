import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A 1 x 1 PNG.
final _png = base64Decode(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mP8z8BQ'
  'DwAEhQGAhKmMIQAAAABJRU5ErkJggg==',
);

void main() {
  late GbFormModel model;
  late List<String> events;

  Future<GbControlState> show(
    WidgetTester tester, {
    String picture = '',
    bool designing = false,
  }) async {
    events = [];
    final image = GbControlState('imgShape', GbControlKind.image, {
      'Picture': picture, 'Stretch': false, 'Left': 10, 'Top': 10, //
      'Width': 100, 'Height': 60,
    }, layer: GbLayer.graphic);
    model = GbFormModel(
      form: {'Caption': 'Shapes', 'Width': 320, 'Height': 120},
      controls: [image],
      onEvent: (c, e) => events.add('$c.$e'),
      designing: designing,
      // The IDE looks names up in any case; this fake knows one.
      pictures: (name) => name.toLowerCase() == 'triangle.png'
          ? Uint8List.fromList(_png)
          : null,
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: GbFormView(model: model)),
      ),
    );
    return image;
  }

  testWidgets('shows the picture, fitted whole or stretched', (tester) async {
    final image = await show(tester, picture: 'triangle.png');
    Image shown() => tester.widget<Image>(find.byType(Image));
    expect(shown().fit, BoxFit.contain);
    image.set('Stretch', true);
    await tester.pump();
    expect(shown().fit, BoxFit.fill);
    expect(tester.getSize(find.byType(GbImage)), const Size(100, 60));
  });

  testWidgets('a new picture, then none', (tester) async {
    final image = await show(tester);
    expect(find.byType(Image), findsNothing);
    expect(find.byIcon(Icons.image_outlined), findsNothing);
    image.set('Picture', 'Triangle.png');
    await tester.pump();
    expect(find.byType(Image), findsOneWidget);
    image.set('Picture', '');
    await tester.pump();
    expect(find.byType(Image), findsNothing);
  });

  testWidgets('a picture the project does not have is shown as missing', (
    tester,
  ) async {
    await show(tester, picture: 'circle.png');
    expect(find.byIcon(Icons.broken_image_outlined), findsOneWidget);
    expect(find.text('circle.png'), findsOneWidget);
  });

  testWidgets('in the designer, an empty Image shows its name', (tester) async {
    await show(tester, designing: true);
    expect(find.byIcon(Icons.image_outlined), findsOneWidget);
    expect(find.text('imgShape'), findsOneWidget);
  });

  testWidgets('takes clicks with or without a picture', (tester) async {
    final image = await show(tester);
    await tester.tap(find.byType(GbImage));
    image.set('Picture', 'triangle.png');
    await tester.pump();
    await tester.tap(find.byType(GbImage));
    expect(events, ['imgShape.Click', 'imgShape.Click']);
  });
}
