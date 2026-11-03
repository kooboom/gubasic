import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/main.dart';
import 'package:gubasic_ide/src/project/examples.g.dart';
import 'package:gubasic_ide/src/project/project_pictures.dart';
import 'package:gubasic_ide/src/strings.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_test_support/gubasic_test_support.dart';
import 'package:integration_test/integration_test.dart';

/// The LiveQuiz example in the IDE's own window (docs/DESIGN.md D136): the
/// TV's form makes a room on the IDE's own relay server, and a phone, here
/// a WebSocket of the test's speaking the room protocol over a real socket
/// on this computer, joins with the code the TV shows, gets the question
/// and answers it. Run with `dart run gubasic_test_support:integration
/// integration_test/livequiz_test.dart -d macos` (or `-d windows`); the
/// taps are the test's, not the computer's. With `--dart-define=SHOTS=
/// folder` it saves the run window there as `livequiz-PLATFORM.png`.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const shots = String.fromEnvironment('SHOTS');

  testWidgetsKeepingFailures(
    'the TV makes a room, a phone joins and answers over the IDE\'s relay',
    (tester) async {
      await tester.pumpWidget(
        IdeApp(
          projects: {'livequiz': exampleProjects['livequiz']!},
          examplePictures: {
            'livequiz': decodeExamplePictures(examplePictures)['livequiz']!,
          },
          open: 'livequiz',
          strings: IdeStrings.ko,
        ),
      );
      await tester.pumpAndSettle();

      /// The text of the one widget [f] finds: a Text, or the output's
      /// selectable text.
      String textOf(Finder f) => switch (tester.widget(f)) {
        final Text t => t.data ?? '',
        final EditableText t => t.controller.text,
        final other => '$other',
      };

      /// Lets real time pass until [ok] holds.
      Future<void> until(String what, bool Function() ok) async {
        for (var i = 0; i < 200; i++) {
          if (ok()) return;
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 50)),
          );
          await tester.pump();
        }
        fail('waited 10 seconds for $what');
      }

      await tester.tap(find.byKey(const ValueKey('toolbar.run')));
      await until(
        'the start form',
        () => find.byKey(runFormKey('FormStart')).evaluate().isNotEmpty,
      );
      // The output says where the IDE's relay server is.
      final relayLine = find.textContaining('Room 서버: ws://127.0.0.1:');
      expect(relayLine, findsOneWidget);
      final url = RegExp(r'ws://127\.0\.0\.1:\d+/room')
          .firstMatch(textOf(relayLine))![0]!;

      await tester.tap(find.text('TV로 진행'));
      final code = find.textContaining(RegExp(r'^방 코드: [0-9A-Z]{6}$'));
      await until('the room code', () => code.evaluate().isNotEmpty);
      final room = RegExp(r'[0-9A-Z]{6}$').firstMatch(textOf(code))![0]!;

      // The phone.
      final heard = <Map<String, Object?>>[];
      final phone = (await tester.runAsync(() => WebSocket.connect(url)))!;
      addTearDown(phone.close);
      phone.listen(
        (m) => heard.add(jsonDecode(m as String) as Map<String, Object?>),
      );
      void say(Map<String, Object?> m) => phone.add(jsonEncode(m));
      say({'type': 'hello', 'v': 1});
      say({'type': 'join', 'room': room.toLowerCase(), 'nickname': '민지'});
      await until('the phone in the room', () => heard.length >= 2);
      expect(heard[1]['type'], 'entered');
      await until(
        '민지 on the TV',
        () => find.text('민지 0점').evaluate().isNotEmpty,
      );

      await tester.tap(find.text('시작'));
      Map<String, Object?>? from(String kind) => heard
          .where((m) => m['type'] == 'message')
          .map((m) => jsonDecode(m['data']! as String) as Map<String, Object?>)
          .where((d) => d['kind'] == kind)
          .lastOrNull;
      await until('the question', () => from('question') != null);
      final question = from('question')!;
      expect(question['text'], '대한민국의 수도는 어디일까요?');
      say({
        'type': 'sendTo',
        'to': question['host'],
        'data': jsonEncode({'kind': 'answer', 'no': 1, 'choice': 1}),
      });
      await until('the result', () => from('score') != null);
      expect(from('result'), {
        'kind': 'result',
        'no': 1,
        'correct': true,
        'score': 10,
      });
      expect(find.text('정답: 2) 서울'), findsOneWidget);
      expect(find.text('민지 10점'), findsOneWidget);

      if (shots.isNotEmpty) {
        final area = tester.getRect(find.byKey(runFormKey('FormTV')));
        final ratio = tester.view.devicePixelRatio;
        await tester.runAsync(() async {
          final view = tester.binding.renderViews.first;
          final image = await (view.debugLayer! as OffsetLayer).toImage(
            Rect.fromLTRB(
              area.left * ratio,
              (area.top - 40) * ratio,
              area.right * ratio,
              area.bottom * ratio,
            ),
          );
          final png = await image.toByteData(format: ui.ImageByteFormat.png);
          final file = File('$shots/livequiz-${Platform.operatingSystem}.png');
          await file.create(recursive: true);
          await file.writeAsBytes(png!.buffer.asUint8List());
        });
      }
    },
  );
}
