import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'support/memory_folders.dart';

/// A program's settings are kept by its project's name, and File → Clear
/// Saved Settings forgets them (docs/DESIGN.md D48).
void main() {
  const s = IdeStrings.en;
  const demo = {
    'Demo.gbproj':
        'formatVersion: 1\nname: Demo\nstartup: Form1\nforms:\n'
        '  - Form1\n',
    'Form1.form.yaml': 'formatVersion: 1\nproperties:\n  Caption: Demo\n',
    'Form1.gbas':
        'Sub Form_Load()\n'
        '    SaveSetting("runs", CInt(GetSetting("runs", "0")) + 1)\n'
        'End Sub\n',
  };

  Future<GbMemorySettings> start(
    WidgetTester tester, {
    IdeStrings? strings,
  }) async {
    tester.view.physicalSize = const Size(1200, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final settings = GbMemorySettings()..values['Other'] = '{"x":"1"}';
    await tester.pumpWidget(
      IdeApp(
        projects: const {'demo': demo},
        open: 'demo',
        strings: strings ?? s,
        folders: MemoryFolders(),
        pickers: ProjectPickers(
          openProjectFile: (_) async => null,
          saveLocation: (_, _) async => null,
        ),
        settings: settings,
      ),
    );
    return settings;
  }

  Future<void> run(WidgetTester tester) async {
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.pumpAndSettle();
    await tester.sendKeyDownEvent(LogicalKeyboardKey.shift);
    await tester.sendKeyEvent(LogicalKeyboardKey.f5);
    await tester.sendKeyUpEvent(LogicalKeyboardKey.shift);
    await tester.pumpAndSettle();
  }

  testWidgets('a run keeps its settings by the project name; Clear Saved '
      'Settings forgets only them', (tester) async {
    final settings = await start(tester);
    await run(tester);
    await run(tester);
    expect(settings.values['Demo'], '{"runs":"2"}');

    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.clearSettings));
    await tester.pumpAndSettle();
    expect(find.textContaining('program of Demo saved'), findsOneWidget);
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();
    expect(settings.values['Demo'], isNotNull);

    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.clearSettings));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.clearSettingsYes));
    await tester.pumpAndSettle();
    expect(settings.values, {'Other': '{"x":"1"}'});
    expect(
      find.text('The saved settings of Demo were cleared.'),
      findsOneWidget,
    );
  });

  testWidgets('Korean words', (tester) async {
    await start(tester, strings: IdeStrings.ko);
    await tester.tap(find.text(IdeStrings.ko.fileMenu));
    await tester.pumpAndSettle();
    expect(find.text('저장된 설정 지우기…'), findsOneWidget);
    await tester.tap(find.text('저장된 설정 지우기…'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Demo 프로젝트의 프로그램이'), findsOneWidget);
  });
}
