import 'dart:collection';
import 'dart:convert';

import 'codes.dart';
import 'config.dart';

/// The version of the room protocol (docs/ROOM_PROTOCOL.md).
const roomProtocolVersion = 1;

/// The relay server's version, as `/room/health` gives it.
const relayVersion = '0.7.0';

/// What the hub needs of one connection: where it comes from, sending a
/// message, closing it.
abstract interface class RelayPeer {
  /// The address it comes from, for the limit on `join` attempts.
  String get address;

  /// Sends one text message (a JSON object).
  void send(String text);

  /// Closes the connection with a WebSocket close [code] and [reason].
  void close(int code, String reason);
}

/// The server side of the room protocol (docs/ROOM_PROTOCOL.md, DESIGN
/// D136), without sockets: the dart:io server feeds it, the parity tests
/// use it in memory. Rooms live in memory only; when one ends, everything
/// about it is gone.
class RoomHub {
  RoomHub({
    this.config = const RelayConfig(),
    RoomCodes? codes,
    DateTime Function()? clock,
    this.log,
  })  : _codes = codes ?? RoomCodes(),
        _clock = clock ?? DateTime.now;

  final RelayConfig config;
  final RoomCodes _codes;
  final DateTime Function() _clock;

  /// Where the hub says what happens: rooms made and closed, refusals;
  /// message bodies only when [RelayConfig.logMessages].
  final void Function(String line)? log;

  final _rooms = <String, _Room>{};

  /// `join` attempts in the last minute, by address.
  final _joins = <String, Queue<DateTime>>{};

  final _connections = <RelayConnection>{};

  /// How many rooms are open.
  int get roomCount => _rooms.length;

  /// The connections open now.
  Iterable<RelayConnection> get connections => _connections;

  /// A new connection from [peer]: give it what the peer sends with
  /// [RelayConnection.receive], and tell it when the peer is gone.
  RelayConnection connect(RelayPeer peer) {
    final c = RelayConnection._(this, peer);
    _connections.add(c);
    return c;
  }

  /// Closes the rooms that have been quiet or open too long, and lets go
  /// the members whose connection was lost too long ago. The server calls
  /// it every few seconds; tests call it after moving the clock.
  void sweep() {
    final now = _clock();
    for (final room in _rooms.values.toList()) {
      if (now.difference(room.created).inMinutes >= config.maxRoomMinutes) {
        _closeRoom(room, 'time');
      } else if (now.difference(room.lastActivity).inMinutes >=
          config.idleMinutes) {
        _closeRoom(room, 'idle');
      } else {
        for (final m in room.members.values.toList()) {
          if (m.awaySince case final since?
              when now.difference(since).inSeconds >= config.reconnectSeconds) {
            _leave(room, m);
            if (!_rooms.containsKey(room.code)) break;
          }
        }
      }
    }
    _joins.removeWhere((_, times) {
      _forgetOld(times, now);
      return times.isEmpty;
    });
  }

  /// The codes of the rooms open now, oldest first.
  List<String> get roomCodes => [..._rooms.keys];

  /// Closes every room, as when the server stops (`server`), or for
  /// another [reason] (a test's `Room Close idle`).
  void shutdown([String reason = 'server']) {
    for (final room in _rooms.values.toList()) {
      _closeRoom(room, reason);
    }
  }

  /// Closes the connections [which] picks, as if they were lost for good
  /// (the IDE's "same network" switch turned off).
  void dropConnections(bool Function(RelayPeer peer) which) {
    for (final c in _connections.toList()) {
      if (which(c.peer)) {
        c.peer.close(1008, 'not allowed');
        c._gone(forGood: true);
      }
    }
  }

  void _forgetOld(Queue<DateTime> times, DateTime now) {
    while (times.isNotEmpty &&
        now.difference(times.first) >= const Duration(minutes: 1)) {
      times.removeFirst();
    }
  }

  bool _joinAllowed(String address) {
    final now = _clock();
    final times = _joins.putIfAbsent(address, Queue.new);
    _forgetOld(times, now);
    if (times.length >= config.joinAttemptsPerMinute) return false;
    times.add(now);
    return true;
  }

  String _newCode() {
    for (;;) {
      final code = normalRoomCode(_codes.next());
      if (!_rooms.containsKey(code)) return code;
    }
  }

  void _closeRoom(_Room room, String reason) {
    _rooms.remove(room.code);
    log?.call('room ${room.code} closed ($reason)');
    for (final m in room.members.values) {
      m.connection?._room = null;
      m.connection?._member = null;
      m.connection?._send({'type': 'closed', 'reason': reason});
    }
    room.members.clear();
  }

