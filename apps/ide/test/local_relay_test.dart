import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:gubasic_ide/src/project/local_relay_io.dart';

/// The desktop IDE's relay server (docs/DESIGN.md D136): on 127.0.0.1
/// alone until "Allow devices on the same network" is on; turned off, the
/// other devices' connections close.
void main() {
  test('localhost only while off; the network while on', () async {
    final relay = IoLocalRelay();
    addTearDown(relay.close);
    expect(relay.sameNetwork, isFalse);
    final here = (await relay.start())!;
    expect(here, matches(RegExp(r'^ws://127\.0\.0\.1:\d+/room$')));
    final port = Uri.parse(here).port;
    expect(await relay.networkAddresses(), isEmpty);

    Future<WebSocket> hello(String url) async {
      final ws = await WebSocket.connect(url);
      ws
        ..listen((_) {})
        ..add(jsonEncode({'type': 'hello', 'v': 1}));
      return ws;
    }

    // This computer always gets in.
    final local = await hello(here);
    // Another address of this computer, as a phone on the same network
    // would reach it; none on a machine without a network.
    final lan = [
      for (final i in await NetworkInterface.list(
        type: InternetAddressType.IPv4,
      ))
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal) a.address,
    ].firstOrNull;
    if (lan != null) {
      await expectLater(
        WebSocket.connect('ws://$lan:$port/room'),
        throwsA(isA<SocketException>()),
      );
    }

    await relay.setSameNetwork(true);
    expect(relay.sameNetwork, isTrue);
    expect(relay.localAddress, here, reason: 'the same port');
    if (lan != null) {
      expect(await relay.networkAddresses(), contains('ws://$lan:$port/room'));
      final phone = await hello('ws://$lan:$port/room');
      await relay.setSameNetwork(false);
      await phone.done;
      expect(phone.closeCode, 1008);
      await expectLater(
        WebSocket.connect('ws://$lan:$port/room'),
        throwsA(isA<SocketException>()),
      );
    } else {
      await relay.setSameNetwork(false);
    }
    // This computer's connection stays.
    expect(local.readyState, WebSocket.open);
    await local.close();
  });
}
