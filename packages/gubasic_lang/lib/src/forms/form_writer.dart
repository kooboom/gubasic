import 'package:yaml/yaml.dart';

import 'component.dart';
import 'form_file.dart';

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
        ..writeln('  - name: ${_string(c.name)}')
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
      String() => _string(value),
      double() when value.isNaN => '.nan',
      double() when value.isInfinite => value > 0 ? '.inf' : '-.inf',
      _ => '$value',
    };

/// [text] as a YAML scalar: as it is when YAML reads it back as the same
/// text, otherwise in double quotes.
String _string(String text) {
  if (text.isNotEmpty && text.runes.every(_isPlainSafe)) {
    try {
      final map = loadYaml('k: $text');
      if (map is YamlMap && map.length == 1 && map['k'] == text) return text;
    } on YamlException {
      // Not plain: quoted below.
    }
  }
  return _quoted(text);
}

/// Characters that can be written without escapes: printable ones except
/// those that editors or YAML 1.1 show as line breaks (U+0085, U+2028,
/// U+2029), and the byte order mark.
bool _isPlainSafe(int rune) =>
    (rune >= 0x20 && rune <= 0x7e) ||
    (rune >= 0xa0 && rune <= 0xd7ff && rune != 0x2028 && rune != 0x2029) ||
    (rune >= 0xe000 && rune <= 0xfffd && rune != 0xfeff) ||
    rune >= 0x10000;

String _quoted(String text) {
  final out = StringBuffer('"');
  for (final rune in text.runes) {
    switch (rune) {
      case 0x22:
        out.write(r'\"');
      case 0x5c:
        out.write(r'\\');
      case 0x09:
        out.write(r'\t');
      case 0x0a:
        out.write(r'\n');
      case 0x0d:
        out.write(r'\r');
      case _ when _isPlainSafe(rune):
        out.writeCharCode(rune);
      case _:
        out.write('\\u${rune.toRadixString(16).padLeft(4, '0')}');
    }
  }
  out.write('"');
  return '$out';
}
