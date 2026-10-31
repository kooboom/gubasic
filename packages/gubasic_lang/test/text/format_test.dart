import 'package:gubasic_lang/src/text/format.dart';
import 'package:test/test.dart';

/// Format (docs/DESIGN.md D115).
void main() {
  final d = DateTime(2026, 3, 7, 14, 5, 9); // a Saturday

  test('dates', () {
    expect(formatDateWith(d, 'yyyy-MM-dd'), '2026-03-07');
    expect(formatDateWith(d, 'yy/M/d H:m:s'), '26/3/7 14:5:9');
    expect(formatDateWith(d, 'hh:mm tt'), '02:05 PM');
    expect(formatDateWith(d, 'dddd, MMMM d'), 'Saturday, March 7');
    expect(formatDateWith(d, 'ddd MMM'), 'Sat Mar');
    expect(formatDateWith(DateTime(2026, 1, 1, 0, 30), 'h tt'), '12 AM');
    expect(formatDateWith(d, '"Day" d \\d'), 'Day 7 d');
  });

  test('names and AM/PM in Korean', () {
    expect(formatDateWith(d, 'yyyy년 M월 d일 (ddd) tt h시', language: 'ko'),
        '2026년 3월 7일 (토) 오후 2시');
    expect(formatDateWith(d, 'dddd MMMM', language: 'ko'), '토요일 3월');
  });

  test('numbers', () {
    expect(formatNumberWith(1234567, '#,##0'), '1,234,567');
    expect(formatNumberWith(1234.5, '#,##0.00'), '1,234.50');
    expect(formatNumberWith(2.675, '0.00'), '2.68');
    expect(formatNumberWith(-2.5, '0'), '-3');
    expect(formatNumberWith(0.256, '0.0%'), '25.6%');
    expect(formatNumberWith(7, '000'), '007');
    expect(formatNumberWith(3.1, '#.##'), '3.1');
    expect(formatNumberWith(0, '#'), '');
    expect(formatNumberWith(15000, '#,##0원'), '15,000원');
    expect(formatNumberWith(-5, '0;(0);zero'), '(5)');
    expect(formatNumberWith(0, '0;(0);"없음"'), '없음');
    expect(formatNumberWith(-0.001, '0.00'), '0.00');
    expect(formatNumberWith('9223372036854775807', '#,##0'),
        '9,223,372,036,854,775,807');
    expect(formatNumberWith(1e21, '0'), '1000000000000000000000');
  });

  test('standard formats, in the app\'s language (D118)', () {
    expect(formatDateWith(d, 'd'), '3/7/2026');
    expect(formatDateWith(d, 'D'), 'Saturday, March 7, 2026');
    expect(formatDateWith(d, 't'), '2:05 PM');
    expect(formatDateWith(d, 'T'), '2:05:09 PM');
    expect(formatDateWith(d, 'd', language: 'ko'), '2026-03-07');
    expect(formatDateWith(d, 'D', language: 'ko'), '2026년 3월 7일 토요일');
    expect(formatDateWith(d, 't', language: 'ko'), '오후 2:05');
    expect(formatDateWith(d, 'T', language: 'ko'), '오후 2:05:09');
    expect(formatDateWith(d, '%d'), '7', reason: '% makes it custom');
    expect(formatNumberWith(1234.567, 'N'), '1,234.57');
    expect(formatNumberWith(1234.567, 'N0'), '1,235');
    expect(formatNumberWith(-1234.5, 'n1'), '-1,234.5');
    expect(formatNumberWith(1234.5, 'F'), '1234.50');
    expect(formatNumberWith(1234.5, 'F0'), '1235');
    expect(formatNumberWith(0.1234, 'P'), '12.34%');
    expect(formatNumberWith(0.5, 'P0'), '50%');
    expect(formatNumberWith(1234.5, 'C'), r'$1,234.50');
    expect(formatNumberWith(-1234.5, 'C'), r'-$1,234.50');
    expect(formatNumberWith(1234.5, 'C', language: 'ko'), '₩1,235');
    expect(formatNumberWith(1234.5, 'C2', language: 'ko'), '₩1,234.50');
    expect(formatNumberWith(42, 'D5'), '00042');
    expect(formatNumberWith(-42, 'D'), '-42');
    expect(formatNumberWith('9223372036854775807', 'N0'),
        '9,223,372,036,854,775,807');
  });
}
