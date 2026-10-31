import 'package:gubasic_lang/src/text/dates.dart';
import 'package:test/test.dart';

/// DateAdd and DateDiff (docs/DESIGN.md D115).
void main() {
  test('intervals', () {
    expect(dateInterval('YYYY'), 'yyyy');
    expect(dateInterval('x'), isNull);
    expect(dateIntervals['WeekOfYear'], 'ww');
  });

  test('DateAdd: a month past the end of a month is its last day', () {
    expect(dateAdd('m', 1, DateTime(2026, 1, 31)), DateTime(2026, 2, 28));
    expect(dateAdd('m', 1, DateTime(2028, 1, 31)), DateTime(2028, 2, 29));
    expect(dateAdd('yyyy', -1, DateTime(2028, 2, 29)), DateTime(2027, 2, 28));
    expect(dateAdd('q', 1, DateTime(2026, 11, 30)), DateTime(2027, 2, 28));
    expect(dateAdd('d', 30, DateTime(2026, 10, 29)), DateTime(2026, 11, 28));
    expect(dateAdd('ww', -1, DateTime(2026, 1, 3)), DateTime(2025, 12, 27));
    expect(dateAdd('h', 25, DateTime(2026, 3, 7, 23)), DateTime(2026, 3, 9, 0));
    expect(dateAdd('n', 90, DateTime(2026, 3, 7)), DateTime(2026, 3, 7, 1, 30));
  });

  test('DateDiff: boundaries for years to weeks, whole ones below', () {
    expect(dateDiff('yyyy', DateTime(2025, 12, 31), DateTime(2026, 1, 1)), 1);
    expect(dateDiff('m', DateTime(2026, 1, 31), DateTime(2026, 2, 1)), 1);
    expect(dateDiff('q', DateTime(2026, 3, 31), DateTime(2026, 4, 1)), 1);
    expect(dateDiff('d', DateTime(2026, 3, 1), DateTime(2026, 2, 1)), -28);
    expect(dateDiff('d', DateTime(2026, 3, 1, 23), DateTime(2026, 3, 2, 1)), 0);
    // Saturday to the next day, a Sunday: one calendar week, no whole week.
    expect(dateDiff('ww', DateTime(2026, 3, 7), DateTime(2026, 3, 8)), 1);
    expect(dateDiff('w', DateTime(2026, 3, 7), DateTime(2026, 3, 8)), 0);
    expect(dateDiff('h', DateTime(2026, 3, 7), DateTime(2026, 3, 8, 2)), 26);
    expect(dateDiff('s', DateTime(2026, 3, 7), DateTime(2026, 3, 7, 0, 1)), 60);
  });
}
