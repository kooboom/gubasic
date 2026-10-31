import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_model.dart';

/// The height of a Grid's header row and of each of its rows.
const gbGridRowHeight = 24.0;

/// The narrowest a Grid's column is drawn; wider when the Grid has room.
const gbGridMinColumnWidth = 96.0;

/// The key of the cell at [row], [col] of Grid [control] (row -1: the
/// header), for tests.
Key gbGridCellKey(String control, int row, int col) =>
    ValueKey('gb.$control.cell.$row.$col');

/// The key of the text field a Grid's cell is edited in, for tests.
Key gbGridEditorKey(String control) => ValueKey('gb.$control.editor');

/// A Grid (docs/DESIGN.md D116): a header row with the column names
/// (`Headers`), under it the cells row by row (`Cells`), scrolling both
/// ways when they do not fit, with the chosen cell (`Row`, `Col`)
/// highlighted. A click on a cell chooses it and raises `Click`; a second
/// click on the chosen cell, a double-click, Enter or F2 edits it, and so
/// does typing, which starts the text over. Enter, or clicking elsewhere,
/// keeps the edit, Escape drops it; a changed cell raises `Changed` with
/// `Row` and `Col` on it. Unless `ReadOnly`. As before a Button's Click,
/// text still being composed in a TextBox is committed first. In the
/// designer, a Grid without columns shows its name.
class GbGrid extends StatefulWidget {
  const GbGrid({super.key, required this.model, required this.state});

  final GbFormModel model;
  final GbControlState state;

  @override
  State<GbGrid> createState() => _GbGridState();
}

class _GbGridState extends State<GbGrid> {
  final _focus = FocusNode(debugLabel: 'grid');
  final _editorFocus = FocusNode(debugLabel: 'grid editor');
  final _editor = TextEditingController();
  final _across = ScrollController();
  final _down = ScrollController();

  /// The cell being edited, or null.
  (int, int)? _editing;

  GbFormModel get model => widget.model;
  GbControlState get state => widget.state;

  List<String> _list(String property) =>
      (state[property] as List).cast<String>();

  @override
  void initState() {
    super.initState();
    _editorFocus.addListener(() {
      if (!_editorFocus.hasFocus && _editing != null) _keep();
    });
  }

  @override
  void dispose() {
    _focus.dispose();
    _editorFocus.dispose();
    _editor.dispose();
    _across.dispose();
    _down.dispose();
    super.dispose();
  }

  void _choose(int row, int col) {
    if (_editing != null) _keep();
    model.commitComposing();
    _focus.requestFocus();
    if (state['Row'] == row && state['Col'] == col) {
      _edit();
      return;
    }
    if (!model.takes(state.name, 'Click')) return;
    state
      ..set('Row', row)
      ..set('Col', col);
    model.raise(state.name, 'Click');
  }

  /// Starts editing the chosen cell, with [text] in place of its own.
  void _edit([String? text]) {
    if (state['ReadOnly'] == true || model.designing) return;
    final row = state['Row'] as int;
    final col = state['Col'] as int;
    final columns = _list('Headers').length;
    final cells = _list('Cells');
    if (row < 0 || col < 0 || col >= columns) return;
    final i = row * columns + col;
    if (i >= cells.length) return;
    setState(() => _editing = (row, col));
    _editor.text = text ?? cells[i];
    _editor.selection = text == null
        ? TextSelection(baseOffset: 0, extentOffset: _editor.text.length)
        : TextSelection.collapsed(offset: _editor.text.length);
    _editorFocus.requestFocus();
  }

  /// Ends the edit, keeping the text: a changed cell raises Changed.
  void _keep() {
    final (row, col) = _editing!;
    setState(() => _editing = null);
    final columns = _list('Headers').length;
    final cells = List<String>.of(_list('Cells'));
    final i = row * columns + col;
    if (col >= columns || i >= cells.length || cells[i] == _editor.text) {
      return;
    }
    if (!model.takes(state.name, 'Changed')) return;
    cells[i] = _editor.text;
    state
      ..set('Row', row)
      ..set('Col', col)
      ..set('Cells', List<String>.unmodifiable(cells));
    model.raise(state.name, 'Changed');
  }

  void _drop() {
    setState(() => _editing = null);
    _focus.requestFocus();
  }

