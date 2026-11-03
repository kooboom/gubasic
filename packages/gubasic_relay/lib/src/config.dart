import 'package:yaml/yaml.dart';

/// The relay server's settings (docs/DESIGN.md D136), as `relay.yaml`
/// gives them; every one has a default fit for a class or a school event.
class RelayConfig {
  const RelayConfig({
    this.bind = '127.0.0.1',
    this.port = 7071,
    this.maxRooms = 50,
    this.maxMembers = 50,
    this.maxMessageBytes = 16384,
    this.messagesPerSecond = 20,
    this.joinAttemptsPerMinute = 30,
    this.idleMinutes = 30,
    this.maxRoomMinutes = 360,
    this.allowedOrigins = const [],
    this.key,
    this.logMessages = false,
    this.reconnectSeconds = 30,
  });

  /// The address to listen on: `127.0.0.1`, behind Apache.
  final String bind;
  final int port;

  /// Rooms open at once on the whole server; beyond, `server-full`.
  final int maxRooms;

  /// Members in one room, its host among them; beyond, `room-full`.
  final int maxMembers;

  /// A message's size in UTF-8 bytes; beyond, `too-big`, and the third
  /// time the connection is closed.
  final int maxMessageBytes;

  /// Messages a member may send in a second; beyond, `too-fast`, and
  /// three times as many closes the connection.
  final int messagesPerSecond;

  /// `join` attempts from one address in a minute, against guessing
  /// codes; beyond, `too-fast`.
  final int joinAttemptsPerMinute;

  /// A room no one has sent anything in for this long is closed (`idle`);
  /// one open this long is closed whatever (`time`).
  final int idleMinutes;
  final int maxRoomMinutes;

  /// The web pages that may connect, by their Origin
  /// (`https://quiz.example.com`); empty: any page, for development.
  final List<String> allowedOrigins;

  /// A word a program must give in `hello` to use the server; null for
  /// none. It goes into the apps as it is: a door that keeps strangers
  /// out, not a secret.
  final String? key;

  /// Whether message bodies are written to the log; never by default.
  final bool logMessages;

  /// How long a member whose connection was lost keeps its place, waiting
  /// to come back (`resume`).
  final int reconnectSeconds;

  /// Reads `relay.yaml`; a setting left out keeps its default. Throws a
  /// [FormatException] naming a setting that is wrong.
  factory RelayConfig.fromYaml(String text) {
    final doc = loadYaml(text);
    if (doc == null) return const RelayConfig();
    if (doc is! YamlMap) {
      throw const FormatException('relay.yaml holds settings, name: value');
    }
    const known = {
      'bind', 'port', 'maxRooms', 'maxMembers', 'maxMessageBytes', //
      'messagesPerSecond', 'joinAttemptsPerMinute', 'idleMinutes',
      'maxRoomMinutes', 'allowedOrigins', 'key', 'logMessages',
      'reconnectSeconds',
    };
    for (final k in doc.keys) {
      if (!known.contains(k)) {
        throw FormatException('relay.yaml: no setting named "$k"; the '
            'settings are ${known.join(', ')}');
      }
    }
    int number(String name, int fallback, {int min = 1}) {
      final v = doc[name] ?? fallback;
      if (v is! int || v < min) {
        throw FormatException('relay.yaml: $name is a whole number from '
            '$min');
      }
      return v;
    }

    final origins = doc['allowedOrigins'] ?? const <String>[];
    if (origins is! List || origins.any((o) => o is! String)) {
      throw const FormatException(
          'relay.yaml: allowedOrigins is a list of addresses');
    }
    final key = doc['key'];
    if (key != null && (key is! String || key.isEmpty)) {
      throw const FormatException('relay.yaml: key is a word, or left out');
    }
    final bind = doc['bind'] ?? '127.0.0.1';
    final log = doc['logMessages'] ?? false;
    if (bind is! String || log is! bool) {
      throw const FormatException(
          'relay.yaml: bind is an address, logMessages true or false');
    }
    return RelayConfig(
      bind: bind,
      port: number('port', 7071, min: 0),
      maxRooms: number('maxRooms', 50),
      maxMembers: number('maxMembers', 50, min: 2),
      maxMessageBytes: number('maxMessageBytes', 16384, min: 256),
      messagesPerSecond: number('messagesPerSecond', 20),
      joinAttemptsPerMinute: number('joinAttemptsPerMinute', 30),
      idleMinutes: number('idleMinutes', 30),
      maxRoomMinutes: number('maxRoomMinutes', 360),
      allowedOrigins: List.unmodifiable(origins.cast<String>()),
      key: key as String?,
      logMessages: log,
      reconnectSeconds: number('reconnectSeconds', 30, min: 0),
    );
  }

  /// The same settings with [bind] and [port] changed.
  RelayConfig listeningOn(String bind, int port) => RelayConfig(
        bind: bind,
        port: port,
        maxRooms: maxRooms,
        maxMembers: maxMembers,
        maxMessageBytes: maxMessageBytes,
        messagesPerSecond: messagesPerSecond,
        joinAttemptsPerMinute: joinAttemptsPerMinute,
        idleMinutes: idleMinutes,
        maxRoomMinutes: maxRoomMinutes,
        allowedOrigins: allowedOrigins,
        key: key,
        logMessages: logMessages,
        reconnectSeconds: reconnectSeconds,
      );
}
