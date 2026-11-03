import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The Room control (docs/DESIGN.md D136). How it runs is in the parity
/// programs room_basics, room_errors and room_reconnect.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: rmQuiz, type: Room, properties: { Nickname: TV, Server: "wss://relay.example.com/room" } }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('a Room in its component.yaml', () {
    final room = builtinComponents['room']!;
    expect(room.visual, isFalse);
    expect(room.channel, isTrue);
    expect(room.defaultEvent, 'Message');
    expect(room.designProperties.map((p) => p.name),
        ['Server', 'Nickname', 'Tag']);
    expect(room.properties['members']!.type, const ArrayType(GbType.string));
    expect(room.events.keys, ['message', 'joined', 'left', 'closed', 'error']);
    expect(room.methods.keys, [
      'create', 'join', 'send', 'sendto', 'leave', 'lock', 'nicknameof', //
    ]);
    expect(_form.control('rmQuiz')!.valueOf('Server'),
        'wss://relay.example.com/room');
  });

  test('its handlers, members and methods', () {
    expect(
        _codes('Sub rmQuiz_Message(e As RoomEventArgs)\n'
            'Debug.Print(e.Member & e.Nickname & e.Text & e.Json.Kind)\n'
            'rmQuiz.SendTo(e.Member, "ok")\nEnd Sub\n'
            'Sub rmQuiz_Closed(e As RoomEventArgs)\nDebug.Print(e.Reason)\n'
            'End Sub\n'
            'Sub rmQuiz_Error(e As RoomEventArgs)\nDebug.Print(e.Message)\n'
            'End Sub\n'
            'Sub F()\nrmQuiz.Create()\nrmQuiz.Join(rmQuiz.Code, "Kim")\n'
            'Dim n As Integer = rmQuiz.Members.Length\n'
            'If rmQuiz.IsHost Then rmQuiz.Lock()\n'
            'Debug.Print(rmQuiz.NicknameOf(rmQuiz.Me) & n)\n'
            'rmQuiz.Nickname = "TV 2"\nrmQuiz.Leave()\nEnd Sub\n'),
        isEmpty);
    expect(_codes('Sub F()\nrmQuiz.Code = "X"\nEnd Sub\n'), ['A034@2']);
    expect(_codes('Sub rmQuiz_Joined()\nEnd Sub\n'), ['A032@1']);
  });

  test('a ws:// Server beyond this computer and its network (A077)', () {
    expect(
        _codes('Sub F()\nrmQuiz.Server = "ws://relay.example.com/room"\n'
            'End Sub\n'),
        ['A077@2']);
    expect(
        _codes('Sub F()\nrmQuiz.Server = "ws://192.168.0.12:53421/room"\n'
            'End Sub\n'),
        isEmpty);
  });

  test('Rooms without a Server, for A078 at export', () {
    final empty = readFormFile('''
formatVersion: 1
controls:
  - { name: rmA, type: Room }
  - { name: rmB, type: Room, properties: { Server: " " } }
''', name: 'FormTV').form;
    expect(roomsWithoutServer([_form, empty]), ['FormTV.rmA', 'FormTV.rmB']);
  });
}
