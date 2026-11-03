import 'dart:io';

import 'package:gubasic_relay/gubasic_relay.dart';

import 'local_relay.dart';

/// The desktop IDE's relay server (D136).
LocalRelay makeLocalRelay() => IoLocalRelay();

class IoLocalRelay implements LocalRelay {
  RelayServer? _server;
  Future<RelayServer>? _starting;
  var _sameNetwork = false;

  @override
  bool get available => true;

  @override
  String? get localAddress =>
      _server == null ? null : 'ws://127.0.0.1:${_server!.port}/room';

  @override
  bool get sameNetwork => _sameNetwork;

  Future<RelayServer> _started() => _starting ??= RelayServer.start(
    // Every limit as a real server has it; the port a free one.
    const RelayConfig().listeningOn('127.0.0.1', 0),
  ).then((s) => _server = s);

  @override
  Future<String?> start() async {
    await _started();
    return localAddress;
  }

  @override
  Future<void> setSameNetwork(bool on) async {
    final server = await _started();
    if (on == _sameNetwork) return;
    _sameNetwork = on;
    await server.rebind(on ? InternetAddress.anyIPv4.address : '127.0.0.1');
    if (!on) {
      // Only this computer from now on.
      server.hub.dropConnections(
        (peer) =>
            !(InternetAddress.tryParse(peer.address)?.isLoopback ?? false),
      );
    }
  }

  @override
  Future<List<String>> networkAddresses() async {
    final server = _server;
    if (server == null || !_sameNetwork) return const [];
    final interfaces = await NetworkInterface.list(
      type: InternetAddressType.IPv4,
    );
    return [
      for (final i in interfaces)
        for (final a in i.addresses)
          if (!a.isLoopback && !a.isLinkLocal)
            'ws://${a.address}:${server.port}/room',
    ];
  }

  @override
  Future<void> close() async {
    await _server?.close();
    _server = null;
    _starting = null;
  }
}
