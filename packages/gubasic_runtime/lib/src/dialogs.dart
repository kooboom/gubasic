import 'dart:async';

import 'package:flutter/material.dart';

import 'form_model.dart';
import 'menus.dart';

/// Words on the runtime's own buttons, in English and Korean.
class GbStrings {
  const GbStrings({required this.ok, required this.cancel});

  final String ok;
  final String cancel;

  static const en = GbStrings(ok: 'OK', cancel: 'Cancel');
  static const ko = GbStrings(ok: '확인', cancel: '취소');
}

/// MsgBox, InputBox and the menus `PopupMenu` shows. All are modal (D28):
/// until one is closed, nothing else on the screen can be used. Tapping
/// outside a MsgBox or an InputBox does not close it; Escape counts as
/// Cancel. A popup menu closes when one of its items is chosen, or with
/// nothing chosen by a tap outside it or Escape.
class GbDialogs {
  GbDialogs({this.strings = GbStrings.en});

  GbStrings strings;
  final _open = <(Route<void>, Completer<String?>)>[];
  final _closers = <void Function(String?)>[];

  bool get hasOpenDialog => _open.isNotEmpty;

  /// Shows [prompt] with an OK button; completes when it is closed.
  Future<void> msgBox(BuildContext context, String prompt, String title) =>
      _show(
        context,
        (close) => AlertDialog(
          title: title.isEmpty ? null : Text(title),
          content: Text(prompt),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => close(''),
              child: Text(strings.ok),
            ),
          ],
        ),
      );

  /// Asks for a line of text; gives "" when cancelled.
  Future<String> inputBox(
    BuildContext context,
    String prompt,
    String title,
    String defaultValue,
  ) async {
    final field = TextEditingController(text: defaultValue)
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: defaultValue.length,
      );
    try {
      final answer = await _show(
        context,
        (close) => AlertDialog(
          title: title.isEmpty ? null : Text(title),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(prompt),
              const SizedBox(height: 12),
              TextField(
                controller: field,
                autofocus: true,
                onSubmitted: (_) => close(field.text),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => close(null),
              child: Text(strings.cancel),
            ),
            FilledButton(
              onPressed: () => close(field.text),
              child: Text(strings.ok),
            ),
          ],
        ),
      );
      return answer ?? '';
    } finally {
      field.dispose();
    }
  }

  /// Shows the items of [menu], a menu of [model], at [at] on the screen
  /// (`PopupMenu`, docs/DESIGN.md D106); completes with the name of the item
  /// chosen, or null when it is closed with none. An item with items opens
  /// them beside it; a line, an item that is not Enabled or not Visible,
  /// cannot be chosen.
  Future<String?> popupMenu(
    BuildContext context,
    GbFormModel model,
    String menu,
    Offset at,
  ) {
    // [at] in the navigator's own area, which the run window's is inside.
    final area = Navigator.of(context).overlay?.context.findRenderObject();
    final local = area is RenderBox ? area.globalToLocal(at) : at;
    final answer = Completer<String?>();
    late final Route<void> route;
    void close(String? value) {
      if (answer.isCompleted) return;
      answer.complete(value);
      _open.removeWhere((e) => e.$1 == route);
      _closers.remove(close);
      if (route.isActive) route.navigator?.removeRoute(route);
    }

    route = _PopupMenuRoute(
      builder: (_) => Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              close(null);
              return null;
            },
          ),
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) close(null);
          },
          // The focus, so that Escape reaches the Actions above.
          child: Focus(
            autofocus: true,
            child: _PopupMenu(
              model: model,
              menu: menu,
              at: local,
              close: close,
            ),
          ),
        ),
      ),
      dismiss: () => close(null),
    );
    _open.add((route, answer));
    _closers.add(close);
    Navigator.of(context).push(route);
    return answer.future;
  }

  /// Closes the topmost dialog as its OK button would, with [value] as an
  /// InputBox's text, or as Cancel when [value] is null; false when none is
  /// open. For tools that drive a program without a mouse, such as the
  /// player's measurements (STAGE2_PLAN §7).
  bool answerTop(String? value) {
    if (_open.isEmpty) return false;
    _closers.last(value);
    return true;
  }

  /// Closes every open dialog as if it was cancelled (the program ended).
  void closeAll() {
    for (final (route, answer) in _open.reversed.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
      if (!answer.isCompleted) answer.complete(null);
    }
    _open.clear();
    _closers.clear();
  }

  Future<String?> _show(
    BuildContext context,
    Widget Function(void Function(String?)) build,
  ) {
    final answer = Completer<String?>();
    late final Route<void> route;
    void close(String? value) {
      if (answer.isCompleted) return;
      answer.complete(value);
      _open.removeWhere((e) => e.$1 == route);
      _closers.remove(close);
      if (route.isActive) route.navigator?.removeRoute(route);
    }

    route = DialogRoute<void>(
      context: context,
      barrierDismissible: false,
      // Escape (DismissIntent) and Back count as Cancel. A dialog that the
      // barrier cannot dismiss gets no Escape handling from Flutter, so it
      // is handled here.
      builder: (_) => Actions(
        actions: {
          DismissIntent: CallbackAction<DismissIntent>(
            onInvoke: (_) {
              close(null);
              return null;
            },
          ),
        },
        child: PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) close(null);
          },
          child: build(close),
        ),
      ),
    );
    _open.add((route, answer));
    _closers.add(close);
    Navigator.of(context).push(route);
    return answer.future;
  }
}

