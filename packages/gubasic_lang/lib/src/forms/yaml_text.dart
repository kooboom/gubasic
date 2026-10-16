import 'package:yaml/yaml.dart';

/// [text] as a YAML scalar: as it is when YAML reads it back as the same
/// text, otherwise in double quotes.
String yamlString(String text) {
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
