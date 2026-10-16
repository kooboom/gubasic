import 'package:flutter/material.dart';

/// The font the IDE uses on every platform, bundled with it (D30): a form
/// drawn on one platform looks the same on the others.
const ideFontFamily = 'NotoSansKR';

final ideTheme = ThemeData(
  colorSchemeSeed: Colors.indigo,
  fontFamily: ideFontFamily,
);

/// The code view and the output: monospace, Hangul from [ideFontFamily].
const codeStyle = TextStyle(
  fontFamily: 'monospace',
  fontFamilyFallback: [ideFontFamily],
);
