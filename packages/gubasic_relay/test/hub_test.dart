import 'dart:convert';

import 'package:gubasic_relay/gubasic_relay_hub.dart';
import 'package:test/test.dart';

/// The room protocol in memory (docs/ROOM_PROTOCOL.md, DESIGN D136).
class _Peer implements RelayPeer {
  _Peer(this.hub, [this.address = '192.0.2.1']) {
    connection = hub.connect(this);
  }

  final RoomHub hub;
  @override
  final String address;
  late final RelayConnection connection;
  final got = <Map<String, Object?>>[];
  String? closed;

  @override
  void send(String text) => got.add(jsonDecode(text) as Map<String, Object?>);

  @override
  void close(int code, String reason) => closed = '$code $reason';

  void say(Map<String, Object?> message) =>
      connection.receive(jsonEncode(message));

  Map<String, Object?> get last => got.last;

  List<Map<String, Object?>> take() {
    final all = List.of(got);
    got.clear();
    return all;
  }

  _Peer hello([String? key]) {
    say({'type': 'hello', 'v': 1, if (key != null) 'key': key});
    expect(take(), [
      {'type': 'welcome', 'v': 1}
    ]);
    return this;
  }
}

void main() {
  var now = DateTime.utc(2026, 11, 3, 9);
  late RoomHub hub;
  RoomHub make([RelayConfig config = const RelayConfig()]) => hub = RoomHub(
      config: config,
      codes: RoomCodes.fixed(['K7QPXM', 'ABCDEF', 'GHJKLM']),
      clock: () => now);

  setUp(() {
    now = DateTime.utc(2026, 11, 3, 9);
    make();
  });

  test('create, join, send, sendTo, leave', () {
    final tv = _Peer(hub).hello();
    tv.say({'type': 'create', 'nickname': 'TV'});
    final created = tv.take().single;
    expect(created['type'], 'created');
    expect(created['room'], 'K7QPXM');
    expect(created['you'], 'm1');
    expect(created['token'], hasLength(32));

    final phone = _Peer(hub, '192.0.2.2').hello();
    phone.say({'type': 'join', 'room': 'k7q pxm', 'nickname': '민지'});
    final entered = phone.take().single;
    expect(entered..remove('token'), {
      'type': 'entered',
      'room': 'K7QPXM',
      'you': 'm2',
      'host': 'm1',
      'members': [
        {'member': 'm1', 'nickname': 'TV'},
        {'member': 'm2', 'nickname': '민지'},
      ],
    });
    expect(tv.take(), [
      {'type': 'joined', 'member': 'm2', 'nickname': '민지'}
    ]);

    phone.say({'type': 'send', 'data': '{"choice":2}'});
    expect(phone.take(), isEmpty);
    expect(tv.take(), [
      {'type': 'message', 'from': 'm2', 'data': '{"choice":2}'}
    ]);
    tv.say({'type': 'sendTo', 'to': 'm2', 'data': 'right!'});
    expect(phone.take(), [
      {'type': 'message', 'from': 'm1', 'data': 'right!', 'direct': true}
    ]);
    tv.say({'type': 'sendTo', 'to': 'm9', 'data': 'x'});
    expect(tv.last, {'type': 'error', 'code': 'no-member'});

    phone.say({'type': 'leave'});
    expect(tv.take().last, {'type': 'left', 'member': 'm2'});
    expect(phone.connection.room, isNull);
    expect(hub.roomCount, 1);
  });

  test('the host leaving ends the room', () {
    final tv = _Peer(hub).hello()..say({'type': 'create'});
    final phone = _Peer(hub).hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'Kim'});
    phone.take();
    tv.say({'type': 'leave'});
    expect(phone.take(), [
      {'type': 'closed', 'reason': 'host left'}
    ]);
    expect(hub.roomCount, 0);
    phone.say({'type': 'send', 'data': 'x'});
    expect(phone.last, {'type': 'error', 'code': 'not-in-room'});
  });

  test('hello first, the version, and the key', () {
    final p = _Peer(hub);
    p.say({'type': 'create'});
    expect(p.last['code'], 'bad-message');
    p.say({'type': 'hello', 'v': 2});
    expect(p.last['code'], 'bad-version');
    expect(p.closed, '1008 bad version');

    make(const RelayConfig(key: 'door'));
    final wrong = _Peer(hub)..say({'type': 'hello', 'v': 1, 'key': 'x'});
    expect(wrong.last, {'type': 'error', 'code': 'bad-key'});
    expect(wrong.closed, '1008 bad key');
    _Peer(hub).hello('door');
  });

  test('messages that are not the protocol\'s', () {
    final p = _Peer(hub).hello();
    p.connection.receive('not json');
    expect(p.last['code'], 'bad-message');
    p.say({'type': 'dance'});
    expect(p.last['code'], 'bad-message');
    p.say({'type': 'join', 'room': 'NOROOM', 'nickname': 'Kim'});
    expect(p.last, {'type': 'error', 'code': 'room-not-found'});
    p.say({'type': 'create', 'nickname': ''});
    expect(p.last['code'], 'bad-nickname');
    p.say({'type': 'create', 'nickname': 'x' * 41});
    expect(p.last['code'], 'bad-nickname');
  });

  test('maxRooms: server-full', () {
    make(const RelayConfig(maxRooms: 2));
    for (var i = 0; i < 2; i++) {
      _Peer(hub).hello().say({'type': 'create'});
    }
    final third = _Peer(hub).hello()..say({'type': 'create'});
    expect(third.last, {'type': 'error', 'code': 'server-full'});
  });

  test('maxMembers: room-full, and a locked room', () {
    make(const RelayConfig(maxMembers: 2));
    final tv = _Peer(hub).hello()..say({'type': 'create'});
    _Peer(hub).hello().say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'a'});
    final late = _Peer(hub).hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'b'});
    expect(late.last, {'type': 'error', 'code': 'room-full'});

    make();
    final host = _Peer(hub).hello()..say({'type': 'create'});
    final guest = _Peer(hub).hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'a'});
    guest.say({'type': 'lock'});
    expect(guest.last, {'type': 'error', 'code': 'not-host'});
    host.say({'type': 'lock'});
    expect(guest.last, {'type': 'locked'});
    final after = _Peer(hub).hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'b'});
    expect(after.last, {'type': 'error', 'code': 'room-locked'});
    expect(tv.closed, isNull);
  });

  test('maxMessageBytes: too-big, and the third time the connection closes',
      () {
    make(const RelayConfig(maxMessageBytes: 300));
    final p = _Peer(hub).hello()..say({'type': 'create'});
    final big = jsonEncode({'type': 'send', 'data': '가' * 100});
    for (var i = 0; i < 2; i++) {
      p.connection.receive(big);
      expect(p.last['code'], 'too-big');
    }
    expect(p.closed, isNull);
    p.connection.receive(big);
    expect(p.closed, '1009 too big');
    expect(hub.roomCount, 0, reason: 'its host is gone for good');
  });

  test('messagesPerSecond: too-fast, three times as many closes', () {
    make(const RelayConfig(messagesPerSecond: 2));
    final tv = _Peer(hub).hello()..say({'type': 'create'});
    final p = _Peer(hub).hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'a'});
    tv.take();
    p.take();
    for (var i = 0; i < 3; i++) {
      p.say({'type': 'send', 'data': '$i'});
    }
    expect(p.last['code'], 'too-fast');
    expect(tv.take().length, 2);
    now = now.add(const Duration(seconds: 1));
    p.say({'type': 'send', 'data': 'next second'});
    expect(tv.take().single['data'], 'next second');
    for (var i = 0; i < 6; i++) {
      p.say({'type': 'send', 'data': '$i'});
    }
    expect(p.closed, '1008 too fast');
  });

  test('joinAttemptsPerMinute, by address', () {
    make(const RelayConfig(joinAttemptsPerMinute: 3));
    final guesser = _Peer(hub, '198.51.100.7').hello();
    for (var i = 0; i < 3; i++) {
      guesser.say({'type': 'join', 'room': 'AAAAA$i', 'nickname': 'x'});
      expect(guesser.last['code'], 'room-not-found');
    }
    guesser.say({'type': 'join', 'room': 'AAAAA9', 'nickname': 'x'});
    expect(guesser.last['code'], 'too-fast');
    // Another address is not held back.
    final other = _Peer(hub, '198.51.100.8').hello()
      ..say({'type': 'join', 'room': 'AAAAA9', 'nickname': 'x'});
    expect(other.last['code'], 'room-not-found');
    now = now.add(const Duration(minutes: 1));
    guesser.say({'type': 'join', 'room': 'AAAAA9', 'nickname': 'x'});
    expect(guesser.last['code'], 'room-not-found');
  });

  test('idleMinutes and maxRoomMinutes', () {
    make(const RelayConfig(idleMinutes: 30, maxRoomMinutes: 60));
    final tv = _Peer(hub).hello()..say({'type': 'create'});
    tv.take();
    now = now.add(const Duration(minutes: 29));
    hub.sweep();
    expect(hub.roomCount, 1);
    tv.say({'type': 'send', 'data': 'still here'});
    now = now.add(const Duration(minutes: 29));
    hub.sweep();
    expect(hub.roomCount, 1);
    now = now.add(const Duration(minutes: 2));
    hub.sweep();
    expect(tv.take(), [
      {'type': 'closed', 'reason': 'time'}
    ]);

    final quiet = _Peer(hub).hello()..say({'type': 'create'});
    quiet.take();
    now = now.add(const Duration(minutes: 30));
    hub.sweep();
    expect(quiet.take(), [
      {'type': 'closed', 'reason': 'idle'}
    ]);
  });

  test('a lost connection keeps its place for reconnectSeconds', () {
    final tv = _Peer(hub).hello()..say({'type': 'create'});
    final phone = _Peer(hub).hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'Kim'});
    final token = phone.take().single['token'];
    tv.take();
    phone.connection.disconnected();
    tv.say({'type': 'send', 'data': 'question 2'});
    now = now.add(const Duration(seconds: 20));
    hub.sweep();
    expect(tv.take(), isEmpty, reason: 'no one is told yet');

    final again = _Peer(hub).hello()
      ..say({'type': 'resume', 'room': 'K7QPXM', 'member': 'm2', 'token': 'x'});
    expect(again.take().single['code'], 'cannot-resume');
    again.say(
        {'type': 'resume', 'room': 'K7QPXM', 'member': 'm2', 'token': token});
    final got = again.take();
    expect(got.first['type'], 'resumed');
    expect(got.last, {'type': 'message', 'from': 'm1', 'data': 'question 2'});

    // Away for longer: gone, and the others are told.
    again.connection.disconnected();
    now = now.add(const Duration(seconds: 30));
    hub.sweep();
    expect(tv.take(), [
      {'type': 'left', 'member': 'm2'}
    ]);
    // The host away for longer ends the room.
    tv.connection.disconnected();
    now = now.add(const Duration(seconds: 30));
    hub.sweep();
    expect(hub.roomCount, 0);
  });

  test('shutdown closes every room; dropConnections drops some', () {
    final a = _Peer(hub).hello()..say({'type': 'create'});
    final b = _Peer(hub, '192.168.0.5').hello()
      ..say({'type': 'join', 'room': 'K7QPXM', 'nickname': 'b'});
    a.take();
    hub.dropConnections((p) => p.address.startsWith('192.168.'));
    expect(b.closed, '1008 not allowed');
    expect(a.take(), [
      {'type': 'left', 'member': 'm2'}
    ]);
    hub.shutdown();
    expect(a.take(), [
      {'type': 'closed', 'reason': 'server'}
    ]);
  });

  test('room codes: 6 of the 32 characters, any case', () {
    expect(roomCodeAlphabet.length, 32);
    expect(roomCodeAlphabet, isNot(contains(RegExp('[01IO]'))));
    final codes = RoomCodes();
    for (var i = 0; i < 200; i++) {
      expect(codes.next(), matches(RegExp('^[$roomCodeAlphabet]{6}\$')));
    }
    expect(normalRoomCode(' k7q-pxm '), 'K7QPXM');
  });

  test('relay.yaml', () {
    final c = RelayConfig.fromYaml('''
port: 8080
maxRooms: 5
allowedOrigins: [https://quiz.example.com]
key: door
''');
    expect(c.port, 8080);
    expect(c.maxRooms, 5);
    expect(c.maxMembers, 50);
    expect(c.allowedOrigins, ['https://quiz.example.com']);
    expect(c.key, 'door');
    expect(c.bind, '127.0.0.1');
    expect(RelayConfig.fromYaml('').messagesPerSecond, 20);
    expect(() => RelayConfig.fromYaml('maxRoom: 5'),
        throwsA(isA<FormatException>()));
    expect(() => RelayConfig.fromYaml('maxRooms: many'),
        throwsA(isA<FormatException>()));
  });
}
