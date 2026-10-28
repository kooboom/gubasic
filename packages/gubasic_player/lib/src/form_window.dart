import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A model of [form] as its file describes it, before any code has run:
/// what the run window starts from and what the designer shows, so that
/// both draw a form the same way (docs/DESIGN.md §2.3).
GbFormModel formModelOf(
  FormFile form, {
  required GbEventSink onEvent,
  GbEventFilter? accepts,
  bool designing = false,
  GbPictureSource? pictures,
  GbKeySink? onKey,
}) => GbFormModel(
  form: {
    for (final p in form.component.properties.values)
      p.name: form.valueOf(p.name),
  },
  controls: [
    // A Timer is not seen on the form (D100); the menu items are drawn in
    // the menu bar (D106).
    for (final c in form.controls.where(
      (c) => c.component.visual || c.component.menu,
    ))
      controlStateOf(c.name, c.component, {
        for (final p in c.component.properties.values)
          if (p.isStored) p.name: c.valueOf(p.name),
      }, container: c.container),
  ],
  onEvent: onEvent,
  accepts: accepts,
  designing: designing,
  pictures: pictures,
  onKey: onKey,
);

/// The state of control [name], a [component], with [properties]: one of a
/// form file, in the Frame named [container] if it is in one (D105), or one
/// the program made with New (docs/DESIGN.md D98).
GbControlState controlStateOf(
  String name,
  ComponentSpec component,
  Map<String, Object> properties, {
  String? container,
}) => GbControlState(
  name,
  _kind(component.name),
  properties,
  container: container,
  layer: switch (component.layer) {
    ComponentLayer.graphic => GbLayer.graphic,
    ComponentLayer.control => GbLayer.control,
  },
);

GbControlKind _kind(String component) => switch (component.toLowerCase()) {
  'button' => GbControlKind.button,
  'label' => GbControlKind.label,
  'textbox' => GbControlKind.textBox,
  'checkbox' => GbControlKind.checkBox,
  'listbox' => GbControlKind.listBox,
  'image' => GbControlKind.image,
  'optionbutton' => GbControlKind.optionButton,
  'combobox' => GbControlKind.comboBox,
  'frame' => GbControlKind.frame,
  'menu' => GbControlKind.menu,
  _ => throw ArgumentError('no widget for component $component'),
};

/// The height of a form window's title bar.
const formTitleHeight = 36.0;

/// A form's window: a title bar with [caption] and [trailing], then
/// [child], [width] wide. The run window and the designer both use it.
class FormWindowFrame extends StatelessWidget {
  const FormWindowFrame({
    super.key,
    required this.caption,
    required this.width,
    this.trailing,
    this.child,
    this.onTitleDoubleTap,
  });

  final String caption;
  final double width;
  final Widget? trailing;
  final Widget? child;

  /// A double-click on the title bar: the run window puts the form back
  /// at the size it was drawn.
  final VoidCallback? onTitleDoubleTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(4),
        clipBehavior: Clip.antiAlias,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: formTitleHeight,
              color: theme.colorScheme.surfaceContainerHighest,
              padding: const EdgeInsets.only(left: 12),
              child: Row(
                children: [
                  Expanded(
                    // Only the caption takes a double-click: over the
                    // close button it would hold back its click.
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onDoubleTap: onTitleDoubleTap,
                      child: SizedBox(
                        height: formTitleHeight,
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            caption,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.titleSmall,
                          ),
                        ),
                      ),
                    ),
                  ),
                  ?trailing,
                ],
              ),
            ),
            ?child,
          ],
        ),
      ),
    );
  }
}
