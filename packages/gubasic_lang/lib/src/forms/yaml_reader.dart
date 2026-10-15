import 'package:source_span/source_span.dart';
import 'package:yaml/yaml.dart';

import '../diagnostics/diagnostic.dart';
import '../lexer/keyword.dart';

/// Shared by the form and project file readers: turns YAML nodes into
/// values and reports problems as F diagnostics at their place in the
/// file. Never throws.
class YamlReader {
  final diagnostics = <Diagnostic>[];

  void report(SourceSpan span, DiagnosticCode code,
      [List<String> args = const []]) {
    diagnostics.add(Diagnostic(
      code: code,
      line: span.start.line + 1,
      column: span.start.column + 1,
      offset: span.start.offset,
      length: span.length,
      args: args,
    ));
  }

  /// The top-level map of [text], or null after reporting F001.
  YamlMap? load(String text) {
    final YamlNode doc;
    try {
      doc = loadYamlNode(text);
    } on YamlException catch (e) {
      final span = e.span;
      if (span != null) {
        report(span, DiagnosticCode.fileSyntax);
      } else {
        diagnostics.add(const Diagnostic(
            code: DiagnosticCode.fileSyntax,
            line: 1,
            column: 1,
            offset: 0,
            length: 0));
      }
      return null;
    }
    if (doc is YamlMap) return doc;
    if (doc is YamlScalar && doc.value == null) {
      // An empty file: reported below as a missing formatVersion.
      return YamlMap.wrap(const {});
    }
    report(doc.span, DiagnosticCode.fileSyntax);
    return null;
  }

  /// The entries of [map] by lower-case key, warning about keys that are
  /// not in [known] (F004).
  Map<String, YamlNode> entries(YamlMap map, Set<String> known) {
    final result = <String, YamlNode>{};
    for (final MapEntry(:key, :value) in map.nodes.entries) {
      final keyNode = key as YamlNode;
      final name = '${keyNode.value}';
      final lower = name.toLowerCase();
      if (!known.contains(lower)) {
        report(keyNode.span, DiagnosticCode.unknownKey, [name]);
        continue;
      }
      result[lower] = value;
    }
    return result;
  }

  /// Checks `formatVersion` against [supported]: F002 if it is missing,
  /// F003 if it is newer. True if the rest of the file can be read.
  bool checkVersion(YamlMap map, Map<String, YamlNode> entries, int supported) {
    final node = entries['formatversion'];
    final value = node?.value;
    if (value is! int) {
      report(node?.span ?? _start(map), DiagnosticCode.formatVersionMissing);
      return true; // read the rest anyway, as version 1
    }
    if (value > supported) {
      report(node!.span, DiagnosticCode.formatVersionTooNew,
          ['$value', '$supported']);
      return false;
    }
    return true;
  }

  /// [node] if it is a map, or null after reporting F005 for [key].
  YamlMap? map(YamlNode node, String key) {
    if (node is YamlMap) return node;
    if (node is YamlScalar && node.value == null) return YamlMap.wrap({});
    report(node.span, DiagnosticCode.wrongValueForm, [key, '$key: …']);
    return null;
  }

  /// [node] if it is a list, or null after reporting F005 for [key].
  YamlList? list(YamlNode node, String key, String example) {
    if (node is YamlList) return node;
    if (node is YamlScalar && node.value == null) return YamlList.wrap([]);
    report(node.span, DiagnosticCode.wrongValueForm, [key, example]);
    return null;
  }

  /// The text of a scalar, or null after reporting F005 for [key].
  String? text(YamlNode node, String key, String example) {
    final value = node.value;
    if (node is YamlScalar && value != null && value is! YamlNode) {
      return '$value';
    }
    report(node.span, DiagnosticCode.wrongValueForm, [key, example]);
    return null;
  }

  /// A usable control or form name, or null after reporting F006.
  String? name(YamlNode node) {
    final value = node.value;
    final text = node is YamlScalar && value != null ? '$value' : '';
    if (isUsableName(text)) return text;
    report(node.span, DiagnosticCode.invalidControlName, [text]);
    return null;
  }

  SourceSpan _start(YamlNode node) {
    final start = node.span.start;
    return SourceSpan(start, start, '');
  }
}

final _namePattern = RegExp(r'^[A-Za-z][A-Za-z0-9_]*$');

/// Whether [name] can name a control or a form: an ASCII identifier
/// (docs/LANGUAGE.md §1), not a keyword, and not `Form`, which handlers
/// of the form's own events use (`Form_Load`).
bool isUsableName(String name) =>
    _namePattern.hasMatch(name) &&
    Keyword.lookup(name) == null &&
    name.toLowerCase() != 'form';
