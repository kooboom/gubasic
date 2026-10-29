import 'dart:async';

import 'package:flutter/gestures.dart';

/// The mouse's buttons as programs name them (docs/DESIGN.md D111), with
/// Visual Basic .NET's numbers: MouseButtons.Left, Right and Middle.
const gbMouseLeft = 1048576;
const gbMouseRight = 2097152;
const gbMouseMiddle = 4194304;

/// Receives a mouse button pressed or let go on [control] (null: the
/// form): [event] is `MouseDown` or `MouseUp`, [button] one of
/// [gbMouseLeft], [gbMouseRight], [gbMouseMiddle], and [x], [y] the place
/// from the control's top left corner.
typedef GbMouseSink = void Function(
  String? control,
  String event,
  int button,
  int x,
  int y,
);

/// How long a finger stays down for a long press, the right button on a
/// touch screen (D111): Flutter's own long press.
const gbLongPress = kLongPressTimeout;

/// Turns the pointer events of a form into MouseDown and MouseUp (D111).
/// The innermost control under the pointer [claim]s it as it goes down;
/// the form, which hears it last, then [down]s it. A mouse's buttons are
/// told at once. A finger is a left button when it is lifted, or a right
/// one once it has stayed down [gbLongPress] without moving; a click that
/// the long press would also make is then [swallowed].
class GbMouseTracker {
  GbMouseTracker(this.sink);

  final GbMouseSink sink;

  final _claims = <int, (String?, Offset)>{};
  final _down = <int, _Press>{};

  /// The control a long press went down on, whose click is not one.
  String? get swallowed => _swallowed;
  String? _swallowed;

  /// The innermost control under [event]'s pointer, at [local] on it:
  /// the first to hear it.
  void claim(PointerDownEvent event, String control, Offset local) =>
      _claims.putIfAbsent(event.pointer, () => (control, local));

  /// [event] reaches the form, at [formLocal] on it.
  void down(PointerDownEvent event, Offset formLocal) {
    final (control, local) = _claims.remove(event.pointer) ?? (null, formLocal);
    final press = _Press(control, formLocal - local);
    _down[event.pointer] = press;
    if (event.kind == PointerDeviceKind.mouse) {
      press.button = switch (event.buttons) {
        final b when b & kSecondaryMouseButton != 0 => gbMouseRight,
        final b when b & kMiddleMouseButton != 0 => gbMouseMiddle,
        _ => gbMouseLeft,
      };
      _tell(press, 'MouseDown', local);
      return;
    }
    press.at = local;
    press.timer = Timer(gbLongPress, () {
      press.button = gbMouseRight;
      _tell(press, 'MouseDown', press.at!);
    });
  }

  /// The finger moved: past a little, it is no long press but a left
  /// button already down.
  void move(PointerMoveEvent event, Offset formLocal) {
    final press = _down[event.pointer];
    if (press == null || press.timer?.isActive != true) return;
    if ((formLocal - press.origin - press.at!).distance > kTouchSlop) {
      press.timer!.cancel();
      press.button = gbMouseLeft;
      _tell(press, 'MouseDown', press.at!);
    }
  }

  /// The button or the finger goes up, at [formLocal] on the form.
  void up(PointerEvent event, Offset formLocal) {
    final press = _down.remove(event.pointer);
    if (press == null) return;
    final local = formLocal - press.origin;
    if (press.timer?.isActive == true) {
      press.timer!.cancel();
      press.button = gbMouseLeft;
      _tell(press, 'MouseDown', press.at!);
    } else if (press.button == gbMouseRight && press.at != null) {
      // A long press: the tap it also is goes to nothing (D111).
      _swallowed = press.control ?? '';
      scheduleMicrotask(() => _swallowed = null);
    }
    _tell(press, 'MouseUp', local);
  }

  /// The pointer went away without going up.
  void cancel(PointerCancelEvent event) {
    _claims.remove(event.pointer);
    _down.remove(event.pointer)?.timer?.cancel();
  }

  void _tell(_Press press, String event, Offset at) =>
      sink(press.control, event, press.button, at.dx.floor(), at.dy.floor());
}

class _Press {
  _Press(this.control, this.origin);

  final String? control;

  /// Where the control's top left corner is on the form.
  final Offset origin;

  int button = gbMouseLeft;

  /// For a finger: where it went down on the control, and the long press
  /// it may become.
  Offset? at;
  Timer? timer;
}
