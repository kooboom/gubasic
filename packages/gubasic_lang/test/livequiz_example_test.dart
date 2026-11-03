@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// examples/livequiz, the live quiz over Room (docs/DESIGN.md D136), is
/// played through by the parity programs livequiz_example (the TV) and
/// livequiz_phone (a phone), which must stay copies of it; the others in
/// the room are the event scripts' Peers.
void main() {
  for (final parity in ['livequiz_example', 'livequiz_phone']) {
    test('$parity is a copy of examples/livequiz', () {
      for (final (example, copy) in [
        ('FormStart.gbas', '$parity.gbas'),
        ('FormStart.form.yaml', '$parity.form.yaml'),
        ('FormTV.gbas', '$parity.FormTV.gbas'),
        ('FormTV.form.yaml', '$parity.FormTV.form.yaml'),
        ('FormPhone.gbas', '$parity.FormPhone.gbas'),
        ('FormPhone.form.yaml', '$parity.FormPhone.form.yaml'),
      ]) {
        expect(
          File('../../test/parity/$copy').readAsStringSync(),
          File('../../examples/livequiz/$example').readAsStringSync(),
          reason: 'copy examples/livequiz/$example to test/parity/$copy',
        );
      }
    });
  }
}
