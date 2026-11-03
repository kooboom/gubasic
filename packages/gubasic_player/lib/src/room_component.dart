import 'package:flutter/foundation.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A `Room` control of a running program (docs/DESIGN.md D136): the
/// interpreter's [RoomComponent], connecting to the relay server through
/// the runtime's [GbWebSocket]. [busy] counts Create and Join while they
/// wait, so that the run window shows the pointer as waiting meanwhile
/// (D124 A).
class PlayerRoom extends RoomComponent {
  PlayerRoom(super.name, this._sockets, this.busy, {super.defaultServer});

  final GbWebSocket _sockets;
  final ValueNotifier<int> busy;

  @override
  void waiting(bool on) => busy.value += on ? 1 : -1;

  @override
  Future<WebSocketLink> open(String url, WebSocketListener listener) async {
    try {
      final socket = await _sockets.connect(
        url,
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

class _Link implements WebSocketLink {
  _Link(this._socket);

  final GbSocket _socket;

  @override
  void send(String text) => _socket.send(text);

  @override
  void close() => _socket.close();
}
