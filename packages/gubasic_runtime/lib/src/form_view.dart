import 'package:flutter/material.dart';

import 'check_box.dart';
import 'form_model.dart';
import 'list_box.dart';
import 'text_box.dart';

/// Shows a form: its inside area (`Width` x `Height` logical pixels) with
/// each control at `Left`, `Top`, sized `Width` x `Height`
/// (docs/LANGUAGE.md §11.1). The form's `Caption` is the window's title,
/// which the app around it shows.
class GbFormView extends StatelessWidget {
  const GbFormView({super.key, required this.model});

  final GbFormModel model;

  @override
  Widget build(BuildContext context) => Theme(
    data: gbFormTheme(Theme.of(context)),
    child: Builder(builder: _form),
  );

  Widget _form(BuildContext context) => ListenableBuilder(
    listenable: model.form,
    builder: (context, _) => SizedBox(
      width: model.form.integer('Width').toDouble(),
      height: model.form.integer('Height').toDouble(),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [for (final c in model.drawingOrder) _GbPlaced(model, c)],
      ),
    ),
  );
}

class _GbPlaced extends StatelessWidget {
  const _GbPlaced(this.model, this.state);

  final GbFormModel model;
  final GbControlState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, child) => Positioned(
      left: state.integer('Left').toDouble(),
      top: state.integer('Top').toDouble(),
      width: state.integer('Width').toDouble(),
      height: state.integer('Height').toDouble(),
      child: child!,
    ),
    child: switch (state.kind) {
      GbControlKind.button => GbButton(model: model, state: state),
      GbControlKind.label => GbLabel(model: model, state: state),
      GbControlKind.textBox => GbTextBox(model: model, state: state),
      GbControlKind.checkBox => GbCheckBox(model: model, state: state),
      GbControlKind.listBox => GbListBox(model: model, state: state),
      GbControlKind.form => throw ArgumentError('a form inside a form'),
    },
  );
}

/// The corners of the controls on a form: square, as in Visual Basic 6
/// (docs/DESIGN.md D49).
const gbControlRadius = BorderRadius.all(Radius.circular(3));

/// The theme of a form's controls (D49): calm, square and dense, 13 px
/// text of normal weight, greys with a blue accent. It is the form's own,
/// apart from the app around it, so that a change of the IDE's look does
/// not change the forms students draw; only the font (family and features)
/// comes from [ambient], as the runtime does not choose fonts (§2.3).
ThemeData gbFormTheme(ThemeData ambient) {
  final font = ambient.textTheme.bodyMedium;
  final base = ThemeData(
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF3B6EA5),
      dynamicSchemeVariant: DynamicSchemeVariant.neutral,
    ),
    fontFamily: font?.fontFamily,
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );
  // Sizes and weight only: the colours stay the theme's own.
  TextStyle? text(TextStyle? from) => from?.copyWith(
    fontFamily: font?.fontFamily,
    fontFeatures: font?.fontFeatures,
    fontSize: 13,
    fontWeight: FontWeight.w400,
  );
  return base.copyWith(
    textTheme: base.textTheme.copyWith(
      bodyLarge: text(base.textTheme.bodyLarge),
      bodyMedium: text(base.textTheme.bodyMedium),
      labelLarge: text(base.textTheme.labelLarge),
    ),
    checkboxTheme: const CheckboxThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.all(Radius.circular(2)),
      ),
    ),
  );
}

/// A Button: shows `Caption`; a click raises `Click`. It takes the focus
/// when clicked, as buttons do on desktops. Its text has
/// [gbButtonPadding] on each side: the Material default, 24, left a
/// Button of the default width (96) too little room for its own name.
/// The room between a Button's edge and its text, left and right.
const gbButtonPadding = 8.0;

/// A Button's fill: opaque, as in Visual Basic 6, so that a Label under it
/// does not show through (docs/DESIGN.md D41). The theme's
/// `surfaceContainerHigh`, a shade darker than the form's `surface`.
Color gbButtonFace(ColorScheme scheme) => scheme.surfaceContainerHigh;

class GbButton extends StatefulWidget {
  const GbButton({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  @override
  State<GbButton> createState() => _GbButtonState();
}

class _GbButtonState extends State<GbButton> {
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: widget.state,
    builder: (context, _) => OutlinedButton(
      focusNode: _focus,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: gbButtonPadding),
        backgroundColor: gbButtonFace(Theme.of(context).colorScheme),
        // Dark text, as on an enabled button; a Button that cannot be
        // clicked (an Enabled property, later) keeps Material's grey.
        foregroundColor: Theme.of(context).colorScheme.onSurface,
        shape: const RoundedRectangleBorder(borderRadius: gbControlRadius),
        minimumSize: Size.zero,
      ),
      onPressed: () {
        _focus.requestFocus();
        widget.model.raise(widget.state.name, 'Click');
      },
      child: Text(
        widget.state.text('Caption'),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    ),
  );
}

/// A Label: shows `Caption`; a click raises `Click`.
class GbLabel extends StatelessWidget {
  const GbLabel({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => model.raise(state.name, 'Click'),
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(state.text('Caption')),
      ),
    ),
  );
}
