import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import '../strings.dart';
import 'control_icons.dart';
import 'form_edit.dart';

/// The designer's toolbox: the pointer, then a tool for each control
/// type, as icons in two columns like Visual Basic 6's toolbox, each the
/// control drawn small; a tool's name is its tooltip (D107). Choosing a
/// tool lets
/// the user draw that control on the form; a double-click places one in
/// the middle of the form at once, and a tool dragged onto the form
/// places one where it is dropped (D69).
class Toolbox extends StatelessWidget {
  const Toolbox({
    super.key,
    required this.tool,
    required this.enabled,
    required this.strings,
    required this.onChoose,
    required this.onPlace,
  });

  /// The chosen control type; null for the pointer.
  final ComponentSpec? tool;

  /// Whether controls can be placed; the pointer always works.
  final bool enabled;
  final IdeStrings strings;
  final void Function(ComponentSpec? tool) onChoose;
  final void Function(ComponentSpec type) onPlace;

  /// The tools in a row, and a tool's cell.
  static const columns = 2;
  static const cellWidth = 36.0;
  static const cellHeight = 36.0;
  static const _padding = 6.0;

  /// The toolbox's width: the columns and the padding at both sides.
  static const width = columns * cellWidth + 2 * _padding;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: width,
    child: SingleChildScrollView(
      padding: const EdgeInsets.all(_padding),
      child: Wrap(
        children: [
          _item(
            context,
            key: const ValueKey('toolbox.pointer'),
            icon: 'pointer',
            label: strings.pointerTool,
            selected: tool == null,
            enabled: true,
            onPress: () => onChoose(null),
          ),
          for (final type in toolboxComponents)
            _item(
              context,
              key: ValueKey('toolbox.${type.name}'),
              icon: type.name.toLowerCase(),
              label: type.name,
              selected: tool == type,
              enabled: enabled,
              onPress: () => onChoose(type),
              onDoubleTap: () => onPlace(type),
              type: type,
            ),
        ],
      ),
    ),
  );

  Widget _item(
    BuildContext context, {
    required Key key,
    required String icon,
    required String label,
    required bool selected,
    required bool enabled,
    required VoidCallback onPress,
    VoidCallback? onDoubleTap,
    ComponentSpec? type,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final item = Container(
      width: cellWidth,
      height: cellHeight,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected && enabled ? scheme.secondaryContainer : null,
        borderRadius: BorderRadius.circular(4),
      ),
      child: ControlIcon(icon, size: 22, enabled: enabled),
    );
    return Tooltip(
      // The toolbox shows only the icon: its name is here.
      message: label,
      waitDuration: const Duration(milliseconds: 600),
      // The tool is chosen as the button goes down: a tap would wait to
      // see whether a double-click follows, and a drag on the form begun
      // in that time drew nothing.
      child: Listener(
        key: key,
        behavior: HitTestBehavior.opaque,
        onPointerDown: (e) {
          if (enabled && e.buttons & kPrimaryButton != 0) onPress();
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: enabled ? onDoubleTap : null,
          child: type == null
              ? item
              : Draggable<ComponentSpec>(
                  data: type,
                  maxSimultaneousDrags: enabled ? 1 : 0,
                  dragAnchorStrategy: pointerDragAnchorStrategy,
                  feedback: _DragFeedback(icon: icon, label: label),
                  child: item,
                ),
        ),
      ),
    );
  }
}

/// What follows the pointer while a tool is dragged onto the form: the
/// tool, its top left corner where the control will go.
class _DragFeedback extends StatelessWidget {
  const _DragFeedback({required this.icon, required this.label});

  final String icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return IgnorePointer(
      child: Material(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(4),
        elevation: 2,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ControlIcon(icon, size: 18),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: scheme.onSecondaryContainer)),
            ],
          ),
        ),
      ),
    );
  }
}
