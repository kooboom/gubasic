import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/designer/properties_panel.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/explorer.dart';

/// The form's FontSize, FontBold and ForeColor in the Properties window
/// (docs/DESIGN.md D137): a number in a range, a colour by name or from
/// the list, a third state for "not set", and empty for not set.
void main() {
  const s = IdeStrings.en;
  const formFile = 'Form1.form.yaml';

  Future<void> open(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(projects: {'hello': exampleProjects['hello']!}, strings: s),
    );
    await tester.tap(explorerItem(formFile));
    await tester.pumpAndSettle();
  }

  String formText(WidgetTester tester) => tester
      .widget<IdeShell>(find.byType(IdeShell))
      .controller
      .current
      .files[formFile]!;

  Future<void> type(WidgetTester tester, String property, String text) async {
    await tester.enterText(find.byKey(propertyFieldKey(property)), text);
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pumpAndSettle();
  }

  testWidgets('FontSize, ForeColor and FontBold of the form', (tester) async {
    await open(tester);
    final before = formText(tester);
    expect(before, isNot(contains('FontSize')));

    await type(tester, 'FontSize', '12');
    expect(formText(tester), contains('  FontSize: 12.0\n'));
    await type(tester, 'FontSize', '500');
    expect(find.text('FontSize takes a number from 1 to 200.'), findsOneWidget);
    await type(tester, 'FontSize', '');
    expect(formText(tester), isNot(contains('FontSize')));

    await type(tester, 'ForeColor', 'skyblue');
    expect(formText(tester), contains('  ForeColor: SkyBlue\n'));
    await type(tester, 'ForeColor', '#ff8800');
    expect(formText(tester), contains('  ForeColor: "#FF8800"\n'));
    await type(tester, 'ForeColor', 'reddish');
    expect(find.textContaining('takes a colour\'s name'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('colors.ForeColor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Navy').last);
    await tester.pumpAndSettle();
    expect(formText(tester), contains('  ForeColor: Navy\n'));
    await tester.tap(find.byKey(const ValueKey('colors.ForeColor')));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.notSet).last);
    await tester.pumpAndSettle();
    expect(formText(tester), isNot(contains('ForeColor')));

    // Not set, False, True, and not set again.
    Checkbox bold() =>
        tester.widget<Checkbox>(find.byKey(propertyFieldKey('FontBold')));
    expect(bold().value, isNull);
    await tester.tap(find.byKey(propertyFieldKey('FontBold')));
    await tester.pumpAndSettle();
    expect(formText(tester), contains('  FontBold: false\n'));
    await tester.tap(find.byKey(propertyFieldKey('FontBold')));
    await tester.pumpAndSettle();
    expect(formText(tester), contains('  FontBold: true\n'));
    await tester.tap(find.byKey(propertyFieldKey('FontBold')));
    await tester.pumpAndSettle();
    expect(formText(tester), before);
  });
}
