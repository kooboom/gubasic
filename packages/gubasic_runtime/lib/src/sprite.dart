import 'package:flutter/material.dart';

import 'form_model.dart';
import 'image.dart';

/// A Sprite (docs/DESIGN.md D138): the frame `Frame` of the project's
/// pictures named in `Frames`, drawn filling the control, as an Image with
/// `Stretch` is; what is behind shows through its transparent pixels. With
/// no frames it is empty on a running form, and outlined with its name in
/// the designer. Like an Image, it takes clicks over its whole area.
class GbSprite extends StatelessWidget {
  const GbSprite({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: state,
    builder: (context, _) {
      final frames = gbFrameNames(state.text('Frames'));
      final index = state.integer('Frame');
      final name = index >= 0 && index < frames.length ? frames[index] : '';
      final bytes = name.isEmpty ? null : model.pictures(name);
      return GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => model.raise(state.name, 'Click'),
        child: bytes != null
            ? Image.memory(
                bytes,
                fit: BoxFit.fill,
                // The next frame replaces the last without a blank frame.
                gaplessPlayback: true,
                errorBuilder: (context, _, _) => GbMissingPicture(name: name),
              )
            : name.isNotEmpty
            ? GbMissingPicture(name: name)
            : model.designing
            ? GbMissingPicture(name: state.name ?? '', empty: true)
            : const SizedBox.expand(),
      );
    },
  );
}

/// The names in a Sprite's `Frames`: separated by commas, each trimmed,
/// as the language reads them (D138).
List<String> gbFrameNames(String frames) => [
  for (final name in frames.split(','))
    if (name.trim().isNotEmpty) name.trim(),
];
