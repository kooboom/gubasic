import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/licenses.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_test_support/gubasic_test_support.dart';
import 'package:integration_test/integration_test.dart';

/// The open source licences in the IDE's own window (D120): 정보 →
/// 오픈소스 라이선스 shows GuBASIC, the three fonts and Flutter's packages.
/// With `--dart-define=SHOTS=folder` it saves the page there as
/// `licenses-PLATFORM.png`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const shots = String.fromEnvironment('SHOTS');

  testWidgetsKeepingFailures('정보 → 오픈소스 라이선스', (tester) async {
    addIdeLicenses();
    await tester.pumpWidget(
      IdeApp(
        projects: {'hello': exampleProjects['hello']!},
        strings: IdeStrings.ko,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.info')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('오픈소스 라이선스'));
    for (
      var i = 0;
      i < 100 && find.text('Pretendard').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    for (final name in ['GuBASIC', 'Pretendard', 'D2Coding', 'NanumGothic']) {
      expect(find.text(name), findsWidgets, reason: name);
    }
    // The page slides in. (Flutter's own and the packages' licences come
    // from its NOTICES file, which a test binding does not read.)
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    if (shots.isNotEmpty) {
      await tester.runAsync(() async {
        final view = tester.binding.renderViews.first;
        final image = await (view.debugLayer! as OffsetLayer).toImage(
          Offset.zero & (view.size * tester.view.devicePixelRatio),
        );
        final png = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('$shots/licenses-${Platform.operatingSystem}.png');
        await file.create(recursive: true);
        await file.writeAsBytes(png!.buffer.asUint8List());
      });
    }
  });
}
