import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// The pointer shows waiting while the program's Http waits for an answer
/// (docs/DESIGN.md D124 A, D125), and the run host's Http object turns
/// the runtime's replies and errors into the component's.
class _SlowHttp implements GbHttp {
  final completer = Completer<GbHttpReply>();
  GbHttpRequest? last;

  @override
  Future<GbHttpReply> send(GbHttpRequest request, Duration timeout) {
    last = request;
    return completer.future;
  }
}

void main() {
  final form = readFormFile(
    'formatVersion: 1\ncontrols: []\n',
    name: 'Form1',
  ).form;

  testWidgets('the pointer waits from the request to its answer', (
    tester,
  ) async {
    final http = _SlowHttp();
    final host = RunHost(form, http: http);
    await tester.pumpWidget(
      MaterialApp(
        home: WaitingPointer(host: host, child: const SizedBox.expand()),
      ),
    );
    expect(find.byKey(waitingPointerKey), findsNothing);
    final component = host.createComponent('Http')!;
    component.setProperty('Timeout', GbInt.of(9));
    component.assign('Header', ['X-A'], 'b');
    final answer = component.call('Get', ['http://x/a']);
    await tester.pump();
    expect(find.byKey(waitingPointerKey), findsOneWidget);
    expect(
      tester.widget<MouseRegion>(find.byKey(waitingPointerKey)).cursor,
      SystemMouseCursors.wait,
    );
    expect(http.last!.method, 'GET');
    expect(http.last!.url, 'http://x/a');
    expect(http.last!.headers, {'X-A': 'b'});
    expect(http.last!.body, isNull);
    http.completer.complete(
      GbHttpReply(200, {'content-type': 'text/plain'}, 'ok'.codeUnits),
    );
    expect(await answer, 'ok');
    await tester.pump();
    expect(find.byKey(waitingPointerKey), findsNothing);
    expect(host.createComponent('Other'), isNull);
  });

  test(
    'no answer becomes the component\'s failure, and the count goes back',
    () async {
      final http = _SlowHttp();
      final host = RunHost(form, http: http);
      final component = host.createComponent('Http')!;
      final answer = component.call('Get', ['http://x/a']);
      expect(host.busyRequests.value, 1);
      http.completer.completeError(const GbHttpError('no route'));
      await expectLater(
        answer,
        throwsA(
          isA<ComponentProblem>()
              .having((p) => p.code, 'code', DiagnosticCode.httpFailed)
              .having((p) => p.args, 'args', ['http://x/a', 'no route']),
        ),
      );
      expect(host.busyRequests.value, 0);
    },
  );
}
