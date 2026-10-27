import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../integration_test/askname.dart';

/// The integration test's askname is a copy of examples/askname.
void main() {
  test('integration_test/askname.dart is a copy of examples/askname', () {
    final example = Directory('../../examples/askname');
    expect(askname, {
      for (final f in example.listSync().whereType<File>())
        f.uri.pathSegments.last: f.readAsStringSync(),
    });
  });
}
