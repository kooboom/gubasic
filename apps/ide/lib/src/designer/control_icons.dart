import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

/// The blue and the yellow of GuBASIC's own icon (docs/icons/ide.svg).
const _blue = Color(0xFF3B6EA5);
const _yellow = Color(0xFFF2C94C);

/// A control drawn small, as the toolbox and the tray show it (D107): a
/// Button as a button, a ListBox as a list, the way Visual Basic 6's
/// toolbox shows its tools, drawn for GuBASIC in the colours of its icon.
///
/// Every icon follows the same rules, so that they read as one set: drawn
/// on a grid of 20 × 20; a control's body is a light face with an outline
/// of one weight and one corner; a wide control (Button, TextBox,
/// ComboBox) is 16 × 9, a square one (ListBox, Image, Frame, Timer)
/// 14 × 14, both centred; one part in GuBASIC's blue says what the control
/// is for, and lines of text are a softer grey. [kind] is a component's
/// name in lower case, or `pointer`; [enabled] false draws it grey.
class ControlIcon extends StatelessWidget {
  const ControlIcon(
    this.kind, {
    super.key,
    this.size = 20,
    this.enabled = true,
  });

  /// The icon of controls of [type].
  ControlIcon.of(ComponentSpec type, {Key? key, double size = 20})
    : this(type.name.toLowerCase(), key: key, size: size);

  final String kind;
  final double size;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Opacity(
      opacity: enabled ? 1 : 0.38,
      child: CustomPaint(
        size: Size.square(size),
        painter: _ControlIconPainter(
          kind,
          ink: scheme.onSurface,
          face: scheme.surface,
          // On a dark theme the blue is lightened, so that it shows.
          accent: scheme.brightness == Brightness.dark
              ? Color.lerp(_blue, Colors.white, 0.35)!
              : _blue,
        ),
      ),
    );
  }
}

/// The outline's weight and corner, the same for every icon.
const _weight = 1.5;
const _corner = Radius.circular(1.5);

/// The body of a wide control, and of a square one.
const _wide = Rect.fromLTRB(2, 5.5, 18, 14.5);
const _square = Rect.fromLTRB(3, 3, 17, 17);

class _ControlIconPainter extends CustomPainter {
  _ControlIconPainter(
    this.kind, {
    required this.ink,
    required this.face,
    required this.accent,
  });

  final String kind;
  final Color ink;
  final Color face;
  final Color accent;

  Paint _stroke(Color c) => Paint()
    ..color = c
    ..style = PaintingStyle.stroke
    ..strokeWidth = _weight
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;

  Paint _fill(Color c) => Paint()..color = c;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.scale(size.width / 20, size.height / 20);
    final outline = _stroke(ink);
    final text = _stroke(ink.withValues(alpha: 0.5));
    final mark = _stroke(accent);
    final faceFill = _fill(Color.alphaBlend(ink.withValues(alpha: 0.06), face));

    /// A control's body: the face, then the outline.
    void body(Rect r) {
      final rr = RRect.fromRectAndRadius(r, _corner);
      canvas
        ..drawRRect(rr, faceFill)
        ..drawRRect(rr, outline);
    }

    void line(double x1, double y1, double x2, double y2, Paint p) =>
        canvas.drawLine(Offset(x1, y1), Offset(x2, y2), p);

