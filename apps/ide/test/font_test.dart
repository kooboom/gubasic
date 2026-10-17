import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_ide/src/theme.dart';

void main() {
  test('the font and its license are in the app', () {
    for (final f in [
      'fonts/NotoSansKR-Regular.otf',
      'fonts/NotoSansKR-Bold.otf',
      'fonts/OFL.txt',
    ]) {
      expect(File(f).existsSync(), isTrue, reason: f);
    }
    expect(
      File('fonts/OFL.txt').readAsStringSync(),
      contains('SIL Open Font License'),
    );
  });

  test('the code font is an asset, not a font the first visit fetches', () {
    const font = 'fonts/d2coding/D2Coding-Ver1.3.2-20180524.ttf';
    expect(File(font).existsSync(), isTrue);
    expect(
      File('fonts/d2coding/OFL.txt').readAsStringSync(),
      allOf(contains('SIL Open Font License'), contains('NHN Corporation')),
    );
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final fonts = pubspec.substring(pubspec.indexOf('  fonts:'));
    expect(fonts, isNot(contains('d2coding')), reason: 'not under fonts:');
    expect(pubspec, contains('    - $font'), reason: 'under assets:');
  });

  testWidgets('the IDE uses the bundled font everywhere', (tester) async {
    await tester.pumpWidget(
      IdeApp(projects: exampleProjects, strings: IdeStrings.en),
    );
    final theme = Theme.of(tester.element(find.text('Hello').first));
    expect(theme.textTheme.bodyMedium!.fontFamily, ideFontFamily);
    expect(codeStyle.fontFamilyFallback, [ideFontFamily]);
  });
}
