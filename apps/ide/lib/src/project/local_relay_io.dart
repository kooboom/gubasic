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
  ).then((s) => _server = s..fallback = _servePreview);

  /// The web app "Preview on the Web" serves, by path.
  Map<String, List<int>> _files = const {};

  static const _types = {
    'html': 'text/html; charset=utf-8',
    'js': 'text/javascript',
    'mjs': 'text/javascript',
    'json': 'application/json',
    'wasm': 'application/wasm',
    'png': 'image/png',
    'ico': 'image/x-icon',
    'otf': 'font/otf',
    'ttf': 'font/ttf',
    'css': 'text/css',
    'gbz': 'application/zip',
    'txt': 'text/plain; charset=utf-8',
  };

  Future<bool> _servePreview(HttpRequest request) async {
    var path = Uri.decodeComponent(request.uri.path);
    if (path.endsWith('/')) path = '${path}index.html';
    final bytes = _files[path.substring(1)];
    if (bytes == null || request.method != 'GET') return false;
    final type = _types[path.split('.').last.toLowerCase()];
    request.response.headers
      ..set(HttpHeaders.contentTypeHeader, type ?? 'application/octet-stream')
      // Always the project as it is now.
      ..set(HttpHeaders.cacheControlHeader, 'no-store');
    request.response.add(bytes);
    await request.response.close();
    return true;
  }

  @override
  Future<void> serve(Map<String, List<int>> files) async {
    await _started();
    _files = files;
  }

  @override
  String? get previewAddress =>
      _server == null ? null : 'http://localhost:${_server!.port}/';

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
