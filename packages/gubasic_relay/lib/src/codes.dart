import 'dart:math';

/// The characters of a room code: digits and capital letters without the
/// ones that look alike (0 and O, 1 and I), 32 of them.
const roomCodeAlphabet = '23456789ABCDEFGHJKLMNPQRSTUVWXYZ';

/// How long a room code is: 32⁶, about 1.07 billion codes.
const roomCodeLength = 6;

/// Makes room codes (docs/DESIGN.md D136).
abstract class RoomCodes {
  /// Codes from a secure random number generator.
  factory RoomCodes() => _SecureCodes();

  /// [codes] in turn, for tests; then the secure ones.
  factory RoomCodes.fixed(List<String> codes) => _FixedCodes(codes);

  String next();
}

class _SecureCodes implements RoomCodes {
  final _random = Random.secure();

  @override
  String next() => String.fromCharCodes([
        for (var i = 0; i < roomCodeLength; i++)
          roomCodeAlphabet.codeUnitAt(_random.nextInt(roomCodeAlphabet.length)),
      ]);
}

class _FixedCodes implements RoomCodes {
  _FixedCodes(List<String> codes) : _codes = List.of(codes);

  final List<String> _codes;
  final _secure = _SecureCodes();

  @override
  String next() => _codes.isEmpty ? _secure.next() : _codes.removeAt(0);
}

/// A code as the program wrote it, in the form rooms are kept by: capital
/// letters, no spaces.
String normalRoomCode(String code) =>
    code.trim().toUpperCase().replaceAll(RegExp(r'[\s-]'), '');

/// A secret that lets a member come back after its connection was lost.
String resumeToken() {
  final r = Random.secure();
  return [for (var i = 0; i < 16; i++) r.nextInt(256)]
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
}
