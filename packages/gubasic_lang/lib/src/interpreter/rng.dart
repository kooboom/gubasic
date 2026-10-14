import 'checked_math.dart';

/// `Rnd` and `Randomize`: SplitMix64, defined exactly so that the same
/// seed gives the same numbers on every platform (docs/LANGUAGE.md §10).
class GbRandom {
  GbInt _state = GbInt.zero;

  static final _gamma = GbInt.fromHalves(0x9E3779B9, 0x7F4A7C15);
  static final _mix1 = GbInt.fromHalves(0xBF58476D, 0x1CE4E5B9);
  static final _mix2 = GbInt.fromHalves(0x94D049BB, 0x133111EB);

  /// `Randomize seed`.
  void seed(GbInt seed) => _state = seed;

  /// `Rnd()`: a Double from 0 (inclusive) to 1 (exclusive).
  double next() {
    _state = _state.addWrapping(_gamma);
    var z = _state;
    z = z.xor(z.shiftRightUnsigned(30)).multiplyWrapping(_mix1);
    z = z.xor(z.shiftRightUnsigned(27)).multiplyWrapping(_mix2);
    z = z.xor(z.shiftRightUnsigned(31));
    // The top 53 bits, exact as a double on every platform.
    return z.shiftRightUnsigned(11).toDouble() / 9007199254740992.0;
  }
}
