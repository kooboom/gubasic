/// GuBASIC's Integer: an exact 64-bit integer on every platform (D26).
///
/// This is the only place where Integer arithmetic and overflow checks are
/// written. The VM uses Dart's native 64-bit `int`; JavaScript has no
/// 64-bit integers, so the web uses `Int64` from package:fixnum. Both
/// implementations have the same API and give the same results; a test
/// runs them on the VM and in Chrome.
library;

export 'checked_math_native.dart'
    if (dart.library.js_interop) 'checked_math_web.dart';
