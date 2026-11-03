import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'config.dart';
import 'hub.dart';

/// The relay server on `dart:io` (docs/DESIGN.md D136, RELAY_SERVER.md):
/// `GET /room` takes the WebSocket upgrade, `GET /room/health` says it is
/// there and how many rooms are open. Behind Apache it listens on
/// `127.0.0.1` only; the IDE runs one of its own on a free port.
class RelayServer {
  RelayServer._(this.hub, this._server, this._log);

  /// Starts a server as [config] says; port 0 takes a free one.
  static Future<RelayServer> start(
    RelayConfig config, {
    RoomHub? hub,
    void Function(String line)? log,
  }) async {
    final server = await HttpServer.bind(config.bind, config.port);
    final relay =
        RelayServer._(hub ?? RoomHub(config: config, log: log), server, log);
    relay._serve(server);
    relay._sweeper =
        Timer.periodic(const Duration(seconds: 5), (_) => relay.hub.sweep());
    log?.call('gubasic-relay $relayVersion listening on '
        '${config.bind}:${server.port}');
    return relay;
  }

  final RoomHub hub;
  HttpServer _server;
  final void Function(String line)? _log;
  Timer? _sweeper;

  /// Answers a request that is not the relay server's (the desktop IDE's
  /// "Preview on the Web" serves the app on the same port, D136); true when
  /// it did. Unset, such requests get 404.
  Future<bool> Function(HttpRequest request)? fallback;

  /// The port it listens on.
  int get port => _server.port;

  /// The address it listens on.
  InternetAddress get address => _server.address;

  void _serve(HttpServer server) {
    server.listen((request) async {
      try {
        if (!await handle(request) &&
            !(await fallback?.call(request) ?? false)) {
          request.response.statusCode = HttpStatus.notFound;
          await request.response.close();
        }
      } catch (e) {
        _log?.call('request failed: $e');
      }
    });
  }

  /// Listens on [bind] instead, on the same port, keeping the rooms (the
  /// IDE's "same network" switch).
  Future<void> rebind(String bind) async {
    final port = _server.port;
    // Stops listening at once; the connections open stay open (closing
    // waits for them, so it is not awaited).
    unawaited(_server.close());
    for (var attempt = 0;; attempt++) {
      try {
        _server = await HttpServer.bind(bind, port);
        break;
      } on SocketException {
        if (attempt == 20) rethrow;
        await Future<void>.delayed(const Duration(milliseconds: 50));
      }
    }
    _serve(_server);
  }

  /// Answers [request] when it is the relay server's (`/room`,
  /// `/room/health`); false for any other path, so that a server serving
  /// more (the IDE's web preview) can answer it.
  Future<bool> handle(HttpRequest request) async {
    final path = request.uri.path;
    if (path == '/room/health') {
      request.response
        ..headers.contentType = ContentType.json
        ..write(
            jsonEncode({'gubasicRelay': relayVersion, 'rooms': hub.roomCount}));
      await request.response.close();
      return true;
    }
    if (path != '/room') return false;
    if (!WebSocketTransformer.isUpgradeRequest(request)) {
      request.response
        ..statusCode = HttpStatus.upgradeRequired
        ..write('This is a GuBASIC relay server: connect with WebSocket.');
      await request.response.close();
      return true;
    }
    final origin = request.headers.value('origin');
    final allowed = hub.config.allowedOrigins;
    if (origin != null && allowed.isNotEmpty && !allowed.contains(origin)) {
      _log?.call('refused: origin $origin');
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return true;
    }
    final socket = await WebSocketTransformer.upgrade(request);
    socket.pingInterval = const Duration(seconds: 25);
    final peer = _SocketPeer(socket, _addressOf(request));
    final connection = hub.connect(peer);
    socket.listen(
      (data) {
        if (data is String) {
          connection.receive(data);
        } else {
          peer.close(1003, 'text only');
          connection.disconnected();
        }
      },
      onDone: connection.disconnected,
      onError: (_) => connection.disconnected(),
      cancelOnError: true,
    );
    return true;
  }

  /// Where [request] comes from: behind a proxy on this computer, the
  /// first address of X-Forwarded-For.
  static String _addressOf(HttpRequest request) {
    final remote = request.connectionInfo?.remoteAddress;
    final forwarded = request.headers.value('x-forwarded-for');
    if (remote != null && remote.isLoopback && forwarded != null) {
      return forwarded.split(',').first.trim();
    }
    return remote?.address ?? '';
  }

  /// Stops: every room is closed (`server`), then the server.
  Future<void> close() async {
    _sweeper?.cancel();
    hub.shutdown();
    for (final c in hub.connections.toList()) {
      c.peer.close(1001, 'server stopping');
    }
    await _server.close(force: true);
  }
}

class _SocketPeer implements RelayPeer {
  _SocketPeer(this.socket, this.address);

  final WebSocket socket;

  @override
  final String address;

  /// Closed by the hub: a message that came before is not answered.
  var _closed = false;

  @override
  void send(String text) {
    if (_closed || socket.readyState != WebSocket.open) return;
    try {
      socket.add(text);
    } on StateError {
      // Closed meanwhile.
    }
  }

  @override
  void close(int code, String reason) {
    _closed = true;
    unawaited(socket.close(code, reason));
  }
}
