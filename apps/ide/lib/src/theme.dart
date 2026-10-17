import 'package:flutter/material.dart';

import 'code/code_font.dart';

/// The font the IDE uses on every platform, bundled with it (D30): a form
/// drawn on one platform looks the same on the others.
const ideFontFamily = 'NotoSansKR';

final ideTheme = ThemeData(
  colorSchemeSeed: Colors.indigo,
  fontFamily: ideFontFamily,
);

/// Code, the code views and the output: D2Coding once it is loaded
/// ([CodeFont]), until then `monospace` with Hangul from [ideFontFamily].
TextStyle get codeStyle => CodeFont.loaded.value
    ? const TextStyle(
        fontFamily: CodeFont.family,
        fontFamilyFallback: [ideFontFamily],
      )
    : const TextStyle(
        fontFamily: 'monospace',
        fontFamilyFallback: [ideFontFamily],
      );
