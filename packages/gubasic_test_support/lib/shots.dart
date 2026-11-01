/// A failure's picture in a test's output (see `testWidgetsKeepingFailures`),
/// without Flutter, for `bin/integration.dart`.
library;

import 'dart:convert';

/// The start of a line of a failure's picture in a test's output: then
/// its name, the part's number and the part, base64.
const failureShotMarker = 'GUBASIC-FAILURE-SHOT';

/// How many base64 characters go on one line: short, so that no log cuts
/// them.
const failureShotLineLength = 400;

/// The pictures in a test's [output]: name → PNG bytes.
Map<String, List<int>> failureShotsIn(String output) {
  final parts = <String, Map<int, String>>{};
  final line = RegExp('$failureShotMarker (\\S+) (\\d+) ([A-Za-z0-9+/=]+)');
  for (final m in line.allMatches(output)) {
    parts.putIfAbsent(m[1]!, () => {})[int.parse(m[2]!)] = m[3]!;
  }
  return {
    for (final MapEntry(:key, :value) in parts.entries)
      key: base64.decode(
        [for (var i = 0; i < value.length; i++) value[i] ?? ''].join(),
      ),
  };
}
