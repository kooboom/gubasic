import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_test_support/shots.dart';

/// A failure's picture survives the trip through a test's output, also
/// when a log puts something before each line.
void main() {
  test('the parts of a picture are put back together, in order', () {
    final bytes = List<int>.generate(1000, (i) => i % 256);
    final text = base64.encode(bytes);
    final lines = [
      for (var i = 0, p = 0; i < text.length; i += 400, p++)
        'flutter: $failureShotMarker scores 0$p '
            '${text.substring(i, i + 400 > text.length ? text.length : i + 400)}',
    ];
    final output = ['00:01 +0: loading', ...lines.reversed, 'done'].join('\n');
    expect(failureShotsIn(output), {'scores': bytes});
    expect(failureShotsIn('nothing here'), isEmpty);
  });
}
