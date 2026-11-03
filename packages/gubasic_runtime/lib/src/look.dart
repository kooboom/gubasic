import 'package:flutter/material.dart';

import 'form_model.dart';

/// How a control looks and whether the user can use it (docs/DESIGN.md
/// D137): its text's size in logical pixels and weight, its colours, all
/// null where neither it, its Frames nor its form set them (the form's
/// theme then), and whether it and its Frames are Enabled and Visible.
class GbLook extends InheritedWidget {
  const GbLook({
    super.key,
    required super.child,
    this.fontSize,
    this.bold,
    this.fore,
    this.back,
    this.enabled = true,
  });

  /// [state]'s look on [model]: a property it does not have is its
  /// Frame's, then its form's. Colours are 0xAARRGGBB, FontSize points.
  factory GbLook.ofControl(
    GbFormModel model,
    GbControlState state, {
    required Widget child,
  }) {
    T? find<T>(String property) {
      GbControlState? at = state;
      for (var i = 0; at != null && i < 64; i++) {
        if (at.has(property) && at[property] is T) return at[property] as T;
        if (identical(at, model.form)) break;
        at = at.container == null ? model.form : model.control(at.container);
      }
      return null;
    }

    final points = find<double>('FontSize');
    final fore = find<int>('ForeColor');
    final back = state.has('BackColor') ? state['BackColor'] as int : null;
    return GbLook(
      fontSize: points == null ? null : points * 4 / 3,
      bold: find<bool>('FontBold'),
      fore: fore == null ? null : Color(fore),
      back: back == null ? null : Color(back),
      enabled: gbUsable(model, state, 'Enabled'),
      child: child,
    );
  }

  final double? fontSize;
  final bool? bold;
  final Color? fore;

  /// The control's own background; a Frame's or the form's is drawn
  /// behind it already.
  final Color? back;
  final bool enabled;

  /// The look of the control being built, if one is placed above.
  static GbLook? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GbLook>();

  /// [style] in this look.
  TextStyle? style(TextStyle? style) => style?.copyWith(
    fontSize: fontSize,
    fontWeight: bold == null
        ? null
        : (bold! ? FontWeight.w700 : FontWeight.w400),
    color: fore,
  );

  /// [child] drawn in this look: the theme's text in its size, weight and
  /// colour, on its background.
  Widget apply(BuildContext context, Widget child) {
    if (fontSize == null && bold == null && fore == null && back == null) {
      return child;
    }
    final theme = Theme.of(context);
    final text = theme.textTheme;
    Widget body = Theme(
      data: theme.copyWith(
        textTheme: text.copyWith(
          bodyLarge: style(text.bodyLarge),
          bodyMedium: style(text.bodyMedium),
          labelLarge: style(text.labelLarge),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: style(const TextStyle()),
        child: child,
      ),
    );
    if (back != null) body = ColoredBox(color: back!, child: body);
    return body;
  }

  @override
  bool updateShouldNotify(GbLook old) =>
      old.fontSize != fontSize ||
      old.bold != bold ||
      old.fore != fore ||
      old.back != back ||
      old.enabled != enabled;
}

/// Whether [state] and every Frame it is in have [property] (`Enabled`,
/// `Visible`) True (D137); one without it counts as True.
bool gbUsable(GbFormModel model, GbControlState state, String property) {
  GbControlState? at = state;
  for (var i = 0; at != null && i < 64; i++) {
    if (at.has(property) && at[property] == false) return false;
    if (at.container == null) break;
    at = model.control(at.container);
  }
  return true;
}
