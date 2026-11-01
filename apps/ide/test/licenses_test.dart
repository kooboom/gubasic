import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/licenses.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

/// The open source licences (docs/DESIGN.md D120): 정보 → 오픈소스 라이선스
/// shows Flutter's licence page, which has GuBASIC's and the three fonts'.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test("GuBASIC's and the three fonts' licences join Flutter's", () async {
    addIdeLicenses();
    final entries = await LicenseRegistry.licenses.toList();
    final packages = [for (final e in entries) ...e.packages];
    expect(
      packages,
      containsAll(['GuBASIC', 'Pretendard', 'D2Coding', 'NanumGothic']),
    );
    final d2coding = entries.firstWhere((e) => e.packages.contains('D2Coding'));
    expect(
      d2coding.paragraphs.map((p) => p.text).join(' '),
      contains('SIL OPEN FONT LICENSE'),
    );
  });

  testWidgets('정보 → 오픈소스 라이선스 opens the licence page', (tester) async {
    tester.view.physicalSize = const Size(1600, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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
    // The menu closes first, then the page comes.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.byType(LicensePage), findsOneWidget);
  });
}
