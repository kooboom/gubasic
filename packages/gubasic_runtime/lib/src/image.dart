import 'package:flutter/material.dart';

import 'form_model.dart';

/// An Image (docs/DESIGN.md D51): the project's picture named by
/// `Picture`, the whole of it fitted inside keeping its proportions, or,
/// with `Stretch`, filling the control. With no picture it is empty on a
/// running form, and outlined with its name in the designer. Like a Label,
/// it takes clicks over its whole area, picture or not.
class GbImage extends StatelessWidget {
  const GbImage({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final name = state.text('Picture');
      final bytes = name.isEmpty ? null : model.pictures(name);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => model.raise(state.name, 'Click'),
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: state['Stretch'] == true ? BoxFit.fill : BoxFit.contain,
                // A new picture replaces the old one without a blank frame.
                gaplessPlayback: true,
                errorBuilder: (context, _, _) => _Missing(name: name),
              )
            : name.isNotEmpty
            ? _Missing(name: name)
            : model.designing
            ? _Missing(name: state.name ?? '', empty: true)
            : const SizedBox.expand(),
      );
    },
  );
}

/// What stands for a picture that cannot be shown: an outline with an
/// icon and [name]; [empty] when no picture is chosen yet.
class _Missing extends StatelessWidget {
  const _Missing({required this.name, this.empty = false});

  final String name;
  final bool empty;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(border: Border.all(color: scheme.outline)),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              empty ? Icons.image_outlined : Icons.broken_image_outlined,
              color: scheme.outline,
            ),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: scheme.outline),
            ),
          ],
        ),
      ),
    );
  }
}
