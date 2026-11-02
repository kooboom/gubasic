import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// JSON text as values and back (docs/DESIGN.md D125): the same values
/// and the same words for a mistake on every platform.
void main() {
  test('values of every kind, members in their order', () {
    final v =
        parseJson(' {"b": [1, 2.5, "x", true, null], "a": {"n": -0.25e1}} ')
            as Map<String, Object?>;
    expect(v.keys.toList(), ['b', 'a']);
    expect(v['b'], [1, 2.5, 'x', true, null]);
    expect((v['a'] as Map)['n'], -2.5);
    expect(jsonKind(v), 'Object');
    expect(jsonKind(v['b']), 'Array');
    expect([for (final x in v['b'] as List) jsonKind(x)],
        ['Number', 'Number', 'String', 'Boolean', 'Null']);
  });

  test('whole numbers are ints on every platform, however written', () {
    expect(parseJson('12'), 12);
    expect(parseJson('12.0'), 12);
    expect(parseJson('1e3'), 1000);
    expect(parseJson('-0'), 0);
    expect(parseJson('12.5'), 12.5);
    expect(parseJson('9007199254740993'), 9007199254740992.0);
    expect(parseJson('12345678901234567890'), 1.2345678901234567e19);
    expect(normalizeJson(3.0), 3);
    expect(normalizeJson([1.0, 1.5]), [1, 1.5]);
  });

  test('strings: escapes and surrogate pairs', () {
    expect(parseJson(r'"a\"b\\c\/d\b\f\n\r\té😀"'), 'a"b\\c/d\b\f\n\r\té😀');
  });

  test('written back compact, whole doubles as whole numbers', () {
    expect(
        writeJson({
          'a': [1, 2.5, 3.0, 'x', true, null],
          'é': {'k': 'v"'}
        }),
        '{"a":[1,2.5,3,"x",true,null],"é":{"k":"v\\""}}');
    expect(writeJson(1e21), '1e+21');
    expect(() => writeJson(double.nan), throwsArgumentError);
    expect(parseJson(writeJson(parseJson('[0.1, 1e-7, 123456789012]'))),
        [0.1, 1e-7, 123456789012]);
  });

  test('mistakes are named with their place', () {
    String bad(String text) {
      try {
        parseJson(text);
      } on FormatException catch (e) {
        return e.message;
      }
      fail('$text was read');
    }

    expect(bad(''), 'the text ends too soon');
    expect(bad('[1,'), 'the text ends too soon');
    expect(bad('{"a" 1}'), 'unexpected "1" at line 1, column 6');
    expect(bad('[1,]'), 'unexpected "]" at line 1, column 4');
    expect(bad('{a: 1}'), 'unexpected "a" at line 1, column 2');
    expect(bad('[1]\n x'), 'unexpected "x" at line 2, column 2');
    expect(bad('tru'), 'unexpected "t" at line 1, column 1');
    expect(bad('01'), 'unexpected "1" at line 1, column 2');
    expect(bad('"a\nb"'), 'unexpected white space at line 1, column 3');
    expect(bad(r'"\x"'), 'unexpected "x" at line 1, column 3');
    expect(bad(r'"\u12"'), 'the text ends too soon');
    expect(bad('{"a": 1, }'), 'unexpected "}" at line 1, column 10');
  });
}
