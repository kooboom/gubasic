import 'package:flutter/material.dart';
import 'package:gubasic_lang/gubasic_lang.dart';

import '../strings.dart';

/// The key of a field of the menu editor: `Caption`, `Name`, `Shortcut`,
/// `Checked`, `Enabled`, `Visible`.
ValueKey<String> menuEditorFieldKey(String field) =>
    ValueKey('menuEditor.$field');

/// The key of a button of the menu editor: `next`, `insert`, `delete`,
/// `out`, `in`, `up`, `down`, `ok`.
ValueKey<String> menuEditorButtonKey(String button) =>
    ValueKey('menuEditor.button.$button');

/// The key of row [index] of the menu editor's list.
ValueKey<String> menuEditorRowKey(int index) =>
    ValueKey('menuEditor.row.$index');

/// One item of a form's menu bar as the menu editor shows it: how deep
/// it is, and its properties.
class MenuRow {
  MenuRow({
    this.name = '',
    this.caption = '',
    this.shortcut = '',
    this.checked = false,
    this.enabled = true,
    this.visible = true,
    this.level = 0,
    this.others = const {},
  });

  String name;
  String caption;
  String shortcut;
  bool checked;
  bool enabled;
  bool visible;

  /// 0 on the menu bar, 1 in a menu on it, and so on.
  int level;

  /// Its other properties, as the form file has them (its `Tag`): kept.
  final Map<String, Object> others;
}

/// The menu items of [form] as rows, in the form file's order (D106).
List<MenuRow> menuRowsOf(FormFile form) {
  int level(ControlDecl c) {
    var n = 0;
    for (var p = c.container; p != null; p = form.control(p)?.container) {
      n++;
    }
    return n;
  }

  return [
    for (final c in form.controls)
      if (c.component.menu)
        MenuRow(
          name: c.name,
          caption: c.valueOf('Caption') as String,
          shortcut: c.valueOf('Shortcut') as String,
          checked: c.valueOf('Checked') as bool,
          enabled: c.valueOf('Enabled') as bool,
          visible: c.valueOf('Visible') as bool,
          level: level(c),
          others: {
            for (final MapEntry(:key, :value) in c.properties.entries)
              if (!const {
                'Caption',
                'Shortcut',
                'Checked',
                'Enabled',
                'Visible',
              }.contains(key))
                key: value,
          },
        ),
  ];
}

/// What is wrong with [rows] as the menu bar of [form], in the language of
/// [s]; null when nothing is. Names must be usable and unique among the
/// form's other controls and the rows; each row is at most one level
/// deeper than the one above; a line holds nothing; a Shortcut is one,
/// and only on an item without items.
String? menuRowsProblem(FormFile form, List<MenuRow> rows, IdeStrings s) {
  final seen = <String>{
    for (final c in form.controls)
      if (!c.component.menu) c.name.toLowerCase(),
  };
  for (final (i, r) in rows.indexed) {
    if (r.name.isEmpty) return s.menuNoName;
    if (!isUsableName(r.name)) return s.menuBadName.replaceAll('{0}', r.name);
    if (!seen.add(r.name.toLowerCase())) {
      return s.menuNameTaken.replaceAll('{0}', r.name);
    }
    final above = i == 0 ? -1 : rows[i - 1].level;
    if (r.level > above + 1) {
      return s.menuTooDeep.replaceAll('{0}', r.name);
    }
    final holds = i + 1 < rows.length && rows[i + 1].level > r.level;
    if (holds && r.caption == '-') {
      return s.menuLineHolds.replaceAll('{0}', r.name);
    }
    if (normalShortcut(r.shortcut) == null) {
      return s.menuBadShortcut.replaceAll('{0}', r.shortcut);
    }
    if (holds && r.shortcut.isNotEmpty) {
      return s.menuShortcutOfMenu.replaceAll('{0}', r.name);
    }
  }
  return null;
}

