import 'package:gubasic_lang/src/text/cp949_table.dart';
import 'package:gubasic_lang/src/text/text_codec.dart';
import 'package:test/test.dart';

/// Text files' bytes (docs/DESIGN.md D113).
void main() {
  test('the table: 126 rows of 190', () {
    expect(cp949Table.length, 126 * 190);
  });

  test('UTF-8, with or without a BOM; otherwise code page 949', () {
    expect(decodeText([0xEF, 0xBB, 0xBF, 0x41, 0xEA, 0xB0, 0x80]), 'A가');
    expect(decodeText([0x41, 0xEA, 0xB0, 0x80]), 'A가');
    // 이름,점수 as Korean Windows' Excel saves it (EUC-KR codes), and 똠
    // from the codes only code page 949 has.
    expect(
      decodeText([0xC0, 0xCC, 0xB8, 0xA7, 0x2C, 0xC1, 0xA1, 0xBC, 0xF6]),
      '이름,점수',
    );
    expect(decodeText([0x8C, 0x63]), '똠');
    expect(decodeCp949([0xFF, 0x41]), '�A');
  });

  test('written as UTF-8, a BOM for .csv', () {
    expect(encodeText('가'), [0xEA, 0xB0, 0x80]);
    expect(encodeText('A', bom: true), [0xEF, 0xBB, 0xBF, 0x41]);
    expect(wantsBom('명단.CSV'), isTrue);
    expect(wantsBom('memo.txt'), isFalse);
  });

  test('lines at any line break, no empty line after the last', () {
    expect(textLines('a\r\nb\nc\rd\n'), ['a', 'b', 'c', 'd']);
    expect(textLines(''), isEmpty);
    expect(textLines('a\n\n'), ['a', '']);
  });
}
