import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

/// A model of [form] as its file describes it, before any code has run:
/// what the run window starts from and what the designer shows, so that
/// both draw a form the same way (docs/DESIGN.md §2.3).
GbFormModel formModelOf(FormFile form, {required GbEventSink onEvent}) =>
    GbFormModel(
      form: {
        for (final p in form.component.properties.values)
          p.name: form.valueOf(p.name),
      },
      controls: [
        for (final c in form.controls)
          GbControlState(
            c.name,
            _kind(c.component.name),
            {
              for (final p in c.component.properties.values)
                p.name: c.valueOf(p.name),
            },
            layer: switch (c.component.layer) {
              ComponentLayer.graphic => GbLayer.graphic,
              ComponentLayer.control => GbLayer.control,
            },
          ),
      ],
      onEvent: onEvent,
    );

GbControlKind _kind(String component) => switch (component.toLowerCase()) {
  'button' => GbControlKind.button,
  'label' => GbControlKind.label,
  'textbox' => GbControlKind.textBox,
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
  });

  final String caption;
  final double width;
  final Widget? trailing;
  final Widget? child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: width,
      child: Material(
        elevation: 8,
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
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
                    child: Text(
                      caption,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall,
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