/// [form] with [rows] as its menu bar (D106), in place of the one it had;
/// [rows] must have no [menuRowsProblem].
FormFile withMenuRows(FormFile form, List<MenuRow> rows) {
  final parents = <String>[];
  final menus = <ControlDecl>[];
  for (final r in rows) {
    parents.length = r.level;
    menus.add(
      ControlDecl(
        name: r.name,
        component: menuComponent,
        properties: {
          ...r.others,
          'Caption': r.caption,
          'Shortcut': normalShortcut(r.shortcut)!,
          'Checked': r.checked,
          'Enabled': r.enabled,
          'Visible': r.visible,
        },
        line: 0,
        container: parents.isEmpty ? null : parents.last,
      ),
    );
    parents.add(r.name);
  }
  return FormFile(
    name: form.name,
    properties: Map.of(form.properties),
    controls: [
      for (final c in form.controls)
        if (!c.component.menu) c,
      ...menus,
    ],
  );
}

/// The menu editor (D106), as in Visual Basic 6: the fields of the chosen
/// item above, the items below, each indented by its level. Returns the
/// rows when OK is pressed with nothing wrong, or null.
Future<List<MenuRow>?> showMenuEditor(
  BuildContext context,
  FormFile form,
  IdeStrings s,
) => showDialog<List<MenuRow>>(
  context: context,
  builder: (context) => _MenuEditor(form: form, strings: s),
);

class _MenuEditor extends StatefulWidget {
  const _MenuEditor({required this.form, required this.strings});

  final FormFile form;
  final IdeStrings strings;

  @override
  State<_MenuEditor> createState() => _MenuEditorState();
}

class _MenuEditorState extends State<_MenuEditor> {
  late final List<MenuRow> _rows = menuRowsOf(widget.form);
  var _at = 0;
  String? _problem;

  final _caption = TextEditingController();
  final _name = TextEditingController();
  final _shortcut = TextEditingController();
  final _captionFocus = FocusNode();

  IdeStrings get s => widget.strings;

  @override
  void initState() {
    super.initState();
    if (_rows.isEmpty) _rows.add(MenuRow());
    _load();
  }

  @override
  void dispose() {
    _caption.dispose();
    _name.dispose();
    _shortcut.dispose();
    _captionFocus.dispose();
    super.dispose();
  }

  MenuRow get _row => _rows[_at];

  /// The chosen row into the fields.
  void _load() {
    _caption.text = _row.caption;
    _name.text = _row.name;
    _shortcut.text = _row.shortcut;
  }

  void _choose(int i) => setState(() {
    _at = i;
    _load();
    _problem = null;
  });

  void _change(void Function() change) => setState(() {
    change();
    _problem = null;
  });

  void _next() => setState(() {
    if (_at == _rows.length - 1) {
      _rows.add(MenuRow(level: _row.level));
    }
    _at++;
    _load();
    _captionFocus.requestFocus();
  });

  void _insert() => setState(() {
    _rows.insert(_at, MenuRow(level: _row.level));
    _load();
    _captionFocus.requestFocus();
  });

  void _delete() => setState(() {
    _rows.removeAt(_at);
    if (_rows.isEmpty) _rows.add(MenuRow());
    _at = _at.clamp(0, _rows.length - 1);
    _load();
  });

  void _move(int by) => setState(() {
    final to = _at + by;
    if (to < 0 || to >= _rows.length) return;
    final row = _rows.removeAt(_at);
    _rows.insert(to, row);
    _at = to;
  });

