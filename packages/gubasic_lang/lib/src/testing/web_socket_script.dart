import 'dart:async';

import '../components/web_socket_component.dart';
import 'room_script.dart' show shortened;

/// What a test's WebSocket server does (D136): a stanza of a `NAME.ws`
/// file.
///
///     CONNECT ws://localhost:8080/chat
///     < welcome
///     ON hello
///     < hi, Kim
///     < {"kind":"news","text":"rain"}
///     ON bye
///     CLOSE see you
///
///     CONNECT ws://localhost:8080/down
///     FAILS connection refused
///
/// `CONNECT url` starts a stanza; `FAILS detail` says the connection
/// cannot be opened. Otherwise the lines before the first `ON` are what
/// the server does as soon as the connection is open, and the lines after
/// `ON text` what it does when the program sends exactly that text:
/// `< text` sends a message, `CLOSE reason` closes the connection, `ERROR
/// message` reports a problem. Stanzas are parted by an empty line.
class WebSocketStub {
  WebSocketStub(this.url, {this.failure});

  final String url;

  /// Why the connection cannot be opened; null when it can.
  final String? failure;

  /// What the server does once the connection is open.
  final opened = <ServerAction>[];

  /// What it does when the program sends a text, by the text.
  final answers = <String, List<ServerAction>>{};
}

/// One thing a test's server does: send a message, close the connection
/// or report a problem.
class ServerAction {
  const ServerAction.send(this.text) : kind = 'send';
  const ServerAction.close(this.text) : kind = 'close';
  const ServerAction.error(this.text) : kind = 'error';

  /// `send`, `close` or `error`.
  final String kind;

  /// The message, the reason or the problem.
  final String text;
}

/// Reads a `NAME.ws` file ([WebSocketStub]).
List<WebSocketStub> parseWebSocketScript(String text) {
  final stubs = <WebSocketStub>[];
  for (final stanza
      in text.replaceAll('\r\n', '\n').split(RegExp(r'\n\s*\n'))) {
    final lines = stanza.split('\n').where((l) => l.trim().isNotEmpty).toList();
    if (lines.isEmpty) continue;
    final first = lines.first.trim();
    if (!first.startsWith('CONNECT ')) {
      throw FormatException('a stanza starts with CONNECT url: $first');
    }
    final url = first.substring(8).trim();
    if (lines.length > 1 && lines[1].trim().startsWith('FAILS')) {
      stubs.add(
          WebSocketStub(url, failure: lines[1].trim().substring(5).trim()));
      continue;
    }
    final stub = WebSocketStub(url);
    var actions = stub.opened;
    for (final line in lines.skip(1)) {
      if (line.startsWith('ON ')) {
        actions = stub.answers[line.substring(3)] = [];
      } else if (line.startsWith('< ')) {
        actions.add(ServerAction.send(line.substring(2)));
      } else if (line.trim() == '<') {
        actions.add(const ServerAction.send(''));
      } else if (line.startsWith('CLOSE')) {
        actions.add(ServerAction.close(line.substring(5).trim()));
      } else if (line.startsWith('ERROR')) {
        actions.add(ServerAction.error(line.substring(5).trim()));
      } else {
        throw FormatException('cannot read "$line" in a .ws stanza');
      }
    }
    stubs.add(stub);
  }
  return stubs;
}

/// The WebSocket servers of a test (D136): opens connections as [stubs]
/// say, answers what the program sends, and records each connection,
/// message and close in [transcript]:
///
///     WebSocket: connect ws://localhost:8080/chat
///     WebSocket: send hello
///     WebSocket: close
///
/// The ScriptedHost and the run window's test share it, so that their
/// transcripts match. What the server does reaches the program in a
/// microtask, before the event script's next step.
class ScriptedWebSockets {
  ScriptedWebSockets(this.stubs, this.transcript);

  final List<WebSocketStub> stubs;
  List<String> transcript;

  /// The connection opened last: an event script's `Server` steps act on
  /// it.
  _Connection? _last;

  Future<WebSocketLink> open(String url, WebSocketListener listener) async {
    transcript.add('WebSocket: connect $url');
    final stub = stubs.where((s) => s.url == url).firstOrNull;
    if (stub == null) {
      throw const WebSocketFailure('no server answers in this test');
    }
    if (stub.failure != null) throw WebSocketFailure(stub.failure!);
    final connection = _last = _Connection(this, stub, listener);
    scheduleMicrotask(() => connection.run(stub.opened));
    return connection;
  }

  /// The server does [action] on the connection opened last (an event
  /// script's `Server Send …`); false when none is open.
  bool serverDoes(ServerAction action) {
    final c = _last;
    if (c == null || c.closed) return false;
    c.run([action]);
    return true;
  }
}

class _Connection implements WebSocketLink {
  _Connection(this.sockets, this.stub, this.listener);

  final ScriptedWebSockets sockets;
  final WebSocketStub stub;
  final WebSocketListener listener;
  var closed = false;

  void run(List<ServerAction> actions) {
    for (final a in actions) {
      if (closed) return;
      switch (a.kind) {
        case 'send':
          listener.message(a.text);
        case 'close':
          closed = true;
          listener.closed(a.text);
        default:
          listener.error(a.text);
      }
    }
  }

  @override
  void send(String text) {
    sockets.transcript.add('WebSocket: send ${shortened(text)}');
    final answer = stub.answers[text];
    if (answer != null) scheduleMicrotask(() => run(answer));
  }

  @override
  void close() {
    if (closed) return;
    closed = true;
    sockets.transcript.add('WebSocket: close');
  }
}
