import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/toolbox.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:integration_test/integration_test.dart';

/// The toolbox in the IDE's own window (D107): icons in two columns, each
/// a control drawn small, and a tool's name in its tooltip. Run with
/// `flutter test integration_test/toolbox_test.dart -d macos` (or `-d
/// windows`); the pointer is the test's, not the computer's. With
/// `--dart-define=SHOTS=folder` it saves what it shows there as
/// `toolbox-PLATFORM.png` and `toolbox-tooltip-PLATFORM.png`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const shots = String.fromEnvironment('SHOTS');

  /// Saves the window's [area] as [name], when there is somewhere to.
  Future<void> save(WidgetTester tester, String name, Rect area) async {
    if (shots.isEmpty) return;
    final view = tester.binding.renderViews.first;
    final ratio = tester.view.devicePixelRatio;
    await tester.runAsync(() async {
      // The root layer is in the screen's pixels.
      final image = await (view.debugLayer! as OffsetLayer).toImage(
        Rect.fromLTRB(
          area.left * ratio,
          area.top * ratio,
          area.right * ratio,
          area.bottom * ratio,
        ),
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      final file = File('$shots/$name-${Platform.operatingSystem}.png');
      await file.create(recursive: true);
      await file.writeAsBytes(png!.buffer.asUint8List());
    });
  }

  testWidgets('two columns of drawn controls; the name in the tooltip', (
    tester,
  ) async {
    await tester.pumpWidget(
      IdeApp(
        projects: {'hello': exampleProjects['hello']!},
        strings: IdeStrings.en,
      ),
    );
    await tester.pumpAndSettle();
    final toolbox = find.byType(Toolbox);
    expect(toolbox, findsOneWidget);

    // The pointer and the Button side by side, the TextBox under the
    // pointer: two columns.
    final pointer = tester.getRect(
      find.byKey(const ValueKey('toolbox.pointer')),
    );
    final button = tester.getRect(find.byKey(const ValueKey('toolbox.Button')));
    final label = tester.getRect(find.byKey(const ValueKey('toolbox.Label')));
    expect(button.top, pointer.top);
    expect(button.left, greaterThan(pointer.right - 1));
    expect(label.left, pointer.left);
    expect(label.top, greaterThan(pointer.bottom - 1));
    // No names in the toolbox itself.
    expect(
      find.descendant(of: toolbox, matching: find.byType(Text)),
      findsNothing,
    );
    final box = tester.getRect(toolbox);
    final last = tester.getRect(find.byKey(const ValueKey('toolbox.Timer')));
    await save(
      tester,
      'toolbox',
      Rect.fromLTRB(box.left, box.top, box.right, last.bottom + 8),
    );

    final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
    await mouse.addPointer(location: Offset.zero);
    addTearDown(mouse.removePointer);
    await mouse.moveTo(
      tester.getCenter(find.byKey(const ValueKey('toolbox.OptionButton'))),
    );
    await tester.pumpAndSettle(const Duration(seconds: 1));
    expect(find.text('OptionButton'), findsOneWidget);
    await save(
      tester,
      'toolbox-tooltip',
      Rect.fromLTWH(box.left, box.top, 420, last.bottom + 8 - box.top),
    );
  });
}
