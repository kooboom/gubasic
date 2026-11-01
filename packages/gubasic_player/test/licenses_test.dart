import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// The open source licences (docs/DESIGN.md D120).
void main() {
  test("GuBASIC's licence is the repository's LICENSE", () {
    expect(gubasicLicense, File('../../LICENSE').readAsStringSync());
  });

  test('GuBASIC and the fonts join Flutter\'s licences; a font the app '
      'does not carry is left out', () async {
    addGubasicLicenses({
      'TestFont': () async => 'the font licence',
      'Missing': () async => null,
    });
    final entries = await LicenseRegistry.licenses.toList();
    final packages = [for (final e in entries) ...e.packages];
    expect(packages, containsAll(['GuBASIC', 'TestFont']));
    expect(packages, isNot(contains('Missing')));
  });

  test('the notices beside an exported app: GuBASIC, the fonts, Flutter', () {
    final text = thirdPartyNotices(
      fonts: {'Pretendard': 'OFL text'},
      flutter: 'engine licences',
    );
    expect(text.indexOf('MIT License'), lessThan(text.indexOf('OFL text')));
    expect(text.indexOf('OFL text'), lessThan(text.indexOf('engine')));
    expect(text, contains('Pretendard (font)'));
  });

  testWidgets('on macOS the app menu has the licences under About', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      var shown = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: SystemMenus(
            appName: 'Demo',
            strings: PlayerStrings.ko,
            onLicenses: () => shown++,
            child: const SizedBox(),
          ),
        ),
      );
      final app =
          tester.widget<PlatformMenuBar>(find.byType(PlatformMenuBar)).menus[0]
              as PlatformMenu;
      final item = [
        for (final g in app.menus)
          for (final i in (g as PlatformMenuItemGroup).members)
            if (i.label == '오픈소스 라이선스') i,
      ].single;
      item.onSelected!();
      expect(shown, 1);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
