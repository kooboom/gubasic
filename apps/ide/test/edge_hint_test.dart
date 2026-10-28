import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/form_designer.dart';
import 'package:gubasic_ide/src/designer/form_edit.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// D77: a drag stopped at the form's edge says why, and a control wholly
/// outside the form has an arrow on the edge pointing to it.
void main() {
  const s = IdeStrings.en;
  const size = (width: 320, height: 120);
  const box = (left: 16, top: 56, width: 120, height: 32);

  test('a drag is past the edge where the form stops it', () {
    bool past(Handle? h, double dx, double dy) =>
        dragPastEdge(box, h, dx, dy, size: size, grid: false);
    expect(past(null, 10, 10), isFalse);
    expect(past(null, 190, 0), isTrue, reason: 'its right edge at 326');
    expect(past(null, -20, 0), isTrue);
    expect(past(null, 0, 40), isTrue);
    expect(past((x: 1, y: 0), 180, 0), isFalse, reason: 'right edge at 316');
    expect(past((x: 1, y: 0), 190, 0), isTrue);
    expect(past((x: -1, y: 0), -20, 0), isTrue);
    expect(past((x: 0, y: 1), 0, 40), isTrue);
    expect(past((x: 0, y: -1), 0, 40), isFalse, reason: 'the top edge');
  });

  test('a control wholly outside has a marker on the nearest edge, '
      'pointing to it; one partly inside has none', () {
    expect(outsideMarker(box, size), isNull);
    expect(
      outsideMarker((left: 300, top: 0, width: 50, height: 20), size),
      isNull,
    );
    final right = outsideMarker((
      left: 400,
      top: 40,
      width: 80,
      height: 20,
    ), size)!;
    expect(right.at, const Point(320.0, 50.0));
    expect(right.towards, const Point(1.0, 0.0));
    final above = outsideMarker((
      left: 100,
      top: -60,
      width: 40,
      height: 20,
    ), size)!;
    expect(above.at, const Point(120.0, 0.0));
    expect(above.towards, const Point(0.0, -1.0));
  });

  testWidgets('dragging a handle past the form says so in the status line, '
      'until the button comes up', (tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': exampleProjects['hello']!}, strings: s),
    );
    await tester.tap(explorerItem('Form1.form.yaml'));
    await tester.pumpAndSettle();
    final origin = tester.getTopLeft(find.byKey(designerFormKey));
    await tester.tapAt(
      origin + const Offset(60, 72),
      kind: PointerDeviceKind.mouse,
    );
    await tester.pump(const Duration(milliseconds: 500));

    final mouse = await tester.startGesture(
      origin + const Offset(136, 72),
      kind: PointerDeviceKind.mouse,
      buttons: kPrimaryButton,
    );
    await mouse.moveTo(origin + const Offset(200, 72));
    await tester.pump();
    expect(find.byKey(designerEdgeHintKey), findsNothing);
    await mouse.moveTo(origin + const Offset(400, 72));
    await tester.pump();
    expect(find.byKey(designerEdgeHintKey), findsOneWidget);
    expect(find.text(s.stoppedAtEdge), findsOneWidget);
    await mouse.up();
    await tester.pumpAndSettle();
    expect(find.byKey(designerEdgeHintKey), findsNothing);
    expect(find.textContaining('btnHello (Button)'), findsOneWidget);
  });
}