  KeyEventResult _key(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent || _editing != null) {
      return KeyEventResult.ignored;
    }
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.enter || key == LogicalKeyboardKey.f2) {
      _edit();
      return KeyEventResult.handled;
    }
    final c = event.character;
    final keyboard = HardwareKeyboard.instance;
    if (c != null &&
        c.isNotEmpty &&
        c.codeUnitAt(0) >= 0x20 &&
        c.codeUnitAt(0) != 0x7f &&
        !keyboard.isControlPressed &&
        !keyboard.isMetaPressed) {
      _edit(c);
      return _editing == null ? KeyEventResult.ignored : KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListenableBuilder(
      listenable: state,
      builder: (context, _) {
        final headers = _list('Headers');
        final cells = _list('Cells');
        final columns = headers.length;
        final rows = columns == 0 ? 0 : cells.length ~/ columns;
        final row = state['Row'] as int;
        final col = state['Col'] as int;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: scheme.surface,
            border: Border.all(color: scheme.outline),
            borderRadius: BorderRadius.circular(2),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: columns == 0 && model.designing
                ? Padding(
                    padding: const EdgeInsets.all(8),
                    child: Text(
                      state.name ?? '',
                      style: TextStyle(color: scheme.onSurfaceVariant),
                    ),
                  )
                : Focus(
                    focusNode: _focus,
                    onKeyEvent: _key,
                    child: LayoutBuilder(
                      builder: (context, box) {
                        final width = columns == 0
                            ? box.maxWidth
                            : (box.maxWidth / columns)
                                  .clamp(gbGridMinColumnWidth, double.infinity)
                                  .floorToDouble();
                        // The last column takes what is left over.
                        final last = columns == 0
                            ? width
                            : (box.maxWidth - width * (columns - 1)).clamp(
                                width,
                                double.infinity,
                              );
                        Widget cell(int r, int c, String text) {
                          final chosen = r == row && c == col && r >= 0;
                          final header = r < 0;
                          return Container(
                            key: gbGridCellKey(state.name ?? '', r, c),
                            width: c == columns - 1 ? last : width,
                            height: gbGridRowHeight,
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            alignment: Alignment.centerLeft,
                            decoration: BoxDecoration(
                              color: header
                                  ? scheme.surfaceContainerHighest
                                  : chosen
                                  ? scheme.primaryContainer
                                  : null,
                              border: Border(
                                right: BorderSide(color: scheme.outlineVariant),
                                bottom: BorderSide(
                                  color: scheme.outlineVariant,
                                ),
                              ),
                            ),
                            child: _editing == (r, c)
                                ? EditableText(
                                    key: gbGridEditorKey(state.name ?? ''),
                                    controller: _editor,
                                    focusNode: _editorFocus,
                                    style: TextStyle(
                                      color: scheme.onSurface,
                                      fontSize: 14,
                                    ),
                                    cursorColor: scheme.primary,
                                    backgroundCursorColor: scheme.outline,
                                    selectionColor: scheme.primary.withValues(
                                      alpha: 0.3,
                                    ),
                                    onSubmitted: (_) {
                                      _keep();
                                      _focus.requestFocus();
                                    },
                                  )
                                : Text(
                                    text,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: header
                                          ? FontWeight.w600
                                          : null,
                                      color: chosen
                                          ? scheme.onPrimaryContainer
                                          : scheme.onSurface,
                                    ),
                                  ),
                          );
                        }

                        return CallbackShortcuts(
                          bindings: {
                            const SingleActivator(
                              LogicalKeyboardKey.escape,
                            ): () {
                              if (_editing != null) _drop();
                            },
                          },
                          child: Scrollbar(
                            controller: _across,
                            child: SingleChildScrollView(
                              controller: _across,
                              scrollDirection: Axis.horizontal,
                              child: SizedBox(
                                width: columns == 0
                                    ? 0
                                    : width * (columns - 1) + last,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        for (var c = 0; c < columns; c++)
                                          cell(-1, c, headers[c]),
                                      ],
                                    ),
                                    Expanded(
                                      child: ListView.builder(
                                        controller: _down,
                                        padding: EdgeInsets.zero,
                                        itemCount: rows,
                                        itemExtent: gbGridRowHeight,
                                        itemBuilder: (context, r) => Row(
                                          children: [
                                            for (var c = 0; c < columns; c++)
                                              GestureDetector(
                                                behavior:
                                                    HitTestBehavior.opaque,
                                                onTap: () => _choose(r, c),
                                                child: cell(
                                                  r,
                                                  c,
                                                  cells[r * columns + c],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        );
      },
    );
  }
}
