import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'code/code_font.dart';

/// The font the IDE uses on every platform, bundled with it (D30): a form
/// drawn on one platform looks the same on the others.
const ideFontFamily = 'Pretendard';

/// Pretendard's character variant 5, the lowercase l with a tail, so that
/// `lblName` and `lstCity` do not read as `IblName` and `IstCity` (D49).
const ideFontFeatures = [FontFeature('cv05')];

/// Pretendard Bold, used only for the handlers that exist in the code
/// editor's Event list (D38). It is an asset, loaded after the first
/// frame, so that the IDE's first visit on the web does not wait for it
/// (D30); until then that text is drawn from Regular.
abstract final class BoldFont {
  static const asset = 'fonts/pretendard/Pretendard-Bold.otf';

  /// Adds Bold to [ideFontFamily]. A failure (no network on the web)
  /// keeps Regular.
  static Future<void> load() async {
    try {
      await (FontLoader(ideFontFamily)..addFont(rootBundle.load(asset))).load();
    } catch (_) {}
  }
}

/// A calm, dense desktop tool, like Visual Basic 6, Xcode or VS Code
/// (D49): 13 px text (12 px in lists and the Properties window), normal
/// weight, compact density, corners of 4 px at most, greys with a blue
/// accent.
final ideTheme = _ideTheme();

ThemeData _ideTheme() {
  const radius = BorderRadius.all(Radius.circular(4));
  const shape = RoundedRectangleBorder(borderRadius: radius);
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF3B6EA5),
    dynamicSchemeVariant: DynamicSchemeVariant.neutral,
  );
  final base = ThemeData(
    colorScheme: scheme,
    fontFamily: ideFontFamily,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  // Sizes and weight only: the colours stay the theme's own.
  TextStyle t(double size, {TextStyle? from}) =>
      (from ?? const TextStyle()).copyWith(
        fontFamily: ideFontFamily,
        fontFeatures: ideFontFeatures,
        fontSize: size,
        fontWeight: FontWeight.w400,
        height: 1.35,
        letterSpacing: 0,
      );
  final buttonText = WidgetStatePropertyAll(t(13));
  const buttonShape = WidgetStatePropertyAll(shape);
  const buttonPadding = WidgetStatePropertyAll(
    EdgeInsets.symmetric(horizontal: 10, vertical: 4),
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      displayLarge: t(22, from: base.textTheme.displayLarge),
      displayMedium: t(20, from: base.textTheme.displayMedium),
      displaySmall: t(18, from: base.textTheme.displaySmall),
      headlineLarge: t(18, from: base.textTheme.headlineLarge),
      headlineMedium: t(16, from: base.textTheme.headlineMedium),
      headlineSmall: t(15, from: base.textTheme.headlineSmall),
      titleLarge: t(15, from: base.textTheme.titleLarge),
      titleMedium: t(13, from: base.textTheme.titleMedium),
      titleSmall: t(13, from: base.textTheme.titleSmall),
      bodyLarge: t(12, from: base.textTheme.bodyLarge),
      bodyMedium: t(12, from: base.textTheme.bodyMedium),
      bodySmall: t(12, from: base.textTheme.bodySmall),
      labelLarge: t(13, from: base.textTheme.labelLarge),
      labelMedium: t(12, from: base.textTheme.labelMedium),
      labelSmall: t(11, from: base.textTheme.labelSmall),
    ),
    dividerTheme: DividerThemeData(
      color: scheme.outlineVariant,
      space: 1,
      thickness: 1,
    ),
    listTileTheme: const ListTileThemeData(
      dense: true,
      visualDensity: VisualDensity(horizontal: -4, vertical: -4),
      minVerticalPadding: 0,
      minTileHeight: 26,
      contentPadding: EdgeInsets.symmetric(horizontal: 10),
      shape: shape,
    ),
    inputDecorationTheme: const InputDecorationTheme(
      isDense: true,
      contentPadding: EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      border: OutlineInputBorder(borderRadius: radius),
    ),
    textButtonTheme: TextButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        padding: buttonPadding,
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        padding: buttonPadding,
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(
        shape: buttonShape,
        textStyle: buttonText,
        padding: buttonPadding,
      ),
    ),
    iconButtonTheme: const IconButtonThemeData(
      style: ButtonStyle(shape: buttonShape),
    ),
    menuTheme: const MenuThemeData(
      style: MenuStyle(shape: WidgetStatePropertyAll(shape)),
    ),
    menuButtonTheme: MenuButtonThemeData(
      style: ButtonStyle(
        textStyle: buttonText,
        minimumSize: const WidgetStatePropertyAll(Size(0, 28)),
      ),
    ),
    dialogTheme: const DialogThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(6)),
      ),
    ),
    snackBarTheme: const SnackBarThemeData(
      shape: shape,
      behavior: SnackBarBehavior.floating,
    ),
    tooltipTheme: const TooltipThemeData(
      decoration: BoxDecoration(color: Color(0xE6303030), borderRadius: radius),
    ),
    iconTheme: const IconThemeData(size: 18),
    chipTheme: ChipThemeData(
      shape: shape,
      labelStyle: t(12, from: base.textTheme.labelLarge),
      labelPadding: const EdgeInsets.symmetric(horizontal: 4),
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
    ),
  );
}

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
