/// A control's `Anchor` (docs/DESIGN.md D57): the edges of the form whose
/// distance it keeps when the form changes size, as words.
///
/// The runtime works out the same positions (gubasic_runtime's
/// `gbAnchored`); the parity programs check that both agree.
library;

/// The edges a control keeps its distance to unless it says otherwise:
/// it stays where it was drawn, as in Visual Basic .NET.
const defaultAnchor = 'Left Top';

const _edges = ['left', 'top', 'right', 'bottom'];
const _names = ['Left', 'Top', 'Right', 'Bottom'];

/// [text] as `Anchor` keeps it: the edges it names, in the order
/// `Left Top Right Bottom`, each once, separated by one space; "" for
/// none. The words may come in any order and case, separated by spaces or
/// commas. Null when a word is not an edge.
String? normalAnchor(String text) {
  final named = <int>{};
  for (final word in text.split(RegExp(r'[\s,]+'))) {
    if (word.isEmpty) continue;
    final i = _edges.indexOf(word.toLowerCase());
    if (i < 0) return null;
    named.add(i);
  }
  return [
    for (var i = 0; i < _edges.length; i++)
      if (named.contains(i)) _names[i],
  ].join(' ');
}

/// A control's place on its form.
typedef AnchorRect = ({int left, int top, int width, int height});

/// Where a control with [anchor] (as [normalAnchor] gives it) goes when
/// its form becomes [width] x [height], having been at [base] when the
/// form was [baseWidth] x [baseHeight]. For each direction: anchored to
/// both edges, it stretches; to one, it keeps its distance to that edge;
/// to neither, it moves half as much as the form grows, so that it stays
/// as near the middle (rounded down). Its size never goes below 0.
///
/// Worked out from [base] each time, never from the last place: a form
/// made larger and then as it was puts every control back exactly.
AnchorRect anchoredRect(
  AnchorRect base,
  String anchor, {
  required int baseWidth,
  required int baseHeight,
  required int width,
  required int height,
}) {
  final words = anchor.split(' ');
  final (left, w) = _axis(base.left, base.width, width - baseWidth,
      words.contains('Left'), words.contains('Right'));
  final (top, h) = _axis(base.top, base.height, height - baseHeight,
      words.contains('Top'), words.contains('Bottom'));
  return (left: left, top: top, width: w, height: h);
}

(int, int) _axis(int start, int size, int grown, bool near, bool far) {
  if (near && far) return (start, size + grown < 0 ? 0 : size + grown);
  if (far) return (start + grown, size);
  if (near) return (start, size);
  // Half, rounded down: the same for a form grown or shrunk by an odd
  // number, on the VM and in JavaScript.
  return (start + (grown - grown % 2) ~/ 2, size);
}
