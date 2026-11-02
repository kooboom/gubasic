import 'dart:convert';

/// JSON text as values, and back (docs/DESIGN.md D124, D125), as RFC 8259
/// defines it ([RFC 8259](https://www.rfc-editor.org/rfc/rfc8259)).
///
/// GuBASIC reads JSON itself, so that a mistake in the text is reported
/// with the same words, at the same place, on every platform, and so that
/// numbers come out the same: a number written without a fraction or an
/// exponent, small enough to be exact (below 2^53 in size), is an `int`;
/// any other is a `double`, and a `double` that is whole and that small
/// is made an `int` too, so that `12.0` and `12` are both the number 12
/// and are written back as `12`. Objects keep their members in the order
/// they were written or added.
///
/// | JSON | Dart |
/// |---|---|
/// | object | `Map<String, Object?>` |
/// | array | `List<Object?>` |
/// | string | `String` |
/// | number | `int` (whole, exact) or `double` |
/// | true, false | `bool` |
/// | null | `null` |

/// [text] as a JSON value. Throws a [FormatException] for text that is not
/// JSON, saying what was unexpected and where (line and column from 1).
Object? parseJson(String text) => _JsonParser(text).parse();

/// [value] with its numbers normalized as the library's rule says, and
/// its maps made `Map<String, Object?>`.
Object? normalizeJson(Object? value) => switch (value) {
      final double d when _isSmallWhole(d) => d.toInt(),
      final List<Object?> l => [for (final v in l) normalizeJson(v)],
      final Map<Object?, Object?> m => <String, Object?>{
          for (final MapEntry(:key, :value) in m.entries)
            '$key': normalizeJson(value),
        },
      _ => value,
    };

bool _isSmallWhole(double d) =>
    d.isFinite && d == d.truncateToDouble() && d.abs() < 9007199254740992;

/// [value] as compact JSON text: no spaces, members in their order. A
/// number that is not finite cannot be written: an [ArgumentError].
String writeJson(Object? value) {
  final out = StringBuffer();
  _write(value, out);
  return '$out';
}

void _write(Object? value, StringBuffer out) {
  switch (value) {
    case null:
      out.write('null');
    case true:
      out.write('true');
    case false:
      out.write('false');
    case final int i:
      out.write(i);
    case final double d:
      if (!d.isFinite) {
        throw ArgumentError.value(d, 'value', 'cannot be written as JSON');
      }
      // A whole double is written as a whole number on every platform.
      out.write(d == d.truncateToDouble() && d.abs() < 1e21
          ? d.toStringAsFixed(0)
          : d.toString());
    case final String s:
      out.write(jsonEncode(s));
    case final List<Object?> l:
      out.write('[');
      for (var i = 0; i < l.length; i++) {
        if (i > 0) out.write(',');
        _write(l[i], out);
      }
      out.write(']');
    case final Map<Object?, Object?> m:
      out.write('{');
      var first = true;
      for (final MapEntry(:key, :value) in m.entries) {
        if (!first) out.write(',');
        first = false;
        out.write(jsonEncode('$key'));
        out.write(':');
        _write(value, out);
      }
      out.write('}');
    default:
      throw ArgumentError.value(value, 'value', 'is not a JSON value');
  }
}

/// The kind of a JSON value, as `Json.Kind` names it: `Object`, `Array`,
/// `String`, `Number`, `Boolean` or `Null`.
String jsonKind(Object? value) => switch (value) {
      null => 'Null',
      bool() => 'Boolean',
      num() => 'Number',
      String() => 'String',
      List() => 'Array',
      Map() => 'Object',
      _ => throw ArgumentError.value(value, 'value', 'is not a JSON value'),
    };

/// A strict JSON reader (RFC 8259): one value, with white space around it.
class _JsonParser {
  _JsonParser(this.text);

  final String text;
  var _i = 0;

  Object? parse() {
    _skipSpace();
    final value = _value();
    _skipSpace();
    if (_i < text.length) _unexpected();
    return value;
  }

