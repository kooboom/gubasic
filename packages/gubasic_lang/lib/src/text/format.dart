/// `Format(value, format)` (docs/DESIGN.md D115): Visual Basic .NET's
/// custom format strings for dates and numbers.
///
/// **Dates:** `yyyy` `yy` the year, `MMMM` `MMM` `MM` `M` the month (its
/// name, short name, two digits, digits), `dddd` `ddd` `dd` `d` the day
/// (the weekday's name, short name, two digits, digits), `HH` `H` the hour
/// of 24, `hh` `h` of 12, `mm` `m` the minute, `ss` `s` the second, `tt`
/// AM or PM. Names and AM/PM are in [language] (`en` or `ko`). Text in
/// quotes, and a character after `\`, is written as it is; any other
/// character too (`-`, `/`, `:`, a space).
///
/// **Numbers:** `0` a digit always written, `#` a digit written only when
/// needed, `.` the decimal point, `,` among the digits a thousands
/// separator, `%` the number times 100 and a percent sign; text before
/// and after the digits is written around them. Up to three sections
/// split by `;`: positive, negative (written without its minus), zero.
/// The decimal point is always `.` and the separator `,`. Rounding goes
/// half away from zero, on the number as it is written in decimal, as
/// `Round` does.
///
/// **Standard formats** (D118): a format of one letter is .NET's standard
/// one, in the app's [language]: for dates `d` `D` (short and long date),
/// `t` `T` (short and long time); for numbers `N` (with separators), `F`
/// (fixed), `P` (percent), `C` (currency: `$` in English, `₩` in Korean),
/// `D` (an integer's digits), each with the number of decimals (digits for
/// `D`) after it: `N0`, `C2`. `%` before one letter makes it a custom
/// format: `%d` is the day.
library;

const _monthsEn = [
  'January', 'February', 'March', 'April', 'May', 'June', 'July', //
  'August', 'September', 'October', 'November', 'December',
];
const _daysEn = [
  'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', //
  'Sunday',
];
const _daysKo = ['월요일', '화요일', '수요일', '목요일', '금요일', '토요일', '일요일'];

/// The custom format a standard date [format] stands for, or null.
String? _standardDate(String format, bool ko) => switch (format) {
      'd' => ko ? 'yyyy-MM-dd' : 'M/d/yyyy',
      'D' => ko ? 'yyyy년 M월 d일 dddd' : 'dddd, MMMM d, yyyy',
      't' => ko ? 'tt h:mm' : 'h:mm tt',
      'T' => ko ? 'tt h:mm:ss' : 'h:mm:ss tt',
      _ => null,
    };

final _standardNumberFormat = RegExp(r'^([NnFfPpCcDd])(\d{0,2})$');

/// The custom format a standard number [format] stands for, or null.
String? _standardNumber(String format, bool ko) {
  final m = _standardNumberFormat.firstMatch(format);
  if (m == null) return null;
  final letter = m[1]!.toUpperCase();
  final given = m[2]!.isEmpty ? null : int.parse(m[2]!);
  String decimals(int n) => n == 0 ? '' : '.${'0' * n}';
  return switch (letter) {
    'N' => '#,##0${decimals(given ?? 2)}',
    'F' => '0${decimals(given ?? 2)}',
    'P' => '#,##0${decimals(given ?? 2)}%',
    'C' => '${ko ? '₩' : r'\$'}#,##0${decimals(given ?? (ko ? 0 : 2))}',
    _ => '0' * (given ?? 1),
  };
}

