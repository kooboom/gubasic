import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import '../strings.dart';
import 'form_edit.dart';

/// The designer's toolbox: the pointer, then a tool for each control
/// type. Choosing a tool lets the user draw that control on the form; a
/// double-click places one in the middle of the form at once.
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

  static IconData _icon(String type) => switch (type.toLowerCase()) {
    'button' => Icons.smart_button_outlined,
    'label' => Icons.title,
    'textbox' => Icons.text_fields,
    'checkbox' => Icons.check_box_outlined,
    'listbox' => Icons.list_alt,
    'image' => Icons.image_outlined,
    _ => Icons.widgets_outlined,
  };

  @override
  Widget build(BuildContext context) => SizedBox(
    width: 128,
    child: ListView(
      padding: const EdgeInsets.symmetric(vertical: 8),
      children: [
        _item(
          context,
          key: const ValueKey('toolbox.pointer'),
          icon: Icons.north_west,
          label: strings.pointerTool,
          tip: strings.pointerTip,
          selected: tool == null,
          enabled: true,
          onTapDown: () => onChoose(null),
        ),
        for (final type in toolboxComponents)
          _item(
            context,
            key: ValueKey('toolbox.${type.name}'),
            icon: _icon(type.name),
            label: type.name,
            tip: strings.placeTip.replaceAll('{0}', type.name),
            selected: tool == type,
            enabled: enabled,
            onTapDown: () => onChoose(type),
            onDoubleTap: () => onPlace(type),
          ),
      ],
    ),
  );

  Widget _item(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String label,
    required String tip,
    required bool selected,
    required bool enabled,
    required VoidCallback onTapDown,
    VoidCallback? onDoubleTap,
  }) {
    final scheme = Theme.of(context).colorScheme;
    final color = enabled
        ? (selected ? scheme.onSecondaryContainer : scheme.onSurface)
        : scheme.onSurface.withValues(alpha: 0.38);
    return Tooltip(
      message: tip,
      waitDuration: const Duration(milliseconds: 600),
      child: GestureDetector(
        key: key,
        behavior: HitTestBehavior.opaque,
        // The tool is chosen as the button goes down, without waiting to
        // see whether a double-click follows.
        onTapDown: enabled ? (_) => onTapDown() : null,
        onDoubleTap: enabled ? onDoubleTap : null,
        child: Container(
          height: 26,
          margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 1),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          decoration: BoxDecoration(
            color: selected && enabled ? scheme.secondaryContainer : null,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
