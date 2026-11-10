import 'package:flutter/services.dart';

/// The number of the key [event] is about, as a program's Keys names it
/// (docs/DESIGN.md D101), or null for a key the program does not tell
/// apart. Shift, Control and Alt are told as 16, 17 and 18 (`Keys.ShiftKey`,
/// `Keys.ControlKey`, `Keys.Menu`), which raise no event of their own but
/// which `Keyboard.IsDown` knows (D138). The numbers are the Windows
/// virtual-key codes, as Visual Basic .NET's Keys are. Letters, digits and
/// the punctuation keys are read by where they are on the keyboard (on
/// the web the browser's `event.code`), so that an input method (Korean)
/// does not change them (D138, D139).
int? gbKeyCode(KeyEvent event) {
  final physical = event.physicalKey;
  final letter = _letters.indexOf(physical);
  if (letter >= 0) return 65 + letter;
  final digit = _digits.indexOf(physical);
  if (digit >= 0) return 48 + digit;
  final pad = _numPad.indexOf(physical);
  if (pad >= 0) return 96 + pad;
  final punctuation = _punctuation[physical];
  if (punctuation != null) return punctuation;
  final key = event.logicalKey;
  final f = _functionKeys.indexOf(key);
  if (f >= 0) return 112 + f;
  return _others[key];
}

final _letters = [
  PhysicalKeyboardKey.keyA,
  PhysicalKeyboardKey.keyB,
  PhysicalKeyboardKey.keyC,
  PhysicalKeyboardKey.keyD,
  PhysicalKeyboardKey.keyE,
  PhysicalKeyboardKey.keyF,
  PhysicalKeyboardKey.keyG,
  PhysicalKeyboardKey.keyH,
  PhysicalKeyboardKey.keyI,
  PhysicalKeyboardKey.keyJ,
  PhysicalKeyboardKey.keyK,
  PhysicalKeyboardKey.keyL,
  PhysicalKeyboardKey.keyM,
  PhysicalKeyboardKey.keyN,
  PhysicalKeyboardKey.keyO,
  PhysicalKeyboardKey.keyP,
  PhysicalKeyboardKey.keyQ,
  PhysicalKeyboardKey.keyR,
  PhysicalKeyboardKey.keyS,
  PhysicalKeyboardKey.keyT,
  PhysicalKeyboardKey.keyU,
  PhysicalKeyboardKey.keyV,
  PhysicalKeyboardKey.keyW,
  PhysicalKeyboardKey.keyX,
  PhysicalKeyboardKey.keyY,
  PhysicalKeyboardKey.keyZ,
];

final _digits = [
  PhysicalKeyboardKey.digit0,
  PhysicalKeyboardKey.digit1,
  PhysicalKeyboardKey.digit2,
  PhysicalKeyboardKey.digit3,
  PhysicalKeyboardKey.digit4,
  PhysicalKeyboardKey.digit5,
  PhysicalKeyboardKey.digit6,
  PhysicalKeyboardKey.digit7,
  PhysicalKeyboardKey.digit8,
  PhysicalKeyboardKey.digit9,
];

final _numPad = [
  PhysicalKeyboardKey.numpad0,
  PhysicalKeyboardKey.numpad1,
  PhysicalKeyboardKey.numpad2,
  PhysicalKeyboardKey.numpad3,
  PhysicalKeyboardKey.numpad4,
  PhysicalKeyboardKey.numpad5,
  PhysicalKeyboardKey.numpad6,
  PhysicalKeyboardKey.numpad7,
  PhysicalKeyboardKey.numpad8,
  PhysicalKeyboardKey.numpad9,
];

final _functionKeys = [
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
];

final _others = {
  LogicalKeyboardKey.backspace: 8,
  LogicalKeyboardKey.tab: 9,
  LogicalKeyboardKey.enter: 13,
  LogicalKeyboardKey.shiftLeft: 16,
  LogicalKeyboardKey.shiftRight: 16,
  LogicalKeyboardKey.controlLeft: 17,
  LogicalKeyboardKey.controlRight: 17,
  LogicalKeyboardKey.altLeft: 18,
  LogicalKeyboardKey.altRight: 18,
  LogicalKeyboardKey.numpadEnter: 13,
  LogicalKeyboardKey.escape: 27,
  LogicalKeyboardKey.space: 32,
  LogicalKeyboardKey.pageUp: 33,
  LogicalKeyboardKey.pageDown: 34,
  LogicalKeyboardKey.end: 35,
  LogicalKeyboardKey.home: 36,
  LogicalKeyboardKey.arrowLeft: 37,
  LogicalKeyboardKey.arrowUp: 38,
  LogicalKeyboardKey.arrowRight: 39,
  LogicalKeyboardKey.arrowDown: 40,
  LogicalKeyboardKey.insert: 45,
  LogicalKeyboardKey.delete: 46,
};

/// The punctuation keys by their place, with .NET's Keys numbers (D139):
/// `Keys.OemPeriod` is 190.
final _punctuation = {
  PhysicalKeyboardKey.semicolon: 186,
  PhysicalKeyboardKey.equal: 187,
  PhysicalKeyboardKey.comma: 188,
  PhysicalKeyboardKey.minus: 189,
  PhysicalKeyboardKey.period: 190,
  PhysicalKeyboardKey.slash: 191,
  PhysicalKeyboardKey.backquote: 192,
  PhysicalKeyboardKey.bracketLeft: 219,
  PhysicalKeyboardKey.backslash: 220,
  PhysicalKeyboardKey.bracketRight: 221,
  PhysicalKeyboardKey.quote: 222,
};
