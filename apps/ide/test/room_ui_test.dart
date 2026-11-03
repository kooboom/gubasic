import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/browser.dart';
import 'package:gubasic_ide/src/project/local_relay.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_player/gubasic_player.dart';

import 'support/fake_browser.dart';

/// Room in the IDE (docs/DESIGN.md D136): a program whose Room has no
/// Server runs on the IDE's own relay server, whose address the output
/// gives; "Allow devices on the same network" is off at first and asks
/// before it is turned on; an export warns about a Room without a Server
/// (A078).
class _FakeRelay implements LocalRelay {
  var started = 0;
  var on = false;

  @override
  bool get available => true;

  @override
  Future<String?> start() async {
    started++;
    return localAddress;
  }

  @override
  String? get localAddress => started == 0 ? null : 'ws://127.0.0.1:53421/room';

  @override
  bool get sameNetwork => on;

  @override
  Future<void> setSameNetwork(bool value) async {
    if (started == 0) started++;
    on = value;
  }

  @override
  Future<List<String>> networkAddresses() async =>
      on ? ['ws://192.0.2.10:53421/room'] : const [];

  @override
  Future<void> close() async {}
}

void main() {
  const quiz = {
    'Quiz.gbproj':
        'formatVersion: 1\nname: Quiz\nstartup: Form1\nforms:\n  - Form1\n',
    'Form1.form.yaml':
        'formatVersion: 1\ncontrols:\n'
        '  - { name: rmQuiz, type: Room }\n',
    'Form1.gbas': 'Sub Form_Load()\n    Debug.Print("hi")\nEnd Sub\n',
  };

  void bigView(WidgetTester tester) {
    tester.view.physicalSize = const Size(1400, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  Future<void> openDebugMenu(WidgetTester tester, IdeStrings s) async {
    await tester.tap(find.byKey(const ValueKey('menu.debug')));
    await tester.pumpAndSettle();
  }

  bool checked(WidgetTester tester) =>
      tester.widget<CheckboxMenuButton>(find.byType(CheckboxMenuButton)).value!;

  for (final s in [IdeStrings.en, IdeStrings.ko]) {
    testWidgets('a Room without a Server runs on the IDE\'s relay server '
        '(${s == IdeStrings.en ? 'en' : 'ko'})', (tester) async {
      bigView(tester);
      final relay = _FakeRelay();
      await tester.pumpWidget(
        IdeApp(
          projects: const {'quiz': quiz},
          open: 'quiz',
          strings: s,
          relay: relay,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('toolbar.run')));
      await tester.pumpAndSettle();
      expect(relay.started, 1);
      expect(find.byType(RunWindow), findsOneWidget);
      expect(
        find.text(
          s.roomServerHere.replaceAll('{0}', 'ws://127.0.0.1:53421/room'),
        ),
        findsOneWidget,
      );

      // Off at first; turning it on asks, and Cancel leaves it off.
      await openDebugMenu(tester, s);
      expect(checked(tester), isFalse);
      await tester.tap(find.byType(CheckboxMenuButton));
      await tester.pumpAndSettle();
      expect(find.text(s.sameNetworkWarning), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('sameNetworkCancel')));
      await tester.pumpAndSettle();
      expect(relay.on, isFalse);

      await openDebugMenu(tester, s);
      await tester.tap(find.byType(CheckboxMenuButton));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('sameNetworkOk')));
      await tester.pumpAndSettle();
      expect(relay.on, isTrue);
      expect(
        find.text(
          s.roomServerNetwork.replaceAll('{0}', 'ws://192.0.2.10:53421/room'),
        ),
        findsOneWidget,
      );

      // Turning it off asks nothing.
      await openDebugMenu(tester, s);
      expect(checked(tester), isTrue);
      await tester.tap(find.byType(CheckboxMenuButton));
      await tester.pumpAndSettle();
      expect(find.text(s.sameNetworkWarning), findsNothing);
      expect(relay.on, isFalse);
      expect(find.textContaining('192.0.2.10'), findsNothing);
    });
  }

  testWidgets('a program without a Room starts no relay server', (
    tester,
  ) async {
    bigView(tester);
    final relay = _FakeRelay();
    final plain = Map.of(quiz)
      ..['Form1.form.yaml'] = 'formatVersion: 1\n'
      ..['Quiz.gbproj'] = quiz['Quiz.gbproj']!;
    await tester.pumpWidget(
      IdeApp(
        projects: {'quiz': plain},
        open: 'quiz',
        strings: IdeStrings.en,
        relay: relay,
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('toolbar.run')));
    await tester.pumpAndSettle();
    expect(relay.started, 0);
    expect(find.textContaining('Room server'), findsNothing);
  });

  testWidgets('exporting a Room without a Server warns first (A078)', (
    tester,
  ) async {
    bigView(tester);
    const s = IdeStrings.ko;
    final browser = FakeBrowser();
    final archive = Archive()
      ..add(ArchiveFile.bytes('index.html', utf8.encode('<html></html>')))
      ..add(
        ArchiveFile.bytes(
          'template.json',
          utf8.encode(
            '{"gubasic":"0.6.0","bundleFormat":$bundleFormatVersion}',
          ),
        ),
      );
    await tester.pumpWidget(
      IdeApp(
        projects: const {'quiz': quiz},
        open: 'quiz',
        strings: s,
        browser: browser,
        kept: await BrowserProjects.open(browser.projects, browser.storage),
        pickZip: () async => null,
        fetchTemplate: (_) async =>
            Uint8List.fromList(ZipEncoder().encodeBytes(archive)),
      ),
    );
    Future<void> export() async {
      await tester.tap(find.text(s.fileMenu));
      await tester.pumpAndSettle();
      await tester.tap(find.text(s.exportWebApp));
      await tester.pumpAndSettle();
    }

    await export();
    expect(
      find.text(
        'Form1.rmQuiz 컨트롤의 Server가 비어 있어 앱에 중계 서버가 없습니다. '
        'docs/RELAY_SERVER.ko.md대로 자기 서버 주소를 넣어 주세요.',
      ),
      findsOneWidget,
    );
    await tester.tap(find.text(s.runtime.cancel));
    await tester.pumpAndSettle();
    expect(browser.downloads, isEmpty);

    await export();
    await tester.tap(find.text(s.exportAnyway));
    await tester.pumpAndSettle();
    expect(browser.downloads.single.$1, 'Quiz-web.zip');
  });
}
