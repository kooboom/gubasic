import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import '../strings.dart';

/// The key of the completion list under the caret (D50), and of each of
/// its rows: `code.completion.ListIndex`.
const completionListKey = ValueKey('code.completion');
ValueKey<String> completionRowKey(String name) =>
    ValueKey('code.completion.$name');

/// The height of a row of the completion list, and how many rows show
/// before it scrolls.
const completionRowHeight = 22.0;
const completionRows = 8;
const completionWidth = 400.0;

/// The names the code editor offers at the caret (D50): suggestions
/// under "Did you mean?" first, then the others, each with what it is and
/// its type or parameters. [selected] is highlighted; a click on a row
/// calls [onPick] with its index.
class CompletionList extends StatefulWidget {
  const CompletionList({
    super.key,
    required this.completions,
    required this.selected,
    required this.strings,
    required this.style,
    required this.onPick,
  });

  final Completions completions;
  final int selected;
  final IdeStrings strings;

  /// The code's style: names show as they will in the code.
  final TextStyle style;
  final ValueChanged<int> onPick;

  /// The height of the list for [completions].
  static double heightOf(Completions completions) {
    final items = completions.items;
    final header = items.any((c) => c.kind == CompletionKind.suggestion)
        ? 1
        : 0;
    final rows = (items.length + header).clamp(1, completionRows);
    return rows * completionRowHeight + 4;
  }

  @override
  State<CompletionList> createState() => _CompletionListState();
}

class _CompletionListState extends State<CompletionList> {
  final _scroll = ScrollController();

  bool get _hasHeader =>
      widget.completions.items.any((c) => c.kind == CompletionKind.suggestion);

  @override
  void didUpdateWidget(CompletionList old) {
    super.didUpdateWidget(old);
    // Keep the chosen row in view.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_scroll.hasClients) return;
      final row = widget.selected + (_hasHeader ? 1 : 0);
      final top = row * completionRowHeight;
      final view = _scroll.position.viewportDimension;
      final at = _scroll.offset;
      if (top < at) {
        _scroll.jumpTo(top);
      } else if (top + completionRowHeight > at + view) {
        _scroll.jumpTo(top + completionRowHeight - view);
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final items = widget.completions.items;
    final hint = theme.textTheme.bodySmall!.copyWith(color: theme.hintColor);
    final s = widget.strings;
    return Material(
      key: completionListKey,
      elevation: 4,
      color: scheme.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: scheme.outlineVariant),
        borderRadius: const BorderRadius.all(Radius.circular(4)),
      ),
      child: SizedBox(
        width: completionWidth,
        height: CompletionList.heightOf(widget.completions),
        child: ListView.builder(
          controller: _scroll,
          // Inside the rounded border, which does not clip: drawing a
          // clipped list the first time is slower on the web (D50).
          padding: const EdgeInsets.all(2),
          itemExtent: completionRowHeight,
          itemCount: items.length + (_hasHeader ? 1 : 0),
          itemBuilder: (context, row) {
            if (_hasHeader && row == 0) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(s.didYouMean, style: hint),
                ),
              );
            }
            final i = row - (_hasHeader ? 1 : 0);
            final c = items[i];
            final selected = i == widget.selected;
            final kind = [
              s.completionKinds[c.kind]!,
              if (c.readOnly) s.readOnlyProperty,
            ].where((w) => w.isNotEmpty).join(', ');
            return InkWell(
              key: completionRowKey(c.name),
              onTap: () => widget.onPick(i),
              child: Container(
                color: selected ? scheme.primaryContainer : null,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: Row(
                  children: [
                    Text(
                      c.name,
                      style: widget.style.copyWith(
                        height: 1.2,
                        color: selected
                            ? scheme.onPrimaryContainer
                            : scheme.onSurface,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        c.detail,
                        overflow: TextOverflow.ellipsis,
                        style: widget.style.copyWith(
                          height: 1.2,
                          fontSize: (widget.style.fontSize ?? 13) - 1,
                          color: theme.hintColor,
                        ),
                      ),
                    ),
                    if (kind.isNotEmpty) ...[
                      const SizedBox(width: 8),
                      Text(kind, style: hint),
                    ],
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