  /// [member] goes; the room ends when it was the host.
  void _leave(_Room room, _Member member) {
    member.connection?._room = null;
    member.connection?._member = null;
    member.connection = null;
    if (member.id == room.host) {
      _closeRoom(room, 'host left');
      return;
    }
    room.members.remove(member.id);
    room.broadcast({'type': 'left', 'member': member.id}, except: null);
  }
}

class _Room {
  _Room(this.code, this.created) : lastActivity = created;

  final String code;
  final DateTime created;
  DateTime lastActivity;
  var locked = false;
  late String host;
  var _next = 1;
  final members = <String, _Member>{};

  String nextId() => 'm${_next++}';

  List<Map<String, String>> get list => [
        for (final m in members.values)
          {'member': m.id, 'nickname': m.nickname},
      ];

  void broadcast(Map<String, Object?> message, {required _Member? except}) {
    final text = jsonEncode(message);
    for (final m in members.values) {
      if (m != except) m.deliver(text);
    }
  }
}

class _Member {
  _Member(this.id, this.nickname, this.connection) : token = resumeToken();

  final String id;
  final String nickname;
  final String token;
  RelayConnection? connection;

  /// When its connection was lost; null while it is connected.
  DateTime? awaySince;

  /// What came for it while it was away, given when it comes back.
  final waiting = Queue<String>();

  void deliver(String text) {
    final c = connection;
    if (c != null) {
      c.peer.send(text);
    } else {
      waiting.add(text);
      if (waiting.length > 500) waiting.removeFirst();
    }
  }
}

/// One program connected to the hub.
class RelayConnection {
  RelayConnection._(this._hub, this.peer);

  final RoomHub _hub;
  final RelayPeer peer;

  var _greeted = false;
  _Room? _room;
  _Member? _member;
  var _tooBig = 0;
  DateTime? _second;
  var _sentThisSecond = 0;

  /// The room it is in, or null.
  String? get room => _room?.code;

  void _send(Map<String, Object?> message) => peer.send(jsonEncode(message));

  void _error(String code, [String? detail]) => _send({
        'type': 'error',
        'code': code,
        if (detail != null) 'message': detail,
      });

  /// One message from the program.
  void receive(String text) {
    final hub = _hub;
    final config = hub.config;
    if (utf8.encode(text).length > config.maxMessageBytes) {
      _error(
          'too-big',
          'a message is at most ${config.maxMessageBytes} '
              'bytes');
      if (++_tooBig >= 3) _close(1009, 'too big');
      return;
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      _error('bad-message', 'a message is one JSON object');
      return;
    }
    if (decoded is! Map<String, Object?> || decoded['type'] is! String) {
      _error('bad-message', 'a message is a JSON object with a "type"');
      return;
    }
    final message = decoded;
    final type = message['type'] as String;
    if (!_greeted) {
      if (type != 'hello') {
        _error('bad-message', 'the first message is hello');
        return;
      }
      if (message['v'] != roomProtocolVersion) {
        _error(
            'bad-version',
            'this server speaks version '
                '$roomProtocolVersion');
        _close(1008, 'bad version');
        return;
      }
      if (config.key != null && message['key'] != config.key) {
        hub.log?.call('refused: bad key from ${peer.address}');
        _error('bad-key');
        _close(1008, 'bad key');
        return;
      }
      _greeted = true;
      _send({'type': 'welcome', 'v': roomProtocolVersion});
      return;
    }
    switch (type) {
      case 'create':
        _create(message);
      case 'join':
        _join(message);
      case 'resume':
        _resume(message);
      case 'send' || 'sendTo':
        _relay(message, direct: type == 'sendTo');
      case 'leave':
        if (_room case final room?) hub._leave(room, _member!);
      case 'lock':
        final room = _room;
        if (room == null) return _error('not-in-room');
        if (room.host != _member!.id) return _error('not-host');
        room.locked = true;
        room.broadcast({'type': 'locked'}, except: null);
      default:
        _error('bad-message', 'no message type "$type"');
    }
  }

  /// The nickname [message] gives, or null after saying what is wrong.
  String? _nickname(Map<String, Object?> message, {String? fallback}) {
    final n = message['nickname'] ?? fallback;
    if (n is! String || n.trim().isEmpty || n.trim().length > 40) {
      _error('bad-nickname', 'a nickname is 1 to 40 characters');
      return null;
    }
    return n.trim();
  }

