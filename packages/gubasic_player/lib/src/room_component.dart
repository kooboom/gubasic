import 'package:flutter/foundation.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A `Room` control of a running program (docs/DESIGN.md D136): the
/// interpreter's [RoomComponent], connecting to the relay server through
/// the runtime's [GbWebSocket]. [busy] counts Create and Join while they
/// wait, so that the run window shows the pointer as waiting meanwhile
/// (D124 A).
class PlayerRoom extends RoomComponent {
  PlayerRoom(
    super.name,
    this._sockets,
    this.busy, {
    super.defaultServer,
    this.page,
  });

  /// The page a Server written as a path is on: the web app's own, or in
  /// the desktop IDE its relay server's (D136).
  final Uri? page;

  final GbWebSocket _sockets;
  final ValueNotifier<int> busy;

  @override
  void waiting(bool on) => busy.value += on ? 1 : -1;

  @override
  Future<WebSocketLink> open(String url, WebSocketListener listener) async {
    try {
      final socket = await _sockets.connect(
        onPage(url, page ?? (kIsWeb ? Uri.base : null)),
        onMessage: listener.message,
        onClosed: listener.closed,
        onError: listener.error,
      );
      return _Link(socket);
    } on GbWebSocketError catch (e) {
      throw WebSocketFailure(e.detail);
    }
  }
}

/// [server] as a WebSocket address: a path alone (`/room`) is on the web
/// server that served the app, [page] (D136: the IDE's "Preview on the
/// Web", or an app and its relay server behind one web server), `wss`
/// when the page is `https`. Without a page a path stays as it is, and
/// cannot be opened.
String onPage(String server, Uri? page) {
  if (!server.startsWith('/') || page == null) return server;
  final scheme = page.scheme == 'https' ? 'wss' : 'ws';
  return '$scheme://${page.authority}$server';
}

class _Link implements WebSocketLink {
  _Link(this._socket);

  final GbSocket _socket;

  @override
  void send(String text) => _socket.send(text);

  @override
  void close() => _socket.close();
}
