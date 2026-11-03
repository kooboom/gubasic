import 'dart:async';
import 'dart:convert';

import 'package:gubasic_relay/gubasic_relay_hub.dart';

import '../components/web_socket_component.dart';

/// [text] as a transcript shows it: a text over 200 characters by its
/// length alone.
String shortened(Object? text) {
  final t = '$text';
  return t.length > 200 ? '(${t.length} characters)' : t;
}

/// `Peer 민지 Join`, `Peer 민지 Send {"choice":2}`: someone else in the
/// test's relay server (D136), by nickname: `Create` a room, `Join` the
/// newest one (or the room named after it), `Send` a text, `SendTo`
/// a member a text, `Leave`, `Lock`.
class PeerAction {
  const PeerAction(this.nickname, this.verb, this.argument);

  final String nickname;

  /// `Create`, `Join`, `Send`, `SendTo`, `Leave` or `Lock`.
  final String verb;

  /// What follows the verb: a room's code, the text, `m1 text`; "" for
  /// none.
  final String argument;
}

/// The relay server of a test (D136): the relay server's own protocol
/// ([RoomHub]) in memory, its room codes pinned (`K7QPXM`, `ABCDEF`,
/// `GHJKLM`, `NPQRST`), its clock moving a second at each look so that no
/// limit is met by chance. The program's Rooms connect to it, the event
/// script's `Peer` steps act as the others in the room, and `Room Close
/// idle` and `Room Drop` act as the server. The transcript records what
/// the program sends and what the peers get:
///
///     Room: create
///     Room: join K7QPXM 민지
///     Room: send {"kind":"answer"}
///     Room: sendTo m2 right
///     Peer 민지: entered K7QPXM as m2
///     Peer 민지 got: {"kind":"question"}
///
/// The ScriptedHost and the run window's test share it, so that their
/// transcripts match.
class ScriptedRooms {
  ScriptedRooms(this.transcript)
      : hub = RoomHub(
            codes: RoomCodes.fixed(['K7QPXM', 'ABCDEF', 'GHJKLM', 'NPQRST']),
            clock: _ticking());

  static DateTime Function() _ticking() {
    var t = DateTime.utc(2026, 11, 3, 9);
    return () => t = t.add(const Duration(seconds: 1));
  }

  final RoomHub hub;
  List<String> transcript;

  final _peers = <String, _Peer>{};
  _ProgramLink? _program;

  /// A connection of the program's Room to the server.
  Future<WebSocketLink> open(String url, WebSocketListener listener) async {
    return _program = _ProgramLink(this, listener);
  }

  /// The server does [verb] (`Close` with a reason, or `Drop`, which loses
  /// the program's connection); false when there is nothing to do it to.
  bool serverDoes(String verb, String argument) {
    switch (verb) {
      case 'Close':
        if (hub.roomCount == 0) return false;
        hub.shutdown(argument.isEmpty ? 'server' : argument);
        return true;
      case 'Drop':
        final p = _program;
        if (p == null || !p.open) return false;
        p.lose();
        return true;
    }
    return false;
  }

  /// A peer does what [action] says; false when it cannot (no room to
  /// join, not in a room).
  bool peerDoes(PeerAction action) {
    final peer =
        _peers.putIfAbsent(action.nickname, () => _Peer(this, action.nickname));
    switch (action.verb) {
      case 'Create':
        peer.say({'type': 'create', 'nickname': action.nickname});
      case 'Join':
        final code = action.argument.isNotEmpty
            ? action.argument
            : (hub.roomCodes.lastOrNull ?? '');
        if (code.isEmpty) return false;
        peer.say({'type': 'join', 'room': code, 'nickname': action.nickname});
      case 'Send':
        peer.say({'type': 'send', 'data': action.argument});
      case 'SendTo':
        final space = action.argument.indexOf(' ');
        if (space < 0) return false;
        peer.say({
          'type': 'sendTo',
          'to': action.argument.substring(0, space),
          'data': action.argument.substring(space + 1),
        });
      case 'Leave':
        peer.say({'type': 'leave'});
      case 'Lock':
        peer.say({'type': 'lock'});
      default:
        return false;
    }
    return true;
  }
}

/// The program's side of a connection: what the program sends goes to
/// the hub (and into the transcript); what the hub sends goes to the
/// Room's [listener] in a microtask, in order, so that it reaches the
/// program before the event script's next step.
class _ProgramLink implements WebSocketLink {
  _ProgramLink(this.rooms, this.listener) {
    connection = rooms.hub.connect(_ProgramPeer(this));
  }

  final ScriptedRooms rooms;
  final WebSocketListener listener;
  late final RelayConnection connection;

  /// Closed by the program, or lost (by the server or `Room Drop`).
  var closed = false;
  var lost = false;

  bool get open => !closed && !lost;

  @override
  void send(String text) {
    if (!open) return;
    final m = jsonDecode(text) as Map<String, Object?>;
    final line = switch (m['type']) {
      'create' => 'Room: create',
      'join' => 'Room: join ${m['room']} ${m['nickname']}',
      'send' => 'Room: send ${shortened(m['data'])}',
      'sendTo' => 'Room: sendTo ${m['to']} ${shortened(m['data'])}',
      'leave' => 'Room: leave',
      'lock' => 'Room: lock',
      'resume' => 'Room: resume',
      _ => null,
    };
    if (line != null) rooms.transcript.add(line);
    connection.receive(text);
  }

  @override
  void close() {
    if (!open) return;
    closed = true;
    connection.disconnected();
  }

  /// The connection is lost: the hub keeps the member's place, the
  /// program hears it closed.
  void lose() {
    lost = true;
    connection.disconnected();
    scheduleMicrotask(() => listener.closed('connection lost'));
  }
}

/// The hub's side of the program's connection.
class _ProgramPeer implements RelayPeer {
  _ProgramPeer(this.link);

  final _ProgramLink link;

  @override
  String get address => '127.0.0.1';

  @override
  void send(String text) {
    if (!link.open) return;
    scheduleMicrotask(() {
      if (link.open) link.listener.message(text);
    });
  }

  @override
  void close(int code, String reason) {
    if (!link.open) return;
    link.lost = true;
    scheduleMicrotask(() => link.listener.closed(reason));
  }
}

/// Someone else in the room, as the event script's `Peer` steps make it.
class _Peer implements RelayPeer {
  _Peer(this.rooms, this.nickname) {
    connection = rooms.hub.connect(this);
    connection.receive(jsonEncode({'type': 'hello', 'v': 1}));
  }

  final ScriptedRooms rooms;
  final String nickname;
  late final RelayConnection connection;

  @override
  String get address => '192.0.2.${nickname.hashCode % 200 + 1}';

  void say(Map<String, Object?> message) =>
      connection.receive(jsonEncode(message));

  @override
  void send(String text) {
    final m = jsonDecode(text) as Map<String, Object?>;
    final line = switch (m['type']) {
      'welcome' || 'joined' || 'left' || 'locked' => null,
      'created' => 'Peer $nickname: created ${m['room']} as ${m['you']}',
      'entered' => 'Peer $nickname: entered ${m['room']} as ${m['you']}',
      'message' => 'Peer $nickname got: ${shortened(m['data'])}',
      'closed' => 'Peer $nickname: closed ${m['reason']}',
      'error' => 'Peer $nickname: error ${m['code']}',
      _ => null,
    };
    if (line != null) rooms.transcript.add(line);
  }

  @override
  void close(int code, String reason) {}
}
