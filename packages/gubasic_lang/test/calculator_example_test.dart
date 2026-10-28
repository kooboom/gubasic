@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// examples/calculator, its ten digit buttons in one handler (Handles,
/// docs/DESIGN.md D98), is played through by the parity program
/// calculator_example, which must stay a copy of it.
void main() {
  test('calculator_example is a copy of examples/calculator', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'calculator_example.gbas'),
      ('Form1.form.yaml', 'calculator_example.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/calculator/$example').readAsStringSync(),
        reason: 'copy examples/calculator/$example to test/parity/$parity',
      );
    }
  });
}
