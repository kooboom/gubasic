import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:test/test.dart';

/// The WebSocket control (docs/DESIGN.md D136). How it runs is in the
/// parity program websocket_basics.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: wsChat, type: WebSocket, properties: { Tag: chat } }
''', name: 'Form1').form;

List<String> _codes(String source) => [
      for (final d in compile(source, form: _form).diagnostics)
        '${d.code.code}@${d.line}',
    ];

void main() {
  test('a WebSocket in its component.yaml: in the tray, through the channel',
      () {
    final ws = builtinComponents['websocket']!;
    expect(ws.visual, isFalse);
    expect(ws.channel, isTrue);
    expect(ws.object, isFalse);
    expect(ws.platforms, ['web', 'macos', 'windows']);
    expect(ws.defaultEvent, 'Message');
    expect(ws.designProperties.map((p) => p.name), ['Tag']);
    expect(ws.methods.keys, ['connect', 'send', 'close']);
    expect(ws.events.keys, ['message', 'closed', 'error']);
  });

  test('its handlers, members and methods', () {
    expect(
        _codes('Sub wsChat_Message(e As MessageEventArgs)\n'
            'Debug.Print(e.Text & e.Json.Kind & wsChat.State & wsChat.Url)\n'
            'wsChat.Send("hi")\nEnd Sub\n'
            'Sub wsChat_Closed(e As CloseEventArgs)\n'
            'Debug.Print(e.Reason)\nwsChat.Connect("wss://relay.example.com/x")\n'
            'End Sub\n'
            'Sub wsChat_Error(e As ErrorEventArgs)\n'
            'Debug.Print(e.Message)\nwsChat.Close()\nEnd Sub\n'),
        isEmpty);
    // Read-only (A034), and not made with New.
    expect(_codes('Sub F()\nwsChat.State = "Open"\nEnd Sub\n'), ['A034@2']);
    expect(_codes('Sub F()\nDim w As New WebSocket\nEnd Sub\n'),
        ['A052@2', 'A026@2']);
    // Winsock's names (A036, A051).
    expect(_codes('Sub F()\nwsChat.SendData("x")\nEnd Sub\n'), ['A036@2']);
    expect(_codes('Sub wsChat_DataArrival(e As MessageEventArgs)\nEnd Sub\n'),
        ['A051@1']);
  });

  test('ws:// beyond this computer and its network is a warning (A077)', () {
    List<String> connect(String url) =>
        _codes('Sub F()\nwsChat.Connect("$url")\nEnd Sub\n');
    expect(connect('ws://relay.example.com/room'), ['A077@2']);
    expect(connect('ws://203.0.113.5:7071/room'), ['A077@2']);
    for (final url in [
      'wss://relay.example.com/room',
      'ws://localhost:8080/chat',
      'ws://127.0.0.1:53421/room',
      'ws://192.168.0.12:53421/room',
      'ws://10.1.2.3/room',
      'ws://172.20.0.1/room',
    ]) {
      expect(connect(url), isEmpty, reason: url);
    }
    final d = compile(
            'Sub F()\nwsChat.Connect("ws://relay.example.com/a")\n'
            'End Sub\n',
            form: _form)
        .diagnostics
        .single;
    expect(d.severity, DiagnosticSeverity.warning);
  });
}
