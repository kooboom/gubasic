import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_player_app/src/player_app.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';
import 'package:gubasic_test_support/gubasic_test_support.dart';
import 'package:integration_test/integration_test.dart';

/// Database in an exported desktop app (docs/DESIGN.md D126): the program
/// makes a table, puts rows in with values for the ?s, reads them back
/// with Query and Scalar, through the SQLite the app carries, in the file
/// under the user's application support folder (on macOS, inside the
/// sandbox). Run with `flutter test integration_test/database_test.dart -d
/// macos` (or `-d windows`); the click is the test's, not the computer's.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgetsKeepingFailures('Execute, Query, Scalar and the file', (
    tester,
  ) async {
    // The app's own file: GuBASIC/<project name>/data.db.
    final path = GbSqlite().pathOf('DatabaseCheck', 'data.db');
    addTearDown(() async {
      final file = File(path);
      try {
        if (await file.exists()) await file.parent.delete(recursive: true);
      } on FileSystemException {
        // Still open: the folder stays, as any app's data would.
      }
    });
    final files = {
      'DatabaseCheck.gbproj':
          'formatVersion: 1\nname: DatabaseCheck\nstartup: Form1\nforms:\n'
          '  - Form1\n',
      'Form1.form.yaml':
          'formatVersion: 1\nproperties:\n  Width: 320\n  Height: 120\n'
          'controls:\n'
          '  - name: btnGo\n    type: Button\n    properties:\n'
          '      Caption: Go\n'
          '  - name: lblOut\n    type: Label\n    properties:\n'
          '      Top: 40\n      Width: 300\n',
      'Form1.gbas':
          'Sub btnGo_Click()\n'
          '    Database.Execute("DROP TABLE IF EXISTS scores")\n'
          '    Database.Execute("CREATE TABLE scores (name TEXT, points REAL)")\n'
          '    Database.Execute("INSERT INTO scores VALUES (?, ?)", "김하나", 91.5)\n'
          '    Database.Execute("INSERT INTO scores VALUES (?, ?)", "O\'Brien", 78)\n'
          '    Dim t As Table = Database.Query("SELECT name, points FROM scores ORDER BY points")\n'
          '    lblOut.Caption = t.Cell(0, "name") & " " & t.Cell(1, "points") & " " & Database.Scalar("SELECT COUNT(*) FROM scores") & " " & Database.LastId\n'
          // Closed, so that the file can be deleted while the app runs.
          '    Database.Close()\n'
          'End Sub\n',
    };
    await tester.pumpWidget(
      PlayerApp(files: files, strings: PlayerStrings.en, asApp: true),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Go'));
    for (
      var i = 0;
      i < 100 && find.text("O'Brien 91.5 2 2").evaluate().isEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    expect(find.text("O'Brien 91.5 2 2"), findsOneWidget);
    expect(File(path).existsSync(), isTrue, reason: path);
    // An SQLite file starts with its header string.
    expect(
      String.fromCharCodes(File(path).readAsBytesSync().take(15)),
      'SQLite format 3',
    );
  });
}