    switch (kind) {
      case 'pointer':
        final arrow = Path()
          ..moveTo(6.5, 3)
          ..lineTo(6.5, 15.5)
          ..lineTo(9.6, 12.6)
          ..lineTo(11.8, 17)
          ..lineTo(13.6, 16.1)
          ..lineTo(11.4, 11.8)
          ..lineTo(15.5, 11.8)
          ..close();
        canvas
          ..drawPath(arrow, faceFill)
          ..drawPath(arrow, outline);
      case 'button':
        body(_wide);
        line(6.5, 10, 13.5, 10, mark);
      case 'label':
        // The letter A, as Visual Basic's Label tool shows it, in strokes
        // of the same weight.
        canvas.drawPath(
          Path()
            ..moveTo(5.5, 16)
            ..lineTo(10, 4)
            ..lineTo(14.5, 16),
          outline,
        );
        line(7.3, 11.6, 12.7, 11.6, mark);
      case 'textbox':
        body(_wide);
        line(4.8, 10, 10.5, 10, text);
        line(12.8, 7.6, 12.8, 12.4, mark);
      case 'combobox':
        body(_wide);
        line(4.8, 10, 9.5, 10, text);
        line(12.5, 5.5, 12.5, 14.5, outline);
        canvas.drawPath(
          Path()
            ..moveTo(13.9, 8.9)
            ..lineTo(16.6, 8.9)
            ..lineTo(15.25, 11.1)
            ..close(),
          _fill(accent),
        );
      case 'checkbox':
        body(const Rect.fromLTRB(2, 5.5, 11, 14.5));
        canvas.drawPath(
          Path()
            ..moveTo(4.2, 10.1)
            ..lineTo(6, 11.9)
            ..lineTo(8.9, 8.1),
          mark,
        );
        line(13.5, 10, 18, 10, text);
      case 'optionbutton':
        canvas
          ..drawCircle(const Offset(6.5, 10), 4.5, faceFill)
          ..drawCircle(const Offset(6.5, 10), 4.5, outline)
          ..drawCircle(const Offset(6.5, 10), 2, _fill(accent));
        line(13.5, 10, 18, 10, text);
      case 'listbox':
        body(_square);
        canvas.drawRect(const Rect.fromLTRB(4.6, 5, 12.6, 7.8), _fill(accent));
        line(5.4, 10.6, 11.8, 10.6, text);
        line(5.4, 14, 11.8, 14, text);
        line(14.2, 3, 14.2, 17, outline);
      case 'frame':
        // The square body with its caption in the top edge.
        canvas.drawPath(
          Path()
            ..moveTo(5, 5)
            ..lineTo(3, 5)
            ..lineTo(3, 17)
            ..lineTo(17, 17)
            ..lineTo(17, 5)
            ..lineTo(12.5, 5),
          outline,
        );
        line(6.5, 5, 11, 5, mark);
      case 'grid':
        // The square body, its header row filled, ruled into cells.
        canvas
          ..drawRRect(RRect.fromRectAndRadius(_square, _corner), faceFill)
          ..drawRect(const Rect.fromLTRB(3, 3, 17, 7.5), _fill(accent));
        line(3, 7.5, 17, 7.5, outline);
        line(3, 12.2, 17, 12.2, text);
        line(7.7, 7.5, 7.7, 17, text);
        line(12.3, 7.5, 12.3, 17, text);
        canvas.drawRRect(RRect.fromRectAndRadius(_square, _corner), outline);
      case 'image':
        canvas
          ..drawRRect(RRect.fromRectAndRadius(_square, _corner), faceFill)
          ..drawPath(
            Path()
              ..moveTo(3.8, 16.2)
              ..lineTo(8, 10.5)
              ..lineTo(11, 13.6)
              ..lineTo(12.8, 11.8)
              ..lineTo(16.2, 16.2)
              ..close(),
            _fill(accent),
          )
          ..drawCircle(const Offset(13, 7), 1.6, _fill(_yellow))
          ..drawRRect(RRect.fromRectAndRadius(_square, _corner), outline);
      case 'timer':
        canvas
          ..drawCircle(const Offset(10, 10.8), 6.2, faceFill)
          ..drawCircle(const Offset(10, 10.8), 6.2, outline);
        line(8.4, 2.6, 11.6, 2.6, outline);
        line(10, 2.6, 10, 4.6, outline);
        line(10, 10.8, 10, 7.4, mark);
        line(10, 10.8, 12.6, 12.2, mark);
      case 'openfiledialog' || 'savefiledialog':
        // A folder, with an arrow out of it to open, into it to save.
        final folder = Path()
          ..moveTo(3, 6.5)
          ..lineTo(3, 16)
          ..lineTo(17, 16)
          ..lineTo(17, 7.5)
          ..lineTo(9.5, 7.5)
          ..lineTo(8, 5)
          ..lineTo(3.8, 5)
          ..close();
        canvas
          ..drawPath(folder, faceFill)
          ..drawPath(folder, outline);
        final open = kind == 'openfiledialog';
        line(10, open ? 14 : 9.5, 10, open ? 9.5 : 14, mark);
        canvas.drawPath(
          Path()
            ..moveTo(7.8, open ? 11.6 : 11.9)
            ..lineTo(10, open ? 9.4 : 14.1)
            ..lineTo(12.2, open ? 11.6 : 11.9),
          mark,
        );
      default:
        body(_square);
    }
  }

  @override
  bool shouldRepaint(_ControlIconPainter old) =>
      old.kind != kind ||
      old.ink != ink ||
      old.face != face ||
      old.accent != accent;
}
