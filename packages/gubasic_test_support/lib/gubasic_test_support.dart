/// What the apps' integration tests share: a test that fails prints a
/// picture of the window into its output, which `bin/integration.dart`
/// keeps as a file beside the whole output.
library;

import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';

import 'shots.dart';

export 'shots.dart';

/// [testWidgets], keeping a picture of the window when [body] fails: an
/// `expect` that does not hold, or anything else it throws. The test
/// still fails with the same error.
void testWidgetsKeepingFailures(
  String description,
  WidgetTesterCallback body, {
  Timeout? timeout,
  bool? skip,
}) {
  testWidgets(
    description,
    (tester) async {
      try {
        await body(tester);
      } catch (_) {
        await printFailureShot(tester, description);
        rethrow;
      }
    },
    timeout: timeout,
    skip: skip,
  );
}

/// Prints the window as it is now, as a PNG in base64 lines under
/// [failureShotMarker], named after [description].
Future<void> printFailureShot(WidgetTester tester, String description) async {
  final ascii = description
      .replaceAll(RegExp(r'[^A-Za-z0-9]+'), '-')
      .replaceAll(RegExp(r'^-+|-+$'), '');
  // A name of no ASCII letters at all (a Korean one) still names the file.
  final name = ascii.isEmpty ? 'failure' : ascii;
  try {
    final bytes = await tester.runAsync(() async {
      final view = tester.binding.renderViews.first;
      final size = view.size * tester.view.devicePixelRatio;
      final image = await (view.debugLayer! as OffsetLayer).toImage(
        Offset.zero & size,
      );
      final png = await image.toByteData(format: ui.ImageByteFormat.png);
      return png!.buffer.asUint8List();
    });
    final text = base64.encode(bytes!);
    for (
      var i = 0, part = 0;
      i < text.length;
      i += failureShotLineLength, part++
    ) {
      final end = i + failureShotLineLength < text.length
          ? i + failureShotLineLength
          : text.length;
      // ignore: avoid_print
      print('$failureShotMarker $name $part ${text.substring(i, end)}');
    }
  } catch (e) {
    // ignore: avoid_print
    print('$failureShotMarker $name no picture: $e');
  }
}
