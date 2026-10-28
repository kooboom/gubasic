import 'package:flutter/material.dart';
import 'package:gubasic_runtime/gubasic_runtime.dart';

import 'player_strings.dart';
import 'run_session.dart';

/// On macOS, the system's menu bar of an app that runs GuBASIC programs,
/// the IDE or an exported app (docs/DESIGN.md D106): the app's own menu,
/// then, while [session]'s program shows a form, the menus of the form in
/// front, then the Window menu. Elsewhere [child] alone: the run window or
/// the app draws the menus in the window ([GbMenuBar]).
///
/// It stays in place for the app's life, its own menus at least: the
/// system's menu bar keeps only what the last menu bar set.
class SystemMenus extends StatefulWidget {
  const SystemMenus({
    super.key,
    required this.appName,
    required this.strings,
    required this.child,
    this.session,
  });

  /// The app's name, the label of its own menu.
  final String appName;
  final PlayerStrings strings;
  final RunSession? session;
  final Widget child;

  @override
  State<SystemMenus> createState() => _SystemMenusState();
}

class _SystemMenusState extends State<SystemMenus> {
  /// What the menus are drawn from now: the session, the form in front's
  /// layout and its menu items. One menu bar stays in place throughout,
  /// as only one may set the system's menus.
  final _watched = <Listenable>[];

  @override
  void initState() {
    super.initState();
    _watch();
  }

  @override
  void didUpdateWidget(SystemMenus old) {
    super.didUpdateWidget(old);
    if (old.session != widget.session) _watch();
  }

  @override
  void dispose() {
    _unwatch();
    super.dispose();
  }

  void _unwatch() {
    for (final l in _watched) {
      l.removeListener(_changed);
    }
    _watched.clear();
  }

  void _watch() {
    _unwatch();
    final s = widget.session;
    if (s == null) return;
    _watched.add(s);
    if (_programRuns(s)) {
      final model = s.host.model;
      _watched.addAll([model.layout, ...model.menuItems]);
    }
    for (final l in _watched) {
      l.addListener(_changed);
    }
  }

  void _changed() => setState(_watch);

  static bool _programRuns(RunSession s) => s.isRunning && s.formShown;

  @override
  Widget build(BuildContext context) {
    if (!gbUsesSystemMenus) return widget.child;
    final s = widget.session;
    return _bar(
      s != null && _programRuns(s) ? gbPlatformMenus(s.host.model) : const [],
    );
  }

  Widget _bar(List<PlatformMenuItem> program) => PlatformMenuBar(
    menus: [
      PlatformMenu(
        label: widget.appName,
        menus: [
          for (final group in const [
            [PlatformProvidedMenuItemType.about],
            [PlatformProvidedMenuItemType.servicesSubmenu],
            [
              PlatformProvidedMenuItemType.hide,
              PlatformProvidedMenuItemType.hideOtherApplications,
              PlatformProvidedMenuItemType.showAllApplications,
            ],
            [PlatformProvidedMenuItemType.quit],
          ])
            PlatformMenuItemGroup(
              members: [
                for (final type in group)
                  if (PlatformProvidedMenuItem.hasMenu(type))
                    PlatformProvidedMenuItem(type: type),
              ],
            ),
        ],
      ),
      ...program,
      PlatformMenu(
        label: widget.strings.windowMenu,
        menus: [
          for (final type in const [
            PlatformProvidedMenuItemType.minimizeWindow,
            PlatformProvidedMenuItemType.zoomWindow,
            PlatformProvidedMenuItemType.toggleFullScreen,
          ])
            if (PlatformProvidedMenuItem.hasMenu(type))
              PlatformProvidedMenuItem(type: type),
        ],
      ),
    ],
    child: widget.child,
  );
}
