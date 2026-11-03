import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_lang/testing.dart';
import 'package:test/test.dart';

/// How a WebSocket's events run (docs/DESIGN.md D136): in turn, never
/// re-entering their handler, waiting for a MsgBox, and the connection
/// closed when the program ends.
final _form = readFormFile('''
formatVersion: 1
controls:
  - { name: btnGo, type: Button }
  - { name: btnOther, type: Button }
  - { name: wsChat, type: WebSocket }
''', name: 'Form1').form;

final _server = parseWebSocketScript('''
CONNECT ws://localhost:8080/chat
ON go
< one
< two
< three
''');

Future<List<String>> _run(String source, String script) =>
    runEventScript(source, _form, script, webSockets: _server);

void main() {
  test('a message that comes while its handler waits in DoEvents waits',
      () async {
    final lines = await _run('''
Sub btnGo_Click()
    wsChat.Connect("ws://localhost:8080/chat")
    wsChat.Send("go")
End Sub

Sub wsChat_Message(e As MessageEventArgs)
    Debug.Print("start " & e.Text)
    DoEvents()
    DoEvents()
    Debug.Print("end " & e.Text)
End Sub
''', 'btnGo.Click\n${'btnOther.Click\n' * 12}');
    // A handler waiting in DoEvents lets the script go on: each click on
    // btnOther, which has no handler, lets the handlers go on a little.
    expect(lines.where((l) => l.startsWith('Debug.Print')).toList(), [
      'Debug.Print: start one',
      'Debug.Print: end one',
      'Debug.Print: start two',
      'Debug.Print: end two',
      'Debug.Print: start three',
      'Debug.Print: end three',
    ]);
  });

  test('while a MsgBox is open, the messages wait for it', () async {
    final lines = await _run('''
Sub btnGo_Click()
    wsChat.Connect("ws://localhost:8080/chat")
    wsChat.Send("go")
End Sub

Sub wsChat_Message(e As MessageEventArgs)
    If e.Text = "one" Then MsgBox("first")
    Debug.Print(e.Text)
End Sub
''', 'btnGo.Click\nOK\n');
    expect(lines, [
      '> btnGo.Click',
      'WebSocket: connect ws://localhost:8080/chat',
      'WebSocket: send go',
      'MsgBox: first',
      '> OK',
      'Debug.Print: one',
      'Debug.Print: two',
      'Debug.Print: three',
      'Still open',
      'WebSocket: close',
      'Closed',
    ]);
  });

  test('an event without a handler, or after the program ended, runs nothing',
      () async {
    final lines = await _run('''
Sub btnGo_Click()
    wsChat.Connect("ws://localhost:8080/chat")
    wsChat.Send("go")
    End
End Sub
''', 'btnGo.Click\n');
    expect(lines, [
      '> btnGo.Click',
      'WebSocket: connect ws://localhost:8080/chat',
      'WebSocket: send go',
      'WebSocket: close',
      'Ended',
    ]);
  });
}
