import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_player/src/room_component.dart';

/// A Room's Server written as a path is on the web server that served the
/// app (D136).
void main() {
  test('a path is on the page\'s server; wss for an https page', () {
    expect(
      onPage('/room', Uri.parse('http://192.168.0.12:53421/')),
      'ws://192.168.0.12:53421/room',
    );
    expect(
      onPage('/room', Uri.parse('https://quiz.example.com/app/index.html')),
      'wss://quiz.example.com/room',
    );
    expect(
      onPage('wss://relay.example.com/room', Uri.parse('http://localhost/')),
      'wss://relay.example.com/room',
    );
    // On the desktop there is no page: the path stays, and cannot open.
    expect(onPage('/room', null), '/room');
  });
}
