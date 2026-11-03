import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:gubasic_relay/gubasic_relay.dart';
import 'package:test/test.dart';

/// The relay server over real WebSockets on localhost (D136).
class _Client {
  _Client._(this.socket) {
    socket.listen(
        (m) => _inbox.add(jsonDecode(m as String) as Map<String, Object?>));
  }

  static Future<_Client> open(int port, {Map<String, String>? headers}) async =>
      _Client._(await WebSocket.connect('ws://127.0.0.1:$port/room',
          headers: headers));

  final WebSocket socket;
  final _inbox = StreamController<Map<String, Object?>>();
  late final _queue = StreamIterator(_inbox.stream);

  void say(Map<String, Object?> m) => socket.add(jsonEncode(m));

  Future<Map<String, Object?>> next() async {
    if (!await _queue.moveNext().timeout(const Duration(seconds: 5))) {
      throw StateError('closed');
    }
    return _queue.current;
  }
}

void main() {
  late RelayServer server;

  Future<void> start([RelayConfig config = const RelayConfig()]) async {
    server = await RelayServer.start(config.listeningOn('127.0.0.1', 0),
        hub: RoomHub(
            config: config, codes: RoomCodes.fixed(['K7QPXM', 'ABCDEF'])));
  }

  tearDown(() => server.close());

  test('two programs in a room over real sockets, and health', () async {
    await start();
    final tv = await _Client.open(server.port);
    tv.say({'type': 'hello', 'v': 1});
    expect(await tv.next(), {'type': 'welcome', 'v': 1});
    tv.say({'type': 'create', 'nickname': 'TV'});
    expect((await tv.next())['room'], 'K7QPXM');

    final phone = await _Client.open(server.port);
    phone.say({'type': 'hello', 'v': 1});
    await phone.next();
    phone.say({'type': 'join', 'room': 'K7QPXM', 'nickname': '민지'});
    expect((await phone.next())['type'], 'entered');
    expect(
        await tv.next(), {'type': 'joined', 'member': 'm2', 'nickname': '민지'});
    phone.say({'type': 'send', 'data': '{"choice":2}'});
    expect(await tv.next(),
        {'type': 'message', 'from': 'm2', 'data': '{"choice":2}'});

    final health = await (await (await HttpClient().getUrl(
                Uri.parse('http://127.0.0.1:${server.port}/room/health')))
            .close())
        .transform(utf8.decoder)
        .join();
    expect(jsonDecode(health), {'gubasicRelay': relayVersion, 'rooms': 1});

    await server.close();
    expect(await tv.next(), {'type': 'closed', 'reason': 'server'});
  });

  test('allowedOrigins: a page not in the list is refused', () async {
    await start(
        const RelayConfig(allowedOrigins: ['https://quiz.example.com']));
    await expectLater(
        _Client.open(server.port,
            headers: {'Origin': 'https://other.example.org'}),
        throwsA(isA<WebSocketException>()));
    final ok = await _Client.open(server.port,
        headers: {'Origin': 'https://quiz.example.com'});
    ok.say({'type': 'hello', 'v': 1});
    expect((await ok.next())['type'], 'welcome');
    // A program that is not a web page sends no Origin.
    final app = await _Client.open(server.port);
    app.say({'type': 'hello', 'v': 1});
    expect((await app.next())['type'], 'welcome');
  });

  test('a key', () async {
    await start(const RelayConfig(key: 'door'));
    final c = await _Client.open(server.port);
    c.say({'type': 'hello', 'v': 1, 'key': 'window'});
    expect(await c.next(), {'type': 'error', 'code': 'bad-key'});
    await c.socket.done;
    expect(c.socket.closeCode, 1008);
  });

  test('rebind keeps the port, the rooms and the connections', () async {
    await start();
    final tv = await _Client.open(server.port);
    tv.say({'type': 'hello', 'v': 1});
    await tv.next();
    tv.say({'type': 'create'});
    await tv.next();
    final port = server.port;
    await server.rebind(InternetAddress.anyIPv4.address);
    expect(server.port, port);
    final phone = await _Client.open(port);
    phone.say({'type': 'hello', 'v': 1});
    await phone.next();
    phone.say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'Kim'});
    expect((await phone.next())['type'], 'entered');
    expect((await tv.next())['type'], 'joined');
  });

  test('other paths are not the relay server\'s', () async {
    await start();
    final client = HttpClient();
    Future<int> status(String path) async => (await (await client
                .getUrl(Uri.parse('http://127.0.0.1:${server.port}$path')))
            .close())
        .statusCode;
    expect(await status('/'), 404);
    expect(await status('/room'), 426);
    client.close();
  });

  test('the executable runs, and says its version', () async {
    final version = await Process.run(
        Platform.resolvedExecutable, ['bin/gubasic_relay.dart', '--version']);
    expect(version.stdout, 'gubasic-relay $relayVersion\n');
    final bad = await Process.run(
        Platform.resolvedExecutable, ['bin/gubasic_relay.dart', '--port']);
    expect(bad.exitCode, isNot(0));
    final dir = await Directory.systemTemp.createTemp('relay');
    final yaml = File('${dir.path}/relay.yaml')
      ..writeAsStringSync('maxRoom: 1');
    final wrong = await Process.run(Platform.resolvedExecutable,
        ['bin/gubasic_relay.dart', '--config', yaml.path]);
    expect(wrong.exitCode, 64);
    expect(wrong.stderr, contains('no setting named "maxRoom"'));
    await dir.delete(recursive: true);
    // The server needs no server for this test.
    server = await RelayServer.start(
        const RelayConfig().listeningOn('127.0.0.1', 0));
  });
}
