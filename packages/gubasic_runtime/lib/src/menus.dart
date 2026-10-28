import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'form_model.dart';

/// Whether a form's menu bar goes on the system's menu bar rather than
/// into the window (docs/DESIGN.md D106): in a macOS app, not on the web.
bool get gbUsesSystemMenus =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// The key of the in-window menu bar item of menu [name].
ValueKey<String> gbMenuKey(String name) =>
    ValueKey('gb.menu.${name.toLowerCase()}');

/// The key of a form's in-window menu bar.
const gbMenuBarKey = ValueKey('gb.menuBar');

/// The height of a form's in-window menu bar.
const gbMenuBarHeight = 28.0;

/// What a menu item's Caption of `-` makes: a line between items.
bool gbIsMenuLine(GbControlState item) => item.text('Caption') == '-';

/// The keys `Shortcut` [shortcut] names, as gubasic_lang's
/// `normalShortcut` writes them (`Ctrl+Shift+S`, `F5`); null for "".
/// [apple]: Ctrl is the Command key.
SingleActivator? gbShortcut(String shortcut, {bool apple = false}) {
  if (shortcut.isEmpty) return null;
  final words = shortcut.split('+');
  final key = switch (words.last) {
    'Delete' => LogicalKeyboardKey.delete,
    'Insert' => LogicalKeyboardKey.insert,
    final k when k.length > 1 => _functionKeys[int.parse(k.substring(1)) - 1],
    final k when RegExp('[0-9]').hasMatch(k) => LogicalKeyboardKey(
      LogicalKeyboardKey.digit0.keyId + int.parse(k),
    ),
    final k => LogicalKeyboardKey(
      LogicalKeyboardKey.keyA.keyId + k.codeUnitAt(0) - 'A'.codeUnitAt(0),
    ),
  };
  final ctrl = words.contains('Ctrl');
  return SingleActivator(
    key,
    control: ctrl && !apple,
    meta: ctrl && apple,
    shift: words.contains('Shift'),
    alt: words.contains('Alt'),
  );
}

const _functionKeys = [
  LogicalKeyboardKey.f1,
  LogicalKeyboardKey.f2,
  LogicalKeyboardKey.f3,
  LogicalKeyboardKey.f4,
  LogicalKeyboardKey.f5,
  LogicalKeyboardKey.f6,
  LogicalKeyboardKey.f7,
  LogicalKeyboardKey.f8,
  LogicalKeyboardKey.f9,
  LogicalKeyboardKey.f10,
  LogicalKeyboardKey.f11,
  LogicalKeyboardKey.f12,
];

/// Whether menu item [item] of [model] can be chosen now in the menu bar:
/// it and the menus it is in are Enabled and Visible (D106).
bool gbMenuEnabled(GbFormModel model, GbControlState item) {
  for (GbControlState? m = item; m != null; m = model.control(m.container)) {
    if (m['Enabled'] != true || m['Visible'] != true) return false;
    if (m.container == null) break;
  }
  return true;
}

/// The user chooses menu item [item]: its Click, unless it or a menu it is
/// in is not Enabled (D106); in a designer, always. As before a click,
/// text still being composed in a TextBox is committed first.
void gbChooseMenu(GbFormModel model, GbControlState item) {
  if (!model.designing && !gbMenuEnabled(model, item)) return;
  model.raise(item.name, 'Click');
}

/// The keys of [model]'s menu items with a Shortcut, each choosing its item
/// (D106). [apple]: Ctrl is the Command key.
Map<ShortcutActivator, VoidCallback> gbMenuShortcuts(
  GbFormModel model, {
  bool apple = false,
}) => {
  for (final item in model.menuItems)
    if (gbShortcut(item.text('Shortcut'), apple: apple) case final keys?
        when model.menusIn(item.name).isEmpty)
      keys: () => gbChooseMenu(model, item),
};

/// A form's menu bar drawn in its window, above the form (D106): on the
/// web and on Windows. A menu opens its items; an item without items is
/// chosen; a `-` is a line; an item that is not Enabled is grey; a
/// Checked one has a check mark; a Shortcut is shown beside it. In a
/// designer every item can be chosen, to open its handler.
class GbMenuBar extends StatelessWidget {
  const GbMenuBar({super.key, required this.model});

  final GbFormModel model;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([model.layout, ...model.menuItems]),
    builder: (context, _) => SizedBox(
      height: gbMenuBarHeight,
      child: MenuBar(
        key: gbMenuBarKey,
        style: const MenuStyle(
          padding: WidgetStatePropertyAll(EdgeInsets.zero),
          elevation: WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(RoundedRectangleBorder()),
        ),
        children: [
          for (final m in model.menusIn(null))
            if (m['Visible'] == true) _item(context, m),
        ],
      ),
    ),
  );

  Widget _item(BuildContext context, GbControlState m) {
    final items = model.menusIn(m.name);
    final enabled = model.designing || m['Enabled'] == true;
    final label = Text(m.text('Caption'));
    if (items.isNotEmpty) {
      return SubmenuButton(
        key: gbMenuKey(m.name!),
        menuChildren: enabled
            ? [
                for (final i in items)
                  if (i['Visible'] == true) _item(context, i),
              ]
            : const [],
        child: label,
      );
    }
    if (gbIsMenuLine(m)) return const Divider(height: 8);
    return MenuItemButton(
      key: gbMenuKey(m.name!),
      onPressed: enabled ? () => gbChooseMenu(model, m) : null,
      leadingIcon: m['Checked'] == true
          ? const Icon(Icons.check, size: 16)
          : null,
      shortcut: gbShortcut(m.text('Shortcut')),
      child: label,
    );
  }
}

/// A form's menu bar for the system's menu bar (D106): on macOS. A
/// Checked item shows ✓ before its Caption, as the system's menus show
/// no check marks of Flutter's; a menu that is not Enabled shows its items
/// grey. The menus' Shortcuts are the Command key's.
List<PlatformMenuItem> gbPlatformMenus(GbFormModel model) => [
  for (final m in model.menusIn(null))
    if (m['Visible'] == true) _platformItem(model, m, enabled: true),
];

PlatformMenuItem _platformItem(
  GbFormModel model,
  GbControlState m, {
  required bool enabled,
}) {
  final on = enabled && m['Enabled'] == true;
  final items = [
    for (final i in model.menusIn(m.name))
      if (i['Visible'] == true) i,
  ];
  final caption = m.text('Caption');
  if (model.menusIn(m.name).isNotEmpty) {
    return PlatformMenu(
      label: caption,
      menus: _grouped(
        [for (final i in items) _platformItem(model, i, enabled: on)],
        [for (final i in items) gbIsMenuLine(i)],
      ),
    );
  }
  return PlatformMenuItem(
    label: m['Checked'] == true ? '✓ $caption' : caption,
    shortcut: gbShortcut(m.text('Shortcut'), apple: true),
    onSelected: on ? () => gbChooseMenu(model, m) : null,
  );
}

/// [items] split into groups at the lines ([lines]): the system's menus
/// draw a line between groups.
List<PlatformMenuItem> _grouped(
  List<PlatformMenuItem> items,
  List<bool> lines,
) {
  if (!lines.contains(true)) return items;
  final groups = <List<PlatformMenuItem>>[[]];
  for (var i = 0; i < items.length; i++) {
    if (lines[i]) {
      groups.add([]);
    } else {
      groups.last.add(items[i]);
    }
  }
  return [
    for (final g in groups)
      if (g.isNotEmpty) PlatformMenuItemGroup(members: g),
  ];
}