/// [date] written as [format] says.
String formatDateWith(DateTime date, String format, {String language = 'en'}) {
  final ko = language == 'ko';
  format = _standardDate(format, ko) ??
      (format.length == 2 && format[0] == '%' ? format[1] : format);
  final out = StringBuffer();
  var i = 0;
  int run(String c) {
    var n = 0;
    while (i + n < format.length && format[i + n] == c) {
      n++;
    }
    return n;
  }

  String two(int v) => v.toString().padLeft(2, '0');
  while (i < format.length) {
    final c = format[i];
    if (c == '"' || c == "'") {
      final end = format.indexOf(c, i + 1);
      out.write(format.substring(i + 1, end < 0 ? format.length : end));
      i = end < 0 ? format.length : end + 1;
      continue;
    }
    if (c == r'\' && i + 1 < format.length) {
      out.write(format[i + 1]);
      i += 2;
      continue;
    }
    final n = run(c);
    final hour12 = date.hour % 12 == 0 ? 12 : date.hour % 12;
    switch (c) {
      case 'y':
        out.write(n <= 2
            ? two(date.year % 100)
            : date.year.toString().padLeft(n, '0'));
      case 'M':
        final m = date.month;
        out.write(switch (n) {
          1 => '$m',
          2 => two(m),
          3 => ko ? '$m월' : _monthsEn[m - 1].substring(0, 3),
          _ => ko ? '$m월' : _monthsEn[m - 1],
        });
      case 'd':
        final w = date.weekday - 1;
        out.write(switch (n) {
          1 => '${date.day}',
          2 => two(date.day),
          3 => ko ? _daysKo[w].substring(0, 1) : _daysEn[w].substring(0, 3),
          _ => ko ? _daysKo[w] : _daysEn[w],
        });
      case 'H':
        out.write(n == 1 ? '${date.hour}' : two(date.hour));
      case 'h':
        out.write(n == 1 ? '$hour12' : two(hour12));
      case 'm':
        out.write(n == 1 ? '${date.minute}' : two(date.minute));
      case 's':
        out.write(n == 1 ? '${date.second}' : two(date.second));
      case 't':
        final pm = date.hour >= 12;
        out.write(ko ? (pm ? '오후' : '오전') : (pm ? 'PM' : 'AM'));
      default:
        out.write(c * n);
    }
    i += n;
  }
  return '$out';
}

/// [number] (an `int` or a `double`; or the text of an exact integer, as
/// GuBASIC's 64-bit Integers give it) written as [format] says.
String formatNumberWith(Object number, String format,
    {String language = 'en'}) {
  format = _standardNumber(format, language == 'ko') ??
      (format.length == 2 && format[0] == '%' ? format[1] : format);
  final sections = _sections(format);
  final negative = switch (number) {
    final double d => d < 0,
    final int n => n < 0,
    final String s => s.startsWith('-'),
    _ => false,
  };
  var section = sections.first;
  var sign = negative ? '-' : '';
  if (negative && sections.length > 1) {
    section = sections[1];
    sign = '';
  }
  final pattern = _Pattern(section);
  var (whole, fraction) = _digits(number, pattern.maxDecimals, pattern.percent);
  if (sections.length > 2 && _isZero(whole, fraction)) {
    final zero = _Pattern(sections[2]);
    (whole, fraction) = _digits(0, zero.maxDecimals, zero.percent);
    return zero.write(whole, fraction);
  }
  if (_isZero(whole, fraction)) sign = '';
  return '$sign${pattern.write(whole, fraction)}';
}

bool _isZero(String whole, String fraction) =>
    whole.replaceAll('0', '').isEmpty && fraction.replaceAll('0', '').isEmpty;

/// [format] split at the `;`s outside quotes.
List<String> _sections(String format) {
  final out = <String>[];
  final cur = StringBuffer();
  String? quote;
  for (var i = 0; i < format.length; i++) {
    final c = format[i];
    if (quote != null) {
      if (c == quote) quote = null;
      cur.write(c);
    } else if (c == '"' || c == "'") {
      quote = c;
      cur.write(c);
    } else if (c == r'\' && i + 1 < format.length) {
      cur.write(c + format[++i]);
    } else if (c == ';') {
      out.add('$cur');
      cur.clear();
    } else {
      cur.write(c);
    }
  }
  out.add('$cur');
  return out;
}

