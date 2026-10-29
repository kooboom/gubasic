/// The keys a program can tell apart in KeyDown and KeyUp
/// (docs/DESIGN.md D101), by name, with their numbers: `Keys.Left` is 37.
/// The names and numbers are Visual Basic .NET's `Keys`, which are the
/// Windows virtual-key codes, so code written for it compares the same.
/// Shift, Control and Alt are not keys of their own here: they are held
/// with another key, as `e.Shift`, `e.Control` and `e.Alt` say.
final Map<String, int> keyCodes = {
  'Back': 8,
  'Tab': 9,
  'Enter': 13,
  'Escape': 27,
  'Space': 32,
  'PageUp': 33,
  'PageDown': 34,
  'End': 35,
  'Home': 36,
  'Left': 37,
  'Up': 38,
  'Right': 39,
  'Down': 40,
  'Insert': 45,
  'Delete': 46,
  for (var d = 0; d <= 9; d++) 'D$d': 48 + d,
  for (var c = 0; c < 26; c++) String.fromCharCode(65 + c): 65 + c,
  for (var d = 0; d <= 9; d++) 'NumPad$d': 96 + d,
  for (var f = 1; f <= 12; f++) 'F$f': 111 + f,
};

/// The answers a dialog form gives (docs/DESIGN.md D103), by name, with
/// Visual Basic .NET's numbers: `DialogResult.OK` is 1.
/// The mouse's buttons MouseDown and MouseUp tell apart (docs/DESIGN.md
/// D111), by name, with Visual Basic .NET's numbers: `MouseButtons.Left`
/// is 1048576. On a touch screen a press is Left, and a long press Right.
const Map<String, int> mouseButtons = {
  'Left': 1048576,
  'Right': 2097152,
  'Middle': 4194304,
};

const Map<String, int> dialogResults = {
  'None': 0,
  'OK': 1,
  'Cancel': 2,
  'Yes': 6,
  'No': 7,
};

/// [keyCodes] by lower-case name.
final Map<String, (String, int)> keyCodesByLowerName = {
  for (final MapEntry(:key, :value) in keyCodes.entries)
    key.toLowerCase(): (key, value),
};
