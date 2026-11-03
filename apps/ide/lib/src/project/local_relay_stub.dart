import 'local_relay.dart';

/// The web IDE: no relay server (D136).
LocalRelay makeLocalRelay() => _NoRelay();

class _NoRelay implements LocalRelay {
  @override
  bool get available => false;

  @override
  Future<String?> start() async => null;

  @override
  String? get localAddress => null;

  @override
  bool get sameNetwork => false;

  @override
  Future<void> setSameNetwork(bool on) async {}

  @override
  Future<List<String>> networkAddresses() async => const [];

  @override
  Future<void> serve(Map<String, List<int>> files) async {}

  @override
  String? get previewAddress => null;

  @override
  Future<void> close() async {}
}
