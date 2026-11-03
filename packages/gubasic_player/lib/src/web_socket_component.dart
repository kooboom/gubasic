import 'package:flutter/foundation.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A `WebSocket` control of a running program (docs/DESIGN.md D136): the
/// interpreter's [WebSocketComponent], connecting through the runtime's
/// [GbWebSocket]. [busy] counts Connect while it waits, so that the run
/// window shows the pointer as waiting meanwhile (D124 A).
class PlayerWebSocket extends WebSocketComponent {
  PlayerWebSocket(super.name, this._sockets, this.busy);

  final GbWebSocket _sockets;
  final ValueNotifier<int> busy;

  @override
  Future<WebSocketLink> open(String url, WebSocketListener listener) async {
    busy.value++;
    try {
      return _Link(
        await _sockets.connect(
          url,
          onMessage: listener.message,
          onClosed: listener.closed,
          onError: listener.error,
        ),
      );
    } on GbWebSocketError catch (e) {
      throw WebSocketFailure(e.detail);
    } finally {
      busy.value--;
    }
  }
}

class _Link implements WebSocketLink {
  _Link(this._socket);

  final GbSocket _socket;

  @override
  void send(String text) => _socket.send(text);

  @override
  void close() => _socket.close();
}
