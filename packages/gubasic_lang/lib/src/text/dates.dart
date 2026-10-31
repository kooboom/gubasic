/// `DateAdd` and `DateDiff` (docs/DESIGN.md D115), as Visual Basic's: an
/// interval is `yyyy` (years), `q` (quarters), `m` (months), `y` (days of
/// the year: days), `d` (days), `w` (weekdays: weeks of 7 days), `ww`
/// (calendar weeks), `h`, `n` (minutes) or `s`, in any case; or the same
/// through `DateInterval`.
///
/// Worked out on the date's parts, never on the time zone's clock, so
/// that a change to summer time changes nothing.
library;

/// The interval [text] as `DateAdd` takes it, or null when it is none.
String? dateInterval(String text) {
  final t = text.toLowerCase();
  return const {'yyyy', 'q', 'm', 'y', 'd', 'w', 'ww', 'h', 'n', 's'}
          .contains(t)
      ? t
      : null;
}

/// The names of `DateInterval`, as Visual Basic .NET's, with the interval
/// each is.
const dateIntervals = {
  'Year': 'yyyy',
  'Quarter': 'q',
  'Month': 'm',
  'DayOfYear': 'y',
  'Day': 'd',
  'Weekday': 'w',
  'WeekOfYear': 'ww',
  'Hour': 'h',
  'Minute': 'n',
  'Second': 's',
};

DateTime _asUtc(DateTime d) => DateTime.utc(
      d.year,
      d.month,
      d.day,
      d.hour,
      d.minute,
      d.second,
      d.millisecond,
    );

DateTime _asLocal(DateTime d) => DateTime(
      d.year,
      d.month,
      d.day,
      d.hour,
      d.minute,
      d.second,
      d.millisecond,
    );

/// [date] with [n] months more: a day past the end of the month is the
/// month's last day (January 31 and a month is February 28 or 29).
DateTime _addMonths(DateTime date, int n) {
  final months = date.year * 12 + date.month - 1 + n;
  final year = months ~/ 12;
  final month = months % 12 + 1;
  final last = DateTime.utc(year, month + 1, 0).day;
  return DateTime.utc(
    year,
    month,
    date.day > last ? last : date.day,
    date.hour,
    date.minute,
    date.second,
    date.millisecond,
  );
}

/// [date] with [n] of [interval] more (n may be negative).
DateTime dateAdd(String interval, int n, DateTime date) {
  final d = _asUtc(date);
  final r = switch (interval) {
    'yyyy' => _addMonths(d, 12 * n),
    'q' => _addMonths(d, 3 * n),
    'm' => _addMonths(d, n),
    'y' || 'd' => d.add(Duration(days: n)),
    'w' || 'ww' => d.add(Duration(days: 7 * n)),
    'h' => d.add(Duration(hours: n)),
    'n' => d.add(Duration(minutes: n)),
    _ => d.add(Duration(seconds: n)),
  };
  return _asLocal(r);
}

/// How many [interval]s from [a] to [b]; negative when [b] is earlier. For
/// years, quarters, months and calendar weeks, the boundaries crossed
/// (from December 31 to January 1 is a year); for days and smaller, the
/// whole ones between; weekdays are whole weeks of 7 days.
int dateDiff(String interval, DateTime a, DateTime b) {
  final x = _asUtc(a), y = _asUtc(b);
  int days() => y.difference(x).inDays;
  switch (interval) {
    case 'yyyy':
      return y.year - x.year;
    case 'q':
      return (y.year * 4 + (y.month - 1) ~/ 3) -
          (x.year * 4 + (x.month - 1) ~/ 3);
    case 'm':
      return (y.year * 12 + y.month) - (x.year * 12 + x.month);
    case 'y' || 'd':
      return days();
    case 'w':
      return days() ~/ 7;
    case 'ww':
      // Sundays crossed: weeks start on Sunday.
      DateTime sunday(DateTime d) {
        final day = DateTime.utc(d.year, d.month, d.day);
        return day.subtract(Duration(days: day.weekday % 7));
      }
      return sunday(y).difference(sunday(x)).inDays ~/ 7;
    case 'h':
      return y.difference(x).inHours;
    case 'n':
      return y.difference(x).inMinutes;
    default:
      return y.difference(x).inSeconds;
  }
}
