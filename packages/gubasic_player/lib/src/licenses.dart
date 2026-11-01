import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'bundle.dart';

/// GuBASIC's own licence, as `LICENSE` at the top of the repository has it
/// (a test keeps them the same).
const gubasicLicense = r'''
MIT License

Copyright (c) 2026 Jungmo Gu

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
''';

/// The fonts an app of GuBASIC may carry (docs/DESIGN.md D120), by name.
const pretendardFont = 'Pretendard';
const d2codingFont = 'D2Coding';
const nanumGothicFont = 'NanumGothic';

/// Adds to Flutter's licences, which name its engine and the packages, the
/// ones its NOTICES file does not have (D120): GuBASIC's own, and each of
/// [fonts]' licence text, which [fonts] gives when asked: font name →
/// text, or null for a font the app does not carry.
void addGubasicLicenses(Map<String, Future<String?> Function()> fonts) {
  LicenseRegistry.addLicense(() async* {
    yield const LicenseEntryWithLineBreaks(['GuBASIC'], gubasicLicense);
    for (final MapEntry(:key, :value) in fonts.entries) {
      final text = await value();
      if (text != null) yield LicenseEntryWithLineBreaks([key], text);
    }
  });
}

/// Flutter's licence page, with GuBASIC's name, version and copyright.
void showGubasicLicenses(BuildContext context) => showLicensePage(
  context: context,
  applicationName: 'GuBASIC',
  applicationVersion: gubasicVersion,
  applicationLegalese: '© 2026 Jungmo Gu · MIT',
);

/// The notices an exported web or Windows app carries beside it, as
/// `THIRD_PARTY_NOTICES.txt` (D120): GuBASIC's licence, the [fonts]'
/// (name → text), then [flutter], the player's NOTICES file: Flutter's
/// engine and the packages.
String thirdPartyNotices({
  required Map<String, String> fonts,
  required String flutter,
}) {
  const line =
      '--------------------------------------------------------------------'
      '------------';
  return [
    'GuBASIC $gubasicVersion: what this app is made with, and their licences.',
    '',
    line,
    'GuBASIC',
    '',
    gubasicLicense.trim(),
    for (final MapEntry(:key, :value) in fonts.entries) ...[
      line,
      '$key (font)',
      '',
      value.trim(),
    ],
    line,
    'Flutter and the packages it uses',
    '',
    flutter.trim(),
    '',
  ].join('\n');
}

/// The name of the notices file beside an exported web or Windows app.
const thirdPartyNoticesFile = 'THIRD_PARTY_NOTICES.txt';
