import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Golden tests: each `test/golden/NAME.gbas` is parsed and printed with
/// [astToText] (with positions) followed by its diagnostics; the result must
/// equal `NAME.ast.txt`. To accept new output after an intended change, run
///
///     UPDATE_GOLDEN=1 dart test test/parser/golden_test.dart
///
/// and review the diff.
void main() {
  final update = Platform.environment['UPDATE_GOLDEN'] == '1';
  final sources = Directory('test/golden')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.gbas'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('golden files exist', () => expect(sources, isNotEmpty));

  for (final file in sources) {
    final name = file.uri.pathSegments.last;
    test(name, () {
      final source = file.readAsStringSync();
      final actual = render(source);
      final golden = File(file.path.replaceFirst('.gbas', '.ast.txt'));
      if (update || !golden.existsSync()) {
        golden.writeAsStringSync(actual);
        if (!update) fail('Created ${golden.path}; review and rerun.');
      }
      expect(actual, golden.readAsStringSync());
    });
  }
}

String render(String source) {
  final r = parse(source);
  final out = StringBuffer(astToText(r.unit, lineMap: LineMap(source)));
  out.writeln('--- diagnostics');
  for (final d in r.diagnostics) {
    out.writeln('${d.code.code} ${d.line}:${d.column} ${d.args.join(' | ')}');
  }
  return out.toString();
}
