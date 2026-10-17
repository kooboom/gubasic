import 'package:flutter/material.dart';

import 'form_model.dart';
import 'text_box.dart';

/// Shows a form: its inside area (`Width` x `Height` logical pixels) with
/// each control at `Left`, `Top`, sized `Width` x `Height`
/// (docs/LANGUAGE.md §11.1). The form's `Caption` is the window's title,
/// which the app around it shows.
class GbFormView extends StatelessWidget {
  const GbFormView({super.key, required this.model});

  final GbFormModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: model.form,
    builder: (context, _) => SizedBox(
      width: model.form.integer('Width').toDouble(),
      height: model.form.integer('Height').toDouble(),
      child: Stack(
        clipBehavior: Clip.hardEdge,
        children: [for (final c in model.controls) _GbPlaced(model, c)],
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
      GbControlKind.form => throw ArgumentError('a form inside a form'),
    },
  );
}

/// A Button: shows `Caption`; a click raises `Click`. It takes the focus
/// when clicked, as buttons do on desktops. Its text has
/// [gbButtonPadding] on each side: the Material default, 24, left a
/// Button of the default width (96) too little room for its own name.
/// The room between a Button's edge and its text, left and right.
const gbButtonPadding = 8.0;

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
