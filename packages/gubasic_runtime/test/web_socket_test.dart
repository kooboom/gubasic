import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// GbWebSocket (docs/DESIGN.md D136) against a real WebSocket server on
/// localhost.
void main() {
  late HttpServer server;
  late String url;
  final fromProgram = <String>[];
  WebSocket? serverSide;

  setUp(() async {
    fromProgram.clear();
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    url = 'ws://127.0.0.1:${server.port}/chat';
    server.listen((request) async {
      if (request.uri.path != '/chat') {
        request.response.statusCode = 404;
        await request.response.close();
        return;
      }
      final ws = serverSide = await WebSocketTransformer.upgrade(request);
      ws.add('welcome');
      ws.listen((m) {
        fromProgram.add('$m');
        if (m == 'bye') ws.close(1000, 'see you');
      });
    });
  });

  tearDown(() => server.close(force: true));

  test('connects, sends, hears messages and the close', () async {
    final messages = <String>[];
    final closed = Completer<String>();
    final socket = await GbWebSocket().connect(
      url,
      onMessage: messages.add,
      onClosed: closed.complete,
      onError: (e) => fail('error: $e'),
    );
    socket.send('hello');
    socket.send('bye');
    expect(await closed.future, 'see you');
    expect(messages, ['welcome']);
    expect(fromProgram, ['hello', 'bye']);
  });

  test(
    'closed by the server without a reason, it says what happened',
    () async {
      final closed = Completer<String>();
      await GbWebSocket().connect(
        url,
        onMessage: (_) {},
        onClosed: closed.complete,
        onError: (_) {},
      );
      while (serverSide == null) {
        await Future<void>.delayed(const Duration(milliseconds: 5));
      }
      await serverSide!.close();
      expect(await closed.future, startsWith('closed ('));
    },
  );

  test('closing it itself tells nothing', () async {
    var told = false;
    final socket = await GbWebSocket().connect(
      url,
      onMessage: (_) {},
      onClosed: (_) => told = true,
      onError: (_) => told = true,
    );
    socket.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    expect(told, isFalse);
  });

  test('an address that cannot be opened is a GbWebSocketError', () async {
    Future<void> open(String address) => GbWebSocket().connect(
      address,
      onMessage: (_) {},
      onClosed: (_) {},
      onError: (_) {},
    );
    await expectLater(
      open('http://127.0.0.1:${server.port}/chat'),
      throwsA(
        isA<GbWebSocketError>().having(
          (e) => e.detail,
          'detail',
          'not a ws:// or wss:// address',
        ),
      ),
    );
    await expectLater(
      open('ws://127.0.0.1:${server.port}/nowhere'),
      throwsA(isA<GbWebSocketError>()),
    );
    final port = server.port;
    await server.close(force: true);
    await expectLater(
      open('ws://127.0.0.1:$port/chat'),
      throwsA(isA<GbWebSocketError>()),
    );
  });
}
