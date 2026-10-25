/// A control's place on its form: `Left`, `Top`, `Width`, `Height`.
typedef GbRect = ({int left, int top, int width, int height});

/// Where a control with `Anchor` [anchor] goes when its form becomes
/// [width] x [height], having been at [base] when the form was
/// [baseWidth] x [baseHeight] (docs/DESIGN.md D57). [anchor] names edges
/// as the language keeps them: `Left Top Right Bottom`, or "" for none.
///
/// For each direction: anchored to both edges, the control stretches; to
/// one, it keeps its distance to that edge; to neither, it moves half as
/// much as the form grows (rounded down), staying as near the middle. Its
/// size never goes below 0. Worked out from [base] each time, never from
/// the last place, so that a form made larger and then as it was puts
/// every control back exactly.
///
/// gubasic_lang works it out the same way for its tests (`anchoredRect`);
/// the parity programs check that both agree.
GbRect gbAnchored(
  GbRect base,
  String anchor, {
  required int baseWidth,
  required int baseHeight,
  required int width,
  required int height,
}) {
  final words = anchor.split(' ');
  final (left, w) = _axis(
    base.left,
    base.width,
    width - baseWidth,
    words.contains('Left'),
    words.contains('Right'),
  );
  final (top, h) = _axis(
    base.top,
    base.height,
    height - baseHeight,
    words.contains('Top'),
    words.contains('Bottom'),
  );
  return (left: left, top: top, width: w, height: h);
}

(int, int) _axis(int start, int size, int grown, bool near, bool far) {
  if (near && far) return (start, size + grown < 0 ? 0 : size + grown);
  if (far) return (start + grown, size);
  if (near) return (start, size);
  // Half, rounded down, also when the form shrinks by an odd number.
  return (start + (grown - grown % 2) ~/ 2, size);
}
