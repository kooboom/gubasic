import 'package:flutter/material.dart';

import 'form_model.dart';

/// A CheckBox: a box with `Caption` beside it. A click on either changes
/// `Checked` and raises `Changed` (docs/DESIGN.md D44). As before a
/// Button's Click, text still being composed in a TextBox is committed
/// first. A click the program would ignore, because the CheckBox's own
/// Changed is still running, changes nothing. When the program sets
/// `Checked`, no event is raised here: the interpreter runs Changed itself.
class GbCheckBox extends StatelessWidget {
  const GbCheckBox({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  void _click() {
    model.commitComposing();
    if (!model.accepts(state.name, 'Changed')) return;
    state.set('Checked', !(state['Checked'] as bool));
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
          Checkbox(
            value: state['Checked'] as bool,
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