/// The key of item [name] in a menu `PopupMenu` shows (D106).
ValueKey<String> gbPopupKey(String name) =>
    ValueKey('gb.popup.${name.toLowerCase()}');

/// A popup menu's route: over everything, with a clear barrier that closes
/// it when tapped.
class _PopupMenuRoute extends PopupRoute<void> {
  _PopupMenuRoute({required this.builder, required this.dismiss});

  final WidgetBuilder builder;
  final VoidCallback dismiss;

  @override
  Color? get barrierColor => null;

  // The barrier's tap goes to [dismiss], which removes the route itself.
  @override
  bool get barrierDismissible => false;

  @override
  String? get barrierLabel => null;

  @override
  Duration get transitionDuration => Duration.zero;

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) => Stack(
    children: [
      Positioned.fill(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: dismiss,
        ),
      ),
      // A Stack of its own that takes no taps outside the menu.
      Positioned.fill(child: builder(context)),
    ],
  );
}

/// The open panels of a popup menu: [menu]'s items at [at], and beside
/// them the items of each item opened in turn.
class _PopupMenu extends StatefulWidget {
  const _PopupMenu({
    required this.model,
    required this.menu,
    required this.at,
    required this.close,
  });

  final GbFormModel model;
  final String menu;
  final Offset at;
  final void Function(String?) close;

  @override
  State<_PopupMenu> createState() => _PopupMenuState();
}

class _PopupMenuState extends State<_PopupMenu> {
  /// The menus open, from [_PopupMenu.menu] outwards.
  late final List<String> _open = [widget.menu];

  static const _width = 200.0;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, area) => _menus(area.biggest));
  }

  /// The panels at [_PopupMenu.at], moved left as far as it takes to keep
  /// the first inside [area].
  Widget _menus(Size area) {
    final left = widget.at.dx
        .clamp(0.0, (area.width - _width).clamp(0.0, double.infinity))
        .toDouble();
    return Stack(
      children: [
        Positioned(
          left: left,
          top: widget.at.dy,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (final (level, menu) in _open.indexed) _panel(level, menu),
            ],
          ),
        ),
      ],
    );
  }

  Widget _panel(int level, String menu) {
    final model = widget.model;
    return Material(
      elevation: 8,
      borderRadius: BorderRadius.circular(4),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minWidth: _width, maxWidth: _width),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (final item in model.menusIn(menu))
                if (item['Visible'] == true)
                  if (gbIsMenuLine(item))
                    const Divider(height: 8)
                  else
                    _item(level, item),
            ],
          ),
        ),
      ),
    );
  }

  Widget _item(int level, GbControlState item) {
    final model = widget.model;
    final opens = model.menusIn(item.name).isNotEmpty;
    final enabled = item['Enabled'] == true;
    final shortcut = item.text('Shortcut');
    return InkWell(
      key: gbPopupKey(item.name!),
      onTap: !enabled
          ? null
          : opens
          ? () => setState(() {
              _open
                ..length = level + 1
                ..add(item.name!);
            })
          : () => widget.close(item.name),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Row(
            children: [
              SizedBox(
                width: 20,
                child: item['Checked'] == true
                    ? const Icon(Icons.check, size: 16)
                    : null,
              ),
              Expanded(child: Text(item.text('Caption'))),
              if (shortcut.isNotEmpty) Text(shortcut),
              if (opens) const Icon(Icons.chevron_right, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}
