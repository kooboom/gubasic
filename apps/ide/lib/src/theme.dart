import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code/code_font.dart';

/// The font the IDE uses on every platform, bundled with it (D30): a form
/// drawn on one platform looks the same on the others.
const ideFontFamily = 'NotoSansKR';

/// Noto Sans KR Bold, used only for the handlers that exist in the code
/// editor's Event list (D38). It is an asset, loaded after the first
/// frame, so that the IDE's first visit on the web does not wait for its
/// 4.8 MB (D30); until then that text is drawn from Regular.
abstract final class BoldFont {
  static const asset = 'fonts/NotoSansKR-Bold.otf';

  /// Adds Bold to [ideFontFamily]. A failure (no network on the web)
  /// keeps Regular.
  static Future<void> load() async {
    try {
      await (FontLoader(ideFontFamily)..addFont(rootBundle.load(asset))).load();
    } catch (_) {}
  }
}

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
