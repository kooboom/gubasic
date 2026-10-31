import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_player_app/src/player_app.dart';
import 'package:integration_test/integration_test.dart';

/// Text files in an exported desktop app (docs/DESIGN.md D113): the
/// program writes a CSV file, with a BOM, adds to it and reads it back,
/// through the app's own file system (on macOS, inside its sandbox). Run
/// with `flutter test integration_test/files_test.dart -d macos` (or `-d
/// windows`); the click is the test's, not the computer's.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('WriteAllText, AppendAllText, ReadAllLines', (tester) async {
    final dir = await Directory.systemTemp.createTemp('gubasic');
    addTearDown(() => dir.delete(recursive: true));
    final path = '${dir.path}${Platform.pathSeparator}점수.csv';
    final files = {
      'Files.gbproj':
          'formatVersion: 1\nname: Files\nstartup: Form1\nforms:\n'
          '  - Form1\n',
      'Form1.form.yaml':
          'formatVersion: 1\nproperties:\n  Width: 320\n  Height: 120\n'
          'controls:\n'
          '  - name: btnGo\n    type: Button\n    properties:\n'
          '      Caption: Go\n'
          '  - name: lblPath\n    type: Label\n    properties:\n'
          // Single quotes: a Windows path's backslashes stay as they are.
          "      Caption: '$path'\n      Top: 40\n      Width: 300\n",
      'Form1.gbas':
          'Sub btnGo_Click()\n'
          '    File.WriteAllText(lblPath.Caption, "이름,점수" & vbCrLf)\n'
          '    File.AppendAllText(lblPath.Caption, "김하나,90" & vbCrLf)\n'
          '    Dim lines = File.ReadAllLines(lblPath.Caption)\n'
          '    lblPath.Caption = lines(1) & " " & File.Exists(lblPath.Caption)\n'
          'End Sub\n',
    };
    await tester.pumpWidget(
      PlayerApp(files: files, strings: PlayerStrings.en, asApp: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    for (
      var i = 0;
      i < 50 && find.text('김하나,90 True').evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text('김하나,90 True'), findsOneWidget);
    expect(File(path).readAsBytesSync().take(3), [0xEF, 0xBB, 0xBF]);
  });
}
