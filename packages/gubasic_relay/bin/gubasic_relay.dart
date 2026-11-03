import 'dart:async';
import 'dart:io';

import 'package:gubasic_relay/gubasic_relay.dart';

/// `gubasic-relay [--config relay.yaml] [--bind ADDRESS] [--port N]`:
/// runs the relay server until it is stopped (docs/RELAY_SERVER.md).
Future<void> main(List<String> args) async {
  String? configPath;
  String? bind;
  int? port;
  for (var i = 0; i < args.length; i++) {
    String value() => i + 1 < args.length
        ? args[++i]
        : (throw ArgumentError('${args[i]} needs a value'));
    switch (args[i]) {
      case '--config':
        configPath = value();
      case '--bind':
        bind = value();
      case '--port':
        port = int.tryParse(value());
        if (port == null) _usage('--port takes a number');
      case '--version':
        stdout.writeln('gubasic-relay $relayVersion');
        return;
      case '--help' || '-h':
        _usage(null);
      default:
        _usage('no option ${args[i]}');
    }
  }
  var config = const RelayConfig();
  if (configPath != null) {
    try {
      config = RelayConfig.fromYaml(File(configPath).readAsStringSync());
    } on FileSystemException catch (e) {
      _usage('cannot read $configPath: ${e.osError?.message ?? e.message}');
    } on FormatException catch (e) {
      _usage(e.message);
    }
  }
  if (bind != null || port != null) {
    config = config.listeningOn(bind ?? config.bind, port ?? config.port);
  }
  void log(String line) =>
      stdout.writeln('${DateTime.now().toUtc().toIso8601String()} $line');
  final server = await RelayServer.start(config, log: log);
  final stopping = Completer<void>();
  for (final signal in [ProcessSignal.sigint, ProcessSignal.sigterm]) {
    if (Platform.isWindows && signal == ProcessSignal.sigterm) continue;
    signal.watch().listen((_) {
      if (!stopping.isCompleted) stopping.complete();
    });
  }
  await stopping.future;
  log('stopping');
  await server.close();
  exit(0);
}

Never _usage(String? problem) {
  if (problem != null) stderr.writeln('gubasic-relay: $problem');
  stderr.writeln('usage: gubasic-relay [--config relay.yaml] '
      '[--bind ADDRESS] [--port N] [--version]');
  exit(problem == null ? 0 : 64);
}
