@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// examples/weather, the weather now from Open-Meteo through Http and
/// JSON (docs/DESIGN.md D125), is played through by the parity program
/// weather_example, which must stay a copy of it; the parity program
/// answers from weather_example.http.
void main() {
  test('weather_example is a copy of examples/weather', () {
    for (final (example, parity) in [
      ('Form1.gbas', 'weather_example.gbas'),
      ('Form1.form.yaml', 'weather_example.form.yaml'),
    ]) {
      expect(
        File('../../test/parity/$parity').readAsStringSync(),
        File('../../examples/weather/$example').readAsStringSync(),
        reason: 'copy examples/weather/$example to test/parity/$parity',
      );
    }
  });
}
