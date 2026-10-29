import 'package:flutter/material.dart';

import 'form_model.dart';

/// An OptionButton: a round box with `Caption` beside it, one of the
/// group of choices of its form, or of its Frame (docs/DESIGN.md D104,
/// D105). A click on a box that is
/// not checked checks it, unchecks the others of the group and raises
/// `Changed`; on the checked one it does nothing. As before a Button's
/// Click, text still being composed in a TextBox is committed first. A
/// click the program would ignore, because its Changed is still running,
/// changes nothing.
class GbOptionButton extends StatelessWidget {
  const GbOptionButton({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  void _click() {
    model.commitComposing();
    if (state['Checked'] == true) return;
    if (!model.takes(state.name, 'Changed')) return;
    for (final other in model.controls) {
      if (other.kind == GbControlKind.optionButton &&
          other != state &&
          other.container?.toLowerCase() == state.container?.toLowerCase()) {
        other.set('Checked', false);
      }
    }
    state.set('Checked', true);
    model.raise(state.name, 'Changed');
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _click,
      child: Row(
        children: [
          Radio<bool>(
            value: true,
            // ignore: deprecated_member_use
            groupValue: state['Checked'] as bool,
            // ignore: deprecated_member_use
            onChanged: (_) => _click(),
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            visualDensity: VisualDensity.compact,
          ),
          Expanded(
            child: Text(
              state.text('Caption'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    ),
  );
}
