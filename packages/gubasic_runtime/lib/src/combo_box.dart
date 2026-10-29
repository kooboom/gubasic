import 'package:flutter/material.dart';

import 'form_model.dart';
import 'list_box.dart';

/// A ComboBox: the chosen item (`Text` of `Items` at `ListIndex`) in a
/// closed box, which a click opens as a list of the items to pick one
/// (docs/DESIGN.md D104). Picking another item chooses it and raises
/// `Changed`, as a ListBox does; text still being composed in a TextBox is
/// committed first. In the designer, it shows its name.
class GbComboBox extends StatelessWidget {
  const GbComboBox({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  Future<void> _open(BuildContext context) async {
    model.commitComposing();
    final items = state['Items'] as List<String>;
    if (items.isEmpty) return;
    final box = context.findRenderObject()! as RenderBox;
    final overlay =
        Overlay.of(context).context.findRenderObject()! as RenderBox;
    final at = box.localToGlobal(Offset(0, box.size.height), ancestor: overlay);
    final chosen = state['ListIndex'] as int;
    final picked = await showMenu<int>(
      context: context,
      position: RelativeRect.fromRect(
        at & Size(box.size.width, 0),
        Offset.zero & overlay.size,
      ),
      constraints: BoxConstraints(minWidth: box.size.width),
      items: [
        for (var i = 0; i < items.length; i++)
          PopupMenuItem(
            key: gbListItemKey(state.name ?? '', i),
            value: i,
            height: gbListItemHeight + 8,
            child: Text(
              items[i],
              style: i == chosen
                  ? const TextStyle(fontWeight: FontWeight.w600)
                  : null,
            ),
          ),
      ],
    );
    if (picked == null || picked == state['ListIndex']) return;
    if (!model.takes(state.name, 'Changed')) return;
    state.set('ListIndex', picked);
    model.raise(state.name, 'Changed');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final items = state['Items'] as List<String>;
        final chosen = state['ListIndex'] as int;
        final text = model.designing
            ? state.name ?? ''
            : chosen < 0 || chosen >= items.length
            ? ''
            : items[chosen];
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: model.designing ? null : () => _open(context),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outline),
              borderRadius: BorderRadius.circular(2),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      text,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: model.designing
                            ? scheme.onSurfaceVariant
                            : scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const Icon(Icons.arrow_drop_down, size: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}
