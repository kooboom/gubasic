import 'package:flutter/material.dart';

import 'form_model.dart';

/// The height of one item of a ListBox.
const gbListItemHeight = 22.0;

/// The key of item [index] of ListBox [control], for tests.
Key gbListItemKey(String control, int index) =>
    ValueKey('gb.$control.item.$index');

/// A ListBox: its items (`Items`, which the program fills with AddItem),
/// one under the other, scrolling when they do not fit, with the chosen
/// one (`ListIndex`) highlighted (docs/DESIGN.md D46). A click on an item
/// chooses it and raises `Changed`; as before a Button's Click, text
/// still being composed in a TextBox is committed first. A click on the
/// chosen item, or one the program would ignore because the ListBox's own
/// Changed is still running, changes nothing. In the designer, an empty
/// ListBox shows its name.
class GbListBox extends StatelessWidget {
  const GbListBox({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  void _choose(int index) {
    model.commitComposing();
    if (state['ListIndex'] == index) return;
    if (!model.takes(state.name, 'Changed')) return;
    state.set('ListIndex', index);
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
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: items.isEmpty && model.designing
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      state.name ?? '',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : ListView.builder(
                    padding: EdgeInsets.zero,
                    itemCount: items.length,
                    itemExtent: gbListItemHeight,
                    itemBuilder: (context, i) => GestureDetector(
                      key: gbListItemKey(state.name ?? '', i),
                      behavior: HitTestBehavior.opaque,
                      onTap: () => _choose(i),
                      child: Container(
                        color: i == chosen ? scheme.primaryContainer : null,
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        alignment: Alignment.centerLeft,
                        child: Text(
                          items[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: i == chosen
                                ? scheme.onPrimaryContainer
                                : scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }
}
