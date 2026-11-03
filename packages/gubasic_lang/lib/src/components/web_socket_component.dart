import '../diagnostics/diagnostic.dart';
import '../interpreter/host.dart';
import '../interpreter/values.dart';

/// Why a WebSocket could not be opened: the detail goes into R047.
class WebSocketFailure implements Exception {
  const WebSocketFailure(this.detail);

  final String detail;
}

/// What an open connection tells its [WebSocketComponent]: a message, that
/// it closed (or was lost), that something went wrong. Each connection has
/// its own, so that a connection closed by the program tells nothing more.
class WebSocketListener {
  WebSocketListener(this.message, this.closed, this.error);

  final void Function(String text) message;
  final void Function(String reason) closed;
  final void Function(String message) error;
}

/// An open connection, as [WebSocketComponent.open] gives it.
abstract interface class WebSocketLink {
  /// Sends one text message.
  void send(String text);

  /// Closes the connection; its listener hears nothing more.
  void close();
}

/// The `WebSocket` control (docs/DESIGN.md D122, D136), a tray control
/// through the component channel: everything but the socket, which [open]
/// makes where the program runs (the player with the runtime's
/// `GbWebSocket`, the tests from a script).
///
/// `Connect(url)` waits until the connection is open, as Http waits for
/// its answer (D124 A), or stops the program with R047; `Send` while it is
/// not open is R049. A message that comes runs `Message`, the server
/// closing it or the connection being lost runs `Closed`, a problem after
/// it was open runs `Error`, each reported to [onEvent] for the
/// interpreter to run in turn. `Close()` and Connect again close the
/// connection quietly: the program knows it did.
abstract class WebSocketComponent implements ComponentWithEvents {
  WebSocketComponent(this.name);

  /// The control's name, for messages.
  final String name;

  WebSocketLink? _link;
  String _url = '';
  var _disposed = false;

  /// The connection [_link]'s number: a listener of an older one is not
  /// heard.
  var _generation = 0;

  @override
  ComponentEventSink? onEvent;

  /// Opens a connection to [url] and gives it once it is open; throws a
  /// [WebSocketFailure] when it cannot be opened. [listener] hears what
  /// happens to it afterwards.
  Future<WebSocketLink> open(String url, WebSocketListener listener);

  /// Whether a connection is open.
  bool get isOpen => _link != null;

  @override
  Object? getProperty(String name) => switch (name) {
        'State' => _link == null ? 'Closed' : 'Open',
        'Url' => _url,
        _ => throw StateError('no property WebSocket.$name'),
      };

  /// Tag is kept by the host; nothing else can be set.
  @override
  void setProperty(String name, Object? value) {}

  @override
  void assign(String name, List<Object?> args, Object? value) =>
      throw StateError('WebSocket.$name cannot be assigned');

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    switch (name) {
      case 'Connect':
        await _connect(args[0] as String);
        return null;
      case 'Send':
        final link = _link ??
            (throw ComponentProblem(DiagnosticCode.notConnected, [this.name]));
        link.send(args[0] as String);
        return null;
      case 'Close':
        _closeQuietly();
        return null;
    }
    throw StateError('no code for WebSocket.$name');
  }

  Future<void> _connect(String url) async {
    _closeQuietly();
    _url = url;
    final generation = ++_generation;
    bool current() => generation == _generation && !_disposed;
    final listener = WebSocketListener(
      (text) {
        if (current()) {
          onEvent?.call('Message', [GbSocketEvent.message(text)]);
        }
      },
      (reason) {
        if (!current()) return;
        _link = null;
        _generation++;
        onEvent?.call('Closed', [GbSocketEvent.closed(reason)]);
      },
      (message) {
        if (current()) onEvent?.call('Error', [GbSocketEvent.error(message)]);
      },
    );
    final WebSocketLink link;
    try {
      link = await open(url, listener);
    } on WebSocketFailure catch (f) {
      throw ComponentProblem(DiagnosticCode.webSocketFailed, [url, f.detail]);
    }
    if (!current()) {
      // Closed or disposed while it opened.
      link.close();
      return;
    }
    _link = link;
  }

  void _closeQuietly() {
    _generation++;
    _link?.close();
    _link = null;
  }

  @override
  void dispose() {
    _disposed = true;
    onEvent = null;
    _closeQuietly();
  }
}

/// Whether [url] is a plain `ws://` address beyond this computer and the
/// private networks of RFC 1918 (A077, D136): not encrypted, and a page
/// served over https cannot open it.
bool isPlainRemoteWebSocket(String url) {
  final uri = Uri.tryParse(url.trim());
  if (uri == null || uri.scheme.toLowerCase() != 'ws') return false;
  final host = uri.host.toLowerCase();
  if (host.isEmpty || host == 'localhost' || host.endsWith('.localhost')) {
    return false;
  }
  if (host == '::1' || host == '[::1]') return false;
  final parts = host.split('.');
  if (parts.length == 4) {
    final n = [for (final p in parts) int.tryParse(p)];
    if (n.every((x) => x != null && x >= 0 && x <= 255)) {
      final a = n[0]!, b = n[1]!;
      if (a == 127 || a == 10) return false;
      if (a == 172 && b >= 16 && b <= 31) return false;
      if (a == 192 && b == 168) return false;
    }
  }
  return true;
}
