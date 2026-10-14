import 'dart:io';

import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// Golden tests for the analyzer: each `test/golden/analyzer/NAME.gbas` is
/// compiled; what every name refers to, every automatic conversion and
/// every diagnostic is printed and compared with `NAME.analysis.txt`.
///
///     UPDATE_GOLDEN=1 dart test test/analyzer/golden_test.dart
void main() {
  final update = Platform.environment['UPDATE_GOLDEN'] == '1';
  final sources = Directory('test/golden/analyzer')
      .listSync()
      .whereType<File>()
      .where((f) => f.path.endsWith('.gbas'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));

  test('golden files exist', () => expect(sources, isNotEmpty));

  for (final file in sources) {
    test(file.uri.pathSegments.last, () {
      final actual = render(file.readAsStringSync());
      final golden = File(file.path.replaceFirst('.gbas', '.analysis.txt'));
      if (update || !golden.existsSync()) {
        golden.writeAsStringSync(actual);
        if (!update) fail('Created ${golden.path}; review and rerun.');
      }
      expect(actual, golden.readAsStringSync());
    });
  }
}

String render(String source) {
  final r = compile(source);
  final lines = LineMap(source);
  String at(Node n) {
    final (l, c) = lines.locate(n.start);
    return '$l:$c';
  }

  final out = StringBuffer('--- names\n');
  final nodes = r.analysis.symbols.keys.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  for (final node in nodes) {
    final s = r.analysis.symbols[node]!;
    final declaration = switch (s.declaration) {
      ProcedureDecl(:final name) => name,
      final other => other,
    };
    final where = declaration == null
        ? 'built-in'
        : declaration == node
            ? 'declared here'
            : 'declared at ${at(declaration)}';
    final storage = s.storage == null ? '' : ' ${s.storage!.name}';
    out.writeln('${at(node)} ${s.name}: ${s.kind.name}$storage '
        '${s.type.displayName} ($where)');
  }
  out.writeln('--- conversions');
  final conversions = r.analysis.conversions.keys.toList()
    ..sort((a, b) => a.start.compareTo(b.start));
  for (final e in conversions) {
    out.writeln('${at(e)} ${source.substring(e.start, e.end)}: '
        '${r.analysis.types[e]?.displayName} → '
        '${r.analysis.conversions[e]!.displayName}');
  }
  out.writeln('--- diagnostics');
  for (final d in r.diagnostics) {
    out.writeln('${d.code.code} ${d.line}:${d.column} ${d.args.join(' | ')}');
  }
  return out.toString();
}
