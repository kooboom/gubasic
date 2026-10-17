import 'package:flutter/material.dart';

import 'composing.dart';
import 'form_model.dart';

/// The characters of [value] the input method has committed: its text
/// without the part still being composed. Typing 갈가 in Korean shows 갈,
/// then 갉, then 갈가; 갈 is committed only when ㅏ is typed
/// (docs/LANGUAGE.md §11.1).
String committedText(TextEditingValue value) {
  final c = value.composing;
  if (!c.isValid || c.isCollapsed || c.end > value.text.length) {
    return value.text;
  }
  return value.text.replaceRange(c.start, c.end, '');
}

/// A TextBox. Its `Text` property holds only committed characters, and
/// `Changed` is raised each time the user changes them. When the program
/// sets `Text`, no event is raised here: the interpreter runs Changed itself.
class GbTextBox extends StatefulWidget {
  const GbTextBox({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  @override
  State<GbTextBox> createState() => _GbTextBoxState();
}

class _GbTextBoxState extends State<GbTextBox> {
  late final _controller = TextEditingController(text: _committed);
  late String _committed = widget.state.text('Text');
  late final _tracker = ComposingTracker(_controller.value);
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller.addListener(_userEdited);
    widget.state.addListener(_programSet);
    widget.model.addCommitter(_commitComposing);
    // Where the platform does not commit as the field loses the focus
    // ([mayLeaveOutComposing]), the field does.
    _focus.addListener(() {
      if (!_focus.hasFocus) _commitComposing();
    });
  }

  @override
  void dispose() {
    widget.model.removeCommitter(_commitComposing);
    widget.state.removeListener(_programSet);
    _focus.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _userEdited() {
    _tracker.track(_controller.value);
    _changed();
  }

  void _changed() {
    final text = committedText(_tracker.value);
    if (text == _committed) return;
    _committed = text;
    widget.state.set('Text', text);
    widget.model.raise(widget.state.name, 'Changed');
  }

  void _programSet() {
    final text = widget.state.text('Text');
    if (text == _committed) return;
    _committed = text;
    _controller.value = TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
    );
  }

  /// Takes the characters being composed as committed (before a click).
  void _commitComposing() {
    final value = _controller.value;
    if (value.composing.isValid && !value.composing.isCollapsed) {
      _controller.value = value.copyWith(composing: TextRange.empty);
    } else if (_tracker.composing) {
      _tracker.commit();
      _changed();
    }
  }

  @override
  Widget build(BuildContext context) => TextField(
    controller: _controller,
    focusNode: _focus,
    decoration: const InputDecoration(
      border: OutlineInputBorder(),
      isDense: true,
    ),
  );
}
