import 'dart:async';

import 'dart:convert';

import '../analyzer/types.dart';
import '../diagnostics/diagnostic.dart';
import '../interpreter/host.dart';
import '../interpreter/values.dart';
import 'web_socket_component.dart';

/// The `Room` control (docs/DESIGN.md D122, D136; the protocol:
/// docs/ROOM_PROTOCOL.md), a tray control through the component channel:
/// the protocol, the room's state and the reconnection; the connection
/// itself is [open]ed where the program runs (the player's on the
/// runtime's `GbWebSocket`, the tests' on a relay server in memory).
///
/// `Create()` and `Join(code, nickname)` wait until the program is in the
/// room; a connection that cannot be opened is R047, a room that cannot be
/// entered R048 with the server's reason. `Send` and `SendTo` while not in
/// a room are R049. A connection lost while in a room comes back by itself
/// within [reconnectFor], keeping the program's place (`resume`); Sends
/// meanwhile wait, and the room is `Closed` ("connection lost") if it
/// cannot.
abstract class RoomComponent implements ComponentWithEvents {
  RoomComponent(this.name, {this.defaultServer});

  /// The control's name, for messages.
  final String name;

  /// The relay server used when `Server` is empty: the IDE's own, while
  /// developing; null where there is none.
  final String? defaultServer;

  /// How long a lost connection is tried again.
  Duration get reconnectFor => const Duration(seconds: 30);

  /// How long Create, Join and a resume wait for the server's answer.
  Duration get answerWithin => const Duration(seconds: 30);

  /// Opens a WebSocket to [url]; throws a [WebSocketFailure].
  Future<WebSocketLink> open(String url, WebSocketListener listener);

  /// Waits [d] before trying a lost connection again; tests make it
  /// shorter.
  Future<void> pause(Duration d) => Future<void>.delayed(d);

  /// Create or Join starts or stops waiting: the player shows the pointer
  /// as waiting meanwhile.
  void waiting(bool on) {}

  @override
  ComponentEventSink? onEvent;

  var _server = '';
  var _nickname = '';

  WebSocketLink? _link;
  var _generation = 0;
  var _disposed = false;

  String _url = '';
  String _code = '';
  String _me = '';
  String _host = '';
  String _token = '';
  final _members = <String, String>{};

  /// While a connection is being tried again: what the program sends
  /// meanwhile.
  List<String>? _outbox;

  /// The answer awaited from the server: `created`, `entered`, `resumed`
  /// or an `error`.
  Completer<Map<String, Object?>>? _answer;

  bool get _inRoom => _code.isNotEmpty;

  @override
  Object? getProperty(String name) => switch (name) {
        'Code' => _code,
        'Me' => _me,
        'IsHost' => _inRoom && _me == _host,
        'Members' => GbArray(GbType.string, [..._members.keys]),
        'Server' => _server,
        'Nickname' => _nickname,
        _ => throw StateError('no property Room.$name'),
      };

  @override
  void setProperty(String name, Object? value) {
    switch (name) {
      case 'Server':
        _server = value as String;
      case 'Nickname':
        _nickname = value as String;
    }
  }

  @override
  void assign(String name, List<Object?> args, Object? value) =>
      throw StateError('Room.$name cannot be assigned');

  @override
  Future<Object?> call(String name, List<Object?> args) async {
    switch (name) {
      case 'Create':
        final nickname = _nickname.trim().isEmpty ? 'host' : _nickname;
        await _enter({'type': 'create', 'nickname': nickname}, 'created');
        return null;
      case 'Join':
        await _enter({
          'type': 'join',
          'room': args[0] as String,
          'nickname': args[1] as String,
        }, 'entered');
        return null;
      case 'Send':
        _out({'type': 'send', 'data': args[0] as String});
        return null;
      case 'SendTo':
        _out({
          'type': 'sendTo',
          'to': args[0] as String,
          'data': args[1] as String,
        });
        return null;
      case 'Lock':
        _out({'type': 'lock'});
        return null;
      case 'Leave':
        if (_inRoom) _link?.send(jsonEncode({'type': 'leave'}));
        _reset();
        return null;
      case 'NicknameOf':
        return _members[args[0] as String] ?? '';
    }
    throw StateError('no code for Room.$name');
  }

  void _out(Map<String, Object?> message) {
    if (!_inRoom) {
      throw ComponentProblem(DiagnosticCode.notConnected, [name]);
    }
    final text = jsonEncode(message);
    if (_outbox case final waiting?) {
      waiting.add(text);
    } else {
      _link?.send(text);
    }
  }

  /// Leaves the room quietly: the connection closes and the state goes.
  void _reset() {
    _generation++;
    _link?.close();
    _link = null;
    _outbox = null;
    _code = _me = _host = _token = '';
    _members.clear();
    final answer = _answer;
    _answer = null;
    if (answer != null && !answer.isCompleted) {
      answer.complete({'type': 'error', 'code': 'left'});
    }
  }

  /// Connects to the server and says hello; the link and its generation.
  Future<(WebSocketLink, int)> _connect(String url) async {
    final generation = ++_generation;
    final link = await open(
      url,
      WebSocketListener(
        (text) => _heard(generation, text),
        (reason) => _lost(generation),
        (message) => _lost(generation),
      ),
    );
    if (generation != _generation || _disposed) {
      link.close();
      throw const _Abandoned();
    }
    link.send(jsonEncode({'type': 'hello', 'v': 1}));
    return (link, generation);
  }