/// The digits of [number]'s size, rounded half away from zero to
/// [decimals] places: the whole part and the fraction, [decimals] long.
(String, String) _digits(Object number, int decimals, bool percent) {
  String text;
  switch (number) {
    case final double d:
      text = (percent ? d * 100 : d).abs().toString();
      if (text.contains('e') || text.contains('E')) {
        text = _plain((percent ? d * 100 : d).abs());
      }
    case final int n:
      text = (percent ? n * 100 : n).abs().toString();
    default:
      final s = '$number'.replaceFirst('-', '');
      text = percent ? '${s}00' : s;
  }
  final dot = text.indexOf('.');
  var whole = dot < 0 ? text : text.substring(0, dot);
  var frac = dot < 0 ? '' : text.substring(dot + 1);
  if (frac.length > decimals) {
    final up = frac.codeUnitAt(decimals) >= 0x35; // '5'..'9'
    frac = frac.substring(0, decimals);
    if (up) {
      final all = (BigInt.parse('$whole$frac') + BigInt.one).toString();
      final padded = all.padLeft(whole.length + frac.length, '0');
      whole = padded.substring(0, padded.length - frac.length);
      frac = padded.substring(padded.length - frac.length);
    }
  }
  return (
    whole.replaceFirst(RegExp('^0+(?=.)'), ''),
    frac.padRight(decimals, '0')
  );
}

/// [d] (not negative) in decimal digits, without an exponent.
String _plain(double d) {
  final exp = d.toStringAsExponential();
  final eAt = exp.indexOf('e');
  final mantissa = exp.substring(0, eAt).replaceFirst('.', '');
  final e = int.parse(exp.substring(eAt + 1));
  if (e >= 0) {
    return e + 1 >= mantissa.length
        ? mantissa.padRight(e + 1, '0')
        : '${mantissa.substring(0, e + 1)}.${mantissa.substring(e + 1)}';
  }
  return '0.${'0' * (-e - 1)}$mantissa';
}

class _Pattern {
  _Pattern(String section) {
    var i = 0;
    var seenDigit = false;
    var inFraction = false;
    while (i < section.length) {
      final c = section[i];
      String? literal;
      if (c == '"' || c == "'") {
        final end = section.indexOf(c, i + 1);
        literal = section.substring(i + 1, end < 0 ? section.length : end);
        i = end < 0 ? section.length : end + 1;
      } else if (c == r'\' && i + 1 < section.length) {
        literal = section[i + 1];
        i += 2;
      } else {
        i++;
        if (c == '0' || c == '#') {
          seenDigit = true;
          if (inFraction) {
            maxDecimals++;
            if (c == '0') minDecimals = maxDecimals;
          } else if (c == '0') {
            minWhole++;
          }
          continue;
        }
        if (c == '.' && !inFraction) {
          inFraction = true;
          continue;
        }
        if (c == ',' && seenDigit && !inFraction) {
          grouping = true;
          continue;
        }
        if (c == '%') percent = true;
        literal = c;
      }
      // Text among or after the digits goes after them all.
      if (seenDigit) {
        suffix.write(literal);
      } else {
        prefix.write(literal);
      }
    }
  }

  final prefix = StringBuffer();
  final suffix = StringBuffer();
  var minWhole = 0;
  var minDecimals = 0;
  var maxDecimals = 0;
  var grouping = false;
  var percent = false;

  String write(String whole, String fraction) {
    var w = whole == '0' && minWhole == 0 ? '' : whole;
    w = w.padLeft(minWhole, '0');
    if (grouping && w.length > 3) {
      final b = StringBuffer();
      for (var i = 0; i < w.length; i++) {
        if (i > 0 && (w.length - i) % 3 == 0) b.write(',');
        b.write(w[i]);
      }
      w = '$b';
    }
    var f = fraction;
    while (f.length > minDecimals && f.endsWith('0')) {
      f = f.substring(0, f.length - 1);
    }
    return '$prefix$w${f.isEmpty ? '' : '.$f'}$suffix';
  }
}
