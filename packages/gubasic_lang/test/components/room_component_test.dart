import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// RoomComponent (docs/DESIGN.md D136) on the test's relay server in
/// memory, with a connection that can be refused.
class _Room extends RoomComponent {
  _Room(this.rooms, {String? server = 'ws://127.0.0.1:7071/room'})
      : super('rmQuiz', defaultServer: server);

  final ScriptedRooms rooms;
  var refuse = false;
  final events = <String>[];

  @override
  Duration get reconnectFor => const Duration(milliseconds: 80);

  @override
  Future<void> pause(Duration d) =>
      Future<void>.delayed(const Duration(milliseconds: 5));

  @override
  Future<WebSocketLink> open(String url, WebSocketListener listener) async {
    if (refuse) throw const WebSocketFailure('refused');
    return rooms.open(url, listener);
  }
}

Future<void> _settle() => Future<void>.delayed(const Duration(milliseconds: 1));

void main() {
  late List<String> transcript;
  late ScriptedRooms rooms;
  late _Room room;

  setUp(() {
    transcript = [];
    rooms = ScriptedRooms(transcript);
    room = _Room(rooms)
      ..onEvent = (name, args) {
        final e = args.single as GbRoomEvent;
        room.events.add('$name ${e.member}${e.reason}${e.text}');
      };
  });

  test('without a relay server, Create is R048', () async {
    final none = _Room(rooms, server: null);
    await expectLater(
        none.call('Create', const []),
        throwsA(isA<ComponentProblem>()
            .having((p) => p.code, 'code', DiagnosticCode.roomNotEntered)
            .having((p) => p.args, 'args',
                ['no relay server (Room.Server is empty)'])));
  });

  test('a connection that cannot be opened is R047', () async {
    room.refuse = true;
    await expectLater(
        room.call('Create', const []),
        throwsA(isA<ComponentProblem>()
            .having((p) => p.code, 'code', DiagnosticCode.webSocketFailed)));
  });

  test('Sends while the connection comes back wait, and go after it', () async {
    await room.call('Create', const []);
    rooms.peerDoes(const PeerAction('민지', 'Join', ''));
    await _settle();
    room.refuse = true;
    rooms.serverDoes('Drop', '');
    await _settle();
    await room.call('Send', ['while away']);
    expect(transcript, isNot(contains('Room: send while away')));
    room.refuse = false;
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(
        transcript,
        containsAllInOrder([
          'Room: resume',
          'Room: send while away',
          'Peer 민지 got: while away'
        ]));
    expect(room.getProperty('Code'), 'K7QPXM');
    expect(room.events, ['Joined m2']);
  });

  test('a connection that does not come back closes the room', () async {
    await room.call('Create', const []);
    room.refuse = true;
    rooms.serverDoes('Drop', '');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(room.events, ['Closed connection lost']);
    expect(room.getProperty('Code'), '');
    await expectLater(
        room.call('Send', ['x']), throwsA(isA<ComponentProblem>()));
  });

  test('Leave and dispose close the connection; no event', () async {
    await room.call('Create', const []);
    await room.call('Leave', const []);
    expect(transcript.last, 'Room: leave');
    expect(room.getProperty('IsHost'), false);
    await room.call('Create', const []);
    room.dispose();
    expect(transcript.last, 'Room: leave');
    expect(room.events, isEmpty);
  });
}
