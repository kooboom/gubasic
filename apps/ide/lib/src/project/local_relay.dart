import 'local_relay_stub.dart'
    if (dart.library.io) 'local_relay_io.dart'
    as platform;

/// The relay server the desktop IDE runs on this computer for Room
/// (docs/DESIGN.md D136): started when a program whose Room has no Server
/// runs, on a free port, kept while the IDE is open. It listens on
/// `127.0.0.1` alone until "Allow devices on the same network" is turned
/// on, and on every interface only while it is. The web IDE has none: a
/// browser cannot open a server.
abstract class LocalRelay {
  /// The platform's: the desktop's, or none on the web.
  factory LocalRelay() => platform.makeLocalRelay();

  /// Whether this IDE can run one.
  bool get available;

  /// Starts it if it has not started; its address on this computer,
  /// `ws://127.0.0.1:53421/room`. Null where there is none.
  Future<String?> start();

  /// The address on this computer, once started.
  String? get localAddress;

  /// Whether devices on the same network may connect.
  bool get sameNetwork;

  /// Listens on every interface ([on]) or on `127.0.0.1` alone, keeping
  /// the port and the rooms; turning it off closes the other devices'
  /// connections. Starts the server first if it has not started.
  Future<void> setSameNetwork(bool on);

  /// The addresses other devices on the same network use, one for each of
  /// this computer's network addresses (`ws://<address>:53421/room`);
  /// empty while [sameNetwork] is off.
  Future<List<String>> networkAddresses();

  Future<void> close();
}
