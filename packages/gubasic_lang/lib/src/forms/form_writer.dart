import 'component.dart';
import 'form_file.dart';
import 'yaml_text.dart';

/// Writes [form] as a form file (docs/LANGUAGE.md §11.2, D31), so that
/// [readFormFile] reads back the same form.
///
/// There is one way to write a form: properties in the order of their
/// component.yaml, only values that differ from the defaults, and quotes
/// only where YAML would read the text differently. Saving the same form
/// twice gives the same bytes, and a change shows in Git as the lines it
/// changed (D13). Comments and other layout of a hand-written file are
/// not kept.
String writeFormFile(FormFile form) {
  final out = StringBuffer('formatVersion: $formFileVersion\n');
  _properties(out, '', form.component, form.properties);
  if (form.controls.isNotEmpty) {
    out.writeln('controls:');
    for (final c in form.controls) {
      out
        ..writeln('  - name: ${yamlString(c.name)}')
        ..writeln('    type: ${c.component.name}');
      _properties(out, '    ', c.component, c.properties);
    }
  }
  return '$out';
}

/// Writes the `properties:` map of [values] for [component], if any
/// value differs from its default.
void _properties(StringBuffer out, String indent, ComponentSpec component,
    Map<String, Object> values) {
  final byName = {
    for (final MapEntry(:key, :value) in values.entries)
      key.toLowerCase(): value
  };
  final lines = [
    for (final MapEntry(:key, value: spec) in component.properties.entries)
      if (byName[key] case final value?
          when !_isDefault(value, spec.defaultValue))
        '$indent  ${spec.name}: ${_scalar(value)}'
  ];
  if (lines.isEmpty) return;
  out.writeln('${indent}properties:');
  lines.forEach(out.writeln);
}

bool _isDefault(Object value, Object defaultValue) =>
    value == defaultValue ||
    (value is double &&
        defaultValue is double &&
        value.isNaN &&
        defaultValue.isNaN);

String _scalar(Object value) => switch (value) {
      String() => yamlString(value),
      double() when value.isNaN => '.nan',
      double() when value.isInfinite => value > 0 ? '.inf' : '-.inf',
      _ => '$value',
    };
