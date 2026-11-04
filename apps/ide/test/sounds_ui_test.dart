import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/ide_shell.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/open_project.dart';
import 'package:gubasic_ide/src/project/project_controller.dart';
import 'package:gubasic_ide/src/project/sounds_dialog.dart';
import 'package:gubasic_ide/src/strings.dart';

import 'support/memory_folders.dart';

/// File → Sounds (docs/DESIGN.md D138): a sound chosen in the system's
/// dialog goes into the project and its group in the file list; Remove
/// takes it out after asking; what is not a sound is refused and said.
void main() {
  const s = IdeStrings.en;
  late MemoryFolders fs;
  late List<PickedSound?> picks;

  final wav = Uint8List.fromList([
    ...'RIFF'.codeUnits, 36, 0, 0, 0, ...'WAVE'.codeUnits, //
    ...'fmt '.codeUnits, 16, 0, 0, 0, 1, 0, 1, 0, 0x44, 0xAC, 0, 0, //
    0x88, 0x58, 1, 0, 2, 0, 16, 0, ...'data'.codeUnits, 0, 0, 0, 0,
  ]);

  setUp(() {
    fs = MemoryFolders()..folders.add('/home');
    picks = [];
  });

  Future<void> start(WidgetTester tester) async {
    tester.view.physicalSize = const Size(1400, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      IdeApp(
        projects: exampleProjects,
        strings: s,
        folders: fs,
        pickers: ProjectPickers(
          openProjectFile: (_) async => null,
          saveLocation: (_, _) async => null,
          openSound: (_) async => picks.removeAt(0),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  OpenProject current(WidgetTester tester) =>
      tester.widget<IdeShell>(find.byType(IdeShell)).controller.current;

  Future<void> openSounds(WidgetTester tester) async {
    await tester.tap(find.text(s.fileMenu));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('menu.sounds')));
    await tester.pumpAndSettle();
  }

  Future<void> add(WidgetTester tester, PickedSound? pick) async {
    picks.add(pick);
    await tester.tap(find.byKey(addSoundKey));
    await tester.pumpAndSettle();
  }

  testWidgets('a sound is added, listed, and taken out after asking', (
    tester,
  ) async {
    await start(tester);
    await openSounds(tester);
    expect(find.text(s.noSounds), findsOneWidget);
    await add(tester, (name: 'shot.wav', bytes: wav));
    expect(current(tester).sounds.keys, ['shot.wav']);
    expect(find.byKey(soundRowKey('shot.wav')), findsOneWidget);
    expect(current(tester).files['Hello.gbproj'], contains('- shot.wav'));
    // Not a sound: refused and said; nothing changes.
    await add(tester, (name: 'notes.txt', bytes: Uint8List.fromList([1, 2])));
    expect(
      find.text(s.soundNotTaken.replaceAll('{0}', 'notes.txt')),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.ok).last);
    await tester.pumpAndSettle();
    expect(current(tester).sounds.keys, ['shot.wav']);
    // Close the window: the file list has a Sounds group.
    await tester.tap(find.text(s.runtime.ok).last);
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('files.sounds')), findsOneWidget);
    expect(find.text('shot.wav'), findsOneWidget);
    // Remove asks; No keeps it, Remove takes it out.
    await tester.tap(find.byKey(const ValueKey('files.sounds')));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip(s.removeSound));
    await tester.pumpAndSettle();
    expect(
      find.text(s.confirmRemoveSound.replaceAll('{0}', 'shot.wav')),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.cancel).last);
    await tester.pumpAndSettle();
    expect(current(tester).sounds.keys, ['shot.wav']);
    await tester.tap(find.byTooltip(s.removeSound));
    await tester.pumpAndSettle();
    await tester.tap(find.text(s.removeSound).last);
    await tester.pumpAndSettle();
    expect(current(tester).sounds, isEmpty);
    expect(find.text(s.noSounds), findsOneWidget);
    expect(current(tester).files['Hello.gbproj'], isNot(contains('sounds:')));
  });
}