  Future<Map<String, Object?>> _await(int generation) {
    final answer = _answer = Completer<Map<String, Object?>>();
    return answer.future.timeout(answerWithin,
        onTimeout: () => {'type': 'error', 'code': 'no answer'});
  }

  Future<void> _enter(Map<String, Object?> request, String expected) async {
    if (_inRoom || _link != null) {
      if (_inRoom) _link?.send(jsonEncode({'type': 'leave'}));
      _reset();
    }
    final url = _server.trim().isNotEmpty ? _server.trim() : defaultServer;
    if (url == null || url.isEmpty) {
      throw ComponentProblem(DiagnosticCode.roomNotEntered,
          ['no relay server (Room.Server is empty)']);
    }
    waiting(true);
    try {
      final WebSocketLink link;
      final int generation;
      try {
        (link, generation) = await _connect(url);
      } on WebSocketFailure catch (f) {
        throw ComponentProblem(DiagnosticCode.webSocketFailed, [url, f.detail]);
      } on _Abandoned {
        return;
      }
      _link = link;
      _url = url;
      final answer = _await(generation);
      link.send(jsonEncode(request));
      final reply = await answer;
      if (generation != _generation) return;
      if (reply['type'] != expected) {
        _reset();
        throw ComponentProblem(
            DiagnosticCode.roomNotEntered, ['${reply['code']}']);
      }
      _code = reply['room'] as String;
      _me = reply['you'] as String;
      _token = reply['token'] as String;
      _members.clear();
      if (expected == 'created') {
        _host = _me;
        _members[_me] = request['nickname'] as String;
      } else {
        _host = reply['host'] as String;
        _takeMembers(reply);
      }
    } finally {
      waiting(false);
    }
  }

  void _takeMembers(Map<String, Object?> reply) {
    _members.clear();
    for (final m in (reply['members'] as List).cast<Map<String, Object?>>()) {
      _members[m['member'] as String] = m['nickname'] as String;
    }
  }

  void _event(String event, GbRoomEvent e) => onEvent?.call(event, [e]);

  /// A message from the server on connection [generation].
  void _heard(int generation, String text) {
    if (generation != _generation || _disposed) return;
    final Map<String, Object?> m;
    try {
      m = jsonDecode(text) as Map<String, Object?>;
    } on Object {
      return;
    }
    final answer = _answer;
    switch (m['type']) {
      case 'welcome':
        return;
      case 'created' || 'entered' || 'resumed':
        if (answer != null && !answer.isCompleted) answer.complete(m);
        return;
      case 'error' when answer != null && !answer.isCompleted:
        answer.complete(m);
        return;
      case 'error':
        final detail = m['message'];
        _event(
            'Error',
            GbRoomEvent(
                message: detail is String && detail.isNotEmpty
                    ? '${m['code']}: $detail'
                    : '${m['code']}'));
      case 'message':
        final from = m['from'] as String;
        _event(
            'Message',
            GbRoomEvent(
                member: from,
                nickname: _members[from] ?? '',
                text: m['data'] as String));
      case 'joined':
        final member = m['member'] as String;
        final nickname = m['nickname'] as String;
        _members[member] = nickname;
        _event('Joined', GbRoomEvent(member: member, nickname: nickname));
      case 'left':
        final member = m['member'] as String;
        final nickname = _members.remove(member) ?? '';
        _event('Left', GbRoomEvent(member: member, nickname: nickname));
      case 'closed':
        final reason = m['reason'] as String? ?? '';
        _reset();
        _event('Closed', GbRoomEvent(reason: reason));
    }
  }

  /// Connection [generation] was lost: try again while in a room.
  void _lost(int generation) {
    if (generation != _generation || _disposed) return;
    _link = null;
    final answer = _answer;
    if (answer != null && !answer.isCompleted) {
      answer.complete({'type': 'error', 'code': 'connection lost'});
      return;
    }
    if (!_inRoom) return;
    _outbox ??= [];
    unawaited(_comeBack());
  }

  Future<void> _comeBack() async {
    final started = DateTime.now();
    final delays = [
      Duration.zero,
      const Duration(seconds: 1),
      const Duration(seconds: 2),
      const Duration(seconds: 4),
    ];
    for (var attempt = 0;; attempt++) {
      if (_disposed || !_inRoom) return;
      if (DateTime.now().difference(started) > reconnectFor) break;
      final delay =
          delays[attempt < delays.length ? attempt : delays.length - 1];
      // The first try comes at once.
      if (delay > Duration.zero) await pause(delay);
      if (_disposed || !_inRoom) return;
      try {
        final (link, generation) = await _connect(_url);
        _link = link;
        final answer = _await(generation);
        link.send(jsonEncode({
          'type': 'resume',
          'room': _code,
          'member': _me,
          'token': _token,
        }));
        final reply = await answer;
        if (generation != _generation) return;
        if (reply['type'] == 'resumed') {
          _host = reply['host'] as String;
          _takeMembers(reply);
          final waiting = _outbox ?? const [];
          _outbox = null;
          for (final text in waiting) {
            link.send(text);
          }
          return;
        }
        if (reply['code'] == 'cannot-resume') break;
      } on WebSocketFailure {
        // Not yet: try again.
      } on _Abandoned {
        return;
      }
    }
    if (_disposed || !_inRoom) return;
    _reset();
    _event('Closed', const GbRoomEvent(reason: 'connection lost'));
  }

  @override
  void dispose() {
    _disposed = true;
    onEvent = null;
    if (_inRoom) _link?.send(jsonEncode({'type': 'leave'}));
    _reset();
  }
}

/// A connection given up while it opened.
class _Abandoned implements Exception {
  const _Abandoned();
}