  void _create(Map<String, Object?> message) {
    final hub = _hub;
    if (_room != null) return _error('already-in-room');
    if (hub._rooms.length >= hub.config.maxRooms) {
      hub.log?.call('refused: server full');
      return _error('server-full');
    }
    final nickname = _nickname(message, fallback: 'host');
    if (nickname == null) return;
    final room = _Room(hub._newCode(), hub._clock());
    final member = _Member(room.nextId(), nickname, this);
    room
      ..host = member.id
      ..members[member.id] = member;
    hub._rooms[room.code] = room;
    _room = room;
    _member = member;
    hub.log?.call('room ${room.code} created');
    _send({
      'type': 'created',
      'room': room.code,
      'you': member.id,
      'token': member.token,
    });
  }

  void _join(Map<String, Object?> message) {
    final hub = _hub;
    if (_room != null) return _error('already-in-room');
    if (!hub._joinAllowed(peer.address)) {
      hub.log?.call('refused: too many joins from ${peer.address}');
      return _error('too-fast', 'too many join attempts; wait a minute');
    }
    final code = message['room'];
    final room = code is String ? hub._rooms[normalRoomCode(code)] : null;
    if (room == null) return _error('room-not-found');
    if (room.locked) return _error('room-locked');
    if (room.members.length >= hub.config.maxMembers) {
      return _error('room-full');
    }
    final nickname = _nickname(message);
    if (nickname == null) return;
    final member = _Member(room.nextId(), nickname, this);
    room.broadcast(
        {'type': 'joined', 'member': member.id, 'nickname': nickname},
        except: null);
    room.members[member.id] = member;
    _room = room;
    _member = member;
    _send({
      'type': 'entered',
      'room': room.code,
      'you': member.id,
      'token': member.token,
      'host': room.host,
      'members': room.list,
    });
  }

  void _resume(Map<String, Object?> message) {
    final hub = _hub;
    if (_room != null) return _error('already-in-room');
    final code = message['room'];
    final room = code is String ? hub._rooms[normalRoomCode(code)] : null;
    final member = room?.members[message['member']];
    if (room == null ||
        member == null ||
        member.awaySince == null ||
        member.token != message['token']) {
      return _error('cannot-resume');
    }
    member
      ..connection = this
      ..awaySince = null;
    _room = room;
    _member = member;
    _send({
      'type': 'resumed',
      'room': room.code,
      'you': member.id,
      'host': room.host,
      'members': room.list,
    });
    while (member.waiting.isNotEmpty) {
      peer.send(member.waiting.removeFirst());
    }
  }

  void _relay(Map<String, Object?> message, {required bool direct}) {
    final hub = _hub;
    final room = _room;
    if (room == null) return _error('not-in-room');
    final data = message['data'];
    if (data is! String) {
      return _error('bad-message', 'data is the text to send');
    }
    final now = hub._clock();
    final second = DateTime.fromMillisecondsSinceEpoch(
        now.millisecondsSinceEpoch ~/ 1000 * 1000);
    if (second != _second) {
      _second = second;
      _sentThisSecond = 0;
    }
    final limit = hub.config.messagesPerSecond;
    if (++_sentThisSecond > limit) {
      if (_sentThisSecond > 3 * limit) {
        _close(1008, 'too fast');
      } else {
        _error('too-fast', 'at most $limit messages a second');
      }
      return;
    }
    room.lastActivity = now;
    final me = _member!;
    final out = {
      'type': 'message',
      'from': me.id,
      'data': data,
      if (direct) 'direct': true,
    };
    if (hub.config.logMessages) {
      hub.log?.call('${room.code} ${me.id}: $data');
    }
    if (direct) {
      final to = room.members[message['to']];
      if (to == null) return _error('no-member');
      to.deliver(jsonEncode(out));
    } else {
      room.broadcast(out, except: me);
    }
  }

  void _close(int code, String reason) {
    peer.close(code, reason);
    _gone(forGood: true);
  }

  /// The peer's connection is gone: its member keeps its place for
  /// [RelayConfig.reconnectSeconds], waiting to `resume`.
  void disconnected() => _gone(forGood: false);

  void _gone({required bool forGood}) {
    if (!_hub._connections.remove(this)) return;
    final room = _room;
    final member = _member;
    _room = null;
    _member = null;
    if (room == null || member == null) return;
    if (forGood || _hub.config.reconnectSeconds == 0) {
      _hub._leave(room, member);
    } else {
      member
        ..connection = null
        ..awaySince = _hub._clock();
    }
  }
}
