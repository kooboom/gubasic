import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// The code editor's font, D2Coding 1.3.2 Regular (OFL): monospaced, with
/// Hangul exactly twice as wide as Latin letters. It is an asset, loaded
/// the first time the code editor opens, so that the IDE's first visit on
/// the web does not wait for it (D36); until then code shows in the
/// IDE's font.
abstract final class CodeFont {
  static const family = 'D2Coding';
  static const asset = 'fonts/d2coding/D2Coding-Ver1.3.2-20180524.ttf';

  /// Whether the font is loaded and can be used.
  static final loaded = ValueNotifier(false);

  static Future<void>? _loading;

  /// Forgets the font, as on a fresh start.
  @visibleForTesting
  static void reset() {
    _loading = null;
    loaded.value = false;
  }

  /// Loads the font once. A failure (no network on the web) keeps the
  /// IDE's font and lets the next code editor try again.
  static Future<void> load() => _loading ??= () async {
    try {
      await (FontLoader(family)..addFont(rootBundle.load(asset))).load();
      loaded.value = true;
    } catch (_) {
      _loading = null;
    }
  }();
}
