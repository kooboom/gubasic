import 'dart:async';

import 'package:web_socket_channel/web_socket_channel.dart';

/// Why a WebSocket could not be opened: a bad address, no server, no
/// connection; [detail] is what the system said, for R047.
class GbWebSocketError implements Exception {
  const GbWebSocketError(this.detail);

  final String detail;
}

/// An open WebSocket connection (docs/DESIGN.md D136).
abstract interface class GbSocket {
  /// Sends one text message.
  void send(String text);

  /// Closes the connection; its callbacks hear nothing more.
  void close();
}

/// Opens WebSocket connections for a running program (D136):
/// package:web_socket_channel, which uses `dart:io` on the desktop and the
/// browser's own WebSocket on the web. Text messages only (KNOWN_ISSUES).
/// Tests give a fake.
abstract class GbWebSocket {
  factory GbWebSocket() => _ChannelWebSocket();

  /// Opens [url] (`ws://` or `wss://`) and gives the connection once it is
  /// open; throws a [GbWebSocketError] when it cannot be opened, or is not
  /// open within [timeout]. Afterwards [onMessage] hears each text message,
  /// [onClosed] that the server closed the connection or it was lost (with
  /// the reason the server gave, or what happened), [onError] a problem.
  Future<GbSocket> connect(
    String url, {
    required void Function(String text) onMessage,
    required void Function(String reason) onClosed,
    required void Function(String message) onError,
    Duration timeout = const Duration(seconds: 30),
  });
}

class _ChannelWebSocket implements GbWebSocket {
  @override
  Future<GbSocket> connect(
    String url, {
    required void Function(String text) onMessage,
    required void Function(String reason) onClosed,
    required void Function(String message) onError,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final Uri uri;
    try {
      uri = Uri.parse(url.trim());
    } on FormatException {
      throw const GbWebSocketError('not a ws:// or wss:// address');
    }
    if (!const {'ws', 'wss'}.contains(uri.scheme.toLowerCase()) ||
        uri.host.isEmpty) {
      throw const GbWebSocketError('not a ws:// or wss:// address');
    }
    final WebSocketChannel channel;
    try {
      channel = WebSocketChannel.connect(uri);
      await channel.ready.timeout(timeout);
    } on TimeoutException {
      throw const GbWebSocketError('no answer in time');
    } catch (e) {
      throw GbWebSocketError(_detail(e));
    }
    final socket = _ChannelSocket(channel);
    socket._subscription = channel.stream.listen(
      (data) {
        if (!socket._closed && data is String) onMessage(data);
      },
      onError: (Object e) {
        if (!socket._closed) onError(_detail(e));
      },
      onDone: () {
        if (socket._closed) return;
        socket._closed = true;
        final reason = channel.closeReason;
        onClosed(
          reason != null && reason.isNotEmpty
              ? reason
              : channel.closeCode == null
              ? 'connection lost'
              : 'closed (${channel.closeCode})',
        );
      },
    );
    return socket;
  }

  static String _detail(Object e) {
    final text = switch (e) {
      WebSocketChannelException(:final inner?) => '$inner',
      WebSocketChannelException(:final message?) => message,
      _ => '$e',
    };
    return text
        .replaceFirst(RegExp(r'^[A-Za-z]*Exception:\s*'), '')
        .split('\n')
        .first
        .trim();
  }
}

class _ChannelSocket implements GbSocket {
  _ChannelSocket(this._channel);

  final WebSocketChannel _channel;
  StreamSubscription<dynamic>? _subscription;
  var _closed = false;

  @override
  void send(String text) {
    if (!_closed) _channel.sink.add(text);
  }

  @override
  void close() {
    if (_closed) return;
    _closed = true;
    unawaited(_subscription?.cancel());
    unawaited(_channel.sink.close(1000));
  }
}