  Never _unexpected() {
    if (_i >= text.length) {
      throw const FormatException('the text ends too soon');
    }
    var line = 1, column = 1;
    for (var k = 0; k < _i; k++) {
      if (text.codeUnitAt(k) == 0x0A) {
        line++;
        column = 1;
      } else {
        column++;
      }
    }
    final c = text[_i];
    throw FormatException(
        'unexpected ${c.trim().isEmpty ? 'white space' : '"$c"'} at line $line, column $column');
  }

  void _skipSpace() {
    while (_i < text.length) {
      final c = text.codeUnitAt(_i);
      if (c == 0x20 || c == 0x09 || c == 0x0A || c == 0x0D) {
        _i++;
      } else {
        break;
      }
    }
  }

  bool _take(String word) {
    if (text.startsWith(word, _i)) {
      _i += word.length;
      return true;
    }
    return false;
  }

  Object? _value() {
    if (_i >= text.length) _unexpected();
    switch (text[_i]) {
      case '{':
        return _object();
      case '[':
        return _array();
      case '"':
        return _string();
      case 't':
        if (_take('true')) return true;
        _unexpected();
      case 'f':
        if (_take('false')) return false;
        _unexpected();
      case 'n':
        if (_take('null')) return null;
        _unexpected();
      default:
        return _number();
    }
  }

  Map<String, Object?> _object() {
    _i++; // {
    final members = <String, Object?>{};
    _skipSpace();
    if (_take('}')) return members;
    while (true) {
      _skipSpace();
      if (_i >= text.length || text[_i] != '"') _unexpected();
      final key = _string();
      _skipSpace();
      if (!_take(':')) _unexpected();
      _skipSpace();
      members[key] = _value();
      _skipSpace();
      if (_take('}')) return members;
      if (!_take(',')) _unexpected();
    }
  }

  List<Object?> _array() {
    _i++; // [
    final items = <Object?>[];
    _skipSpace();
    if (_take(']')) return items;
    while (true) {
      _skipSpace();
      items.add(_value());
      _skipSpace();
      if (_take(']')) return items;
      if (!_take(',')) _unexpected();
    }
  }

  String _string() {
    _i++; // "
    final out = StringBuffer();
    while (true) {
      if (_i >= text.length) _unexpected();
      final c = text.codeUnitAt(_i);
      if (c == 0x22) {
        _i++;
        return '$out';
      }
      if (c < 0x20) _unexpected();
      if (c != 0x5C) {
        out.writeCharCode(c);
        _i++;
        continue;
      }
      _i++; // backslash
      if (_i >= text.length) _unexpected();
      switch (text[_i]) {
        case '"':
          out.write('"');
        case r'\':
          out.write(r'\');
        case '/':
          out.write('/');
        case 'b':
          out.write('\b');
        case 'f':
          out.write('\f');
        case 'n':
          out.write('\n');
        case 'r':
          out.write('\r');
        case 't':
          out.write('\t');
        case 'u':
          if (_i + 4 >= text.length) {
            _i = text.length;
            _unexpected();
          }
          final hex = text.substring(_i + 1, _i + 5);
          final code = int.tryParse(hex, radix: 16);
          if (code == null || !RegExp(r'^[0-9A-Fa-f]{4}$').hasMatch(hex)) {
            _i++;
            _unexpected();
          }
          out.writeCharCode(code);
          _i += 4;
        default:
          _unexpected();
      }
      _i++;
    }
  }

  static final _numberPattern =
      RegExp(r'-?(?:0|[1-9][0-9]*)(\.[0-9]+)?([eE][+-]?[0-9]+)?');

  Object _number() {
    final m = _numberPattern.matchAsPrefix(text, _i);
    if (m == null || m.end == _i) _unexpected();
    final word = m[0]!;
    _i = m.end;
    if (m[1] == null && m[2] == null) {
      final n = int.tryParse(word);
      if (n != null && n.abs() < 9007199254740992) return n;
    }
    final d = double.parse(word);
    return _isSmallWhole(d) ? d.toInt() : d;
  }
}