  void _ok() {
    // An empty last row, as Next leaves it, is not an item.
    final rows = [
      for (final (i, r) in _rows.indexed)
        if (!(i == _rows.length - 1 &&
            r.name.isEmpty &&
            r.caption.isEmpty &&
            r.shortcut.isEmpty))
          r,
    ];
    final problem = menuRowsProblem(widget.form, rows, s);
    if (problem != null) {
      setState(() => _problem = problem);
      return;
    }
    Navigator.pop(context, rows);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget field(
      String label,
      TextEditingController c,
      ValueChanged<String> on, {
      FocusNode? focus,
      String? hint,
    }) => Expanded(
      child: TextField(
        key: menuEditorFieldKey(label),
        controller: c,
        focusNode: focus,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          isDense: true,
        ),
        onChanged: (v) => _change(() => on(v)),
      ),
    );
    Widget check(String label, bool value, ValueChanged<bool> on) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Checkbox(
          key: menuEditorFieldKey(label),
          value: value,
          onChanged: (v) => _change(() => on(v!)),
        ),
        Text(label),
      ],
    );
    Widget button(String key, String label, VoidCallback? on) => OutlinedButton(
      key: menuEditorButtonKey(key),
      onPressed: on,
      child: Text(label),
    );
    Widget arrow(String key, IconData icon, String tip, VoidCallback? on) =>
        IconButton(
          key: menuEditorButtonKey(key),
          tooltip: tip,
          icon: Icon(icon),
          onPressed: on,
        );
    return AlertDialog(
      title: Text(s.menuEditorTitle),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                field(
                  'Caption',
                  _caption,
                  (v) => _row.caption = v,
                  focus: _captionFocus,
                ),
                const SizedBox(width: 12),
                field('Name', _name, (v) => _row.name = v),
              ],
            ),
            Row(
              children: [
                field(
                  'Shortcut',
                  _shortcut,
                  (v) => _row.shortcut = v,
                  hint: 'Ctrl+O',
                ),
                const SizedBox(width: 12),
                check('Checked', _row.checked, (v) => _row.checked = v),
                check('Enabled', _row.enabled, (v) => _row.enabled = v),
                check('Visible', _row.visible, (v) => _row.visible = v),
              ],
            ),
            const SizedBox(height: 4),
            Text(s.menuLineHint, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Row(
              children: [
                arrow(
                  'out',
                  Icons.arrow_back,
                  s.menuOut,
                  _row.level > 0 ? () => _change(() => _row.level--) : null,
                ),
                arrow(
                  'in',
                  Icons.arrow_forward,
                  s.menuIn,
                  _at > 0 && _row.level <= _rows[_at - 1].level
                      ? () => _change(() => _row.level++)
                      : null,
                ),
                arrow(
                  'up',
                  Icons.arrow_upward,
                  s.menuUp,
                  _at > 0 ? () => _move(-1) : null,
                ),
                arrow(
                  'down',
                  Icons.arrow_downward,
                  s.menuDown,
                  _at < _rows.length - 1 ? () => _move(1) : null,
                ),
                const Spacer(),
                button('next', s.menuNext, _next),
                const SizedBox(width: 8),
                button('insert', s.menuInsert, _insert),
                const SizedBox(width: 8),
                button('delete', s.deleteControl, _delete),
              ],
            ),
            const SizedBox(height: 8),
            Container(
              height: 200,
              decoration: BoxDecoration(
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: ListView(
                children: [
                  for (final (i, r) in _rows.indexed)
                    ListTile(
                      key: menuEditorRowKey(i),
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      selected: i == _at,
                      selectedTileColor: theme.colorScheme.secondaryContainer,
                      contentPadding: const EdgeInsets.only(left: 8),
                      title: Text(
                        '${'····' * r.level}'
                        '${r.caption.isEmpty ? r.name : r.caption}',
                      ),
                      trailing: r.shortcut.isEmpty
                          ? null
                          : Padding(
                              padding: const EdgeInsets.only(right: 8),
                              child: Text(r.shortcut),
                            ),
                      onTap: () => _choose(i),
                    ),
                ],
              ),
            ),
            if (_problem case final problem?) ...[
              const SizedBox(height: 8),
              Text(
                problem,
                key: const ValueKey('menuEditor.problem'),
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.runtime.cancel),
        ),
        FilledButton(
          key: menuEditorButtonKey('ok'),
          onPressed: _ok,
          child: Text(s.runtime.ok),
        ),
      ],
    );
  }
}
