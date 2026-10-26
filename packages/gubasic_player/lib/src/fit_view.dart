import 'dart:math';

import 'package:flutter/material.dart';

/// How much a view [natural] large is shrunk to fit [space] (D66): never
/// grown, and never below a tenth.
double fitScale(Size natural, Size space) {
  if (natural.isEmpty || space.isEmpty) return 1;
  final scale = min(space.width / natural.width, space.height / natural.height);
  return scale.clamp(0.1, 1.0).toDouble();
}

/// The room [constraints] leave inside [padding] on every side.
Size inside(BoxConstraints constraints, double padding) => Size(
  max(0, constraints.maxWidth - 2 * padding),
  max(0, constraints.maxHeight - 2 * padding),
);

/// [child], laid out [natural] large, drawn [scale] times as large. The
/// pointer reaches it as the user sees it: a click on a shrunk control is
/// a click on that control.
Widget fitted(Widget child, Size natural, double scale) => scale >= 1
    ? child
    : SizedBox(
        width: natural.width * scale,
        height: natural.height * scale,
        child: FittedBox(
          fit: BoxFit.fill,
          alignment: Alignment.topLeft,
          child: SizedBox.fromSize(size: natural, child: child),
        ),
      );

/// The percentage a shrunk view is shown at, in a corner of it.
class FitPercent extends StatelessWidget {
  const FitPercent(this.scale, {super.key});

  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return IgnorePointer(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          '${(scale * 100).floor()}%',
          style: theme.textTheme.labelSmall,
        ),
      ),
    );
  }
}
