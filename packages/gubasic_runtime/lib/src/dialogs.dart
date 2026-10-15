import 'dart:async';

import 'package:flutter/material.dart';

/// Words on the runtime's own buttons, in English and Korean.
class GbStrings {
  const GbStrings({required this.ok, required this.cancel});

  final String ok;
  final String cancel;

  static const en = GbStrings(ok: 'OK', cancel: 'Cancel');
  static const ko = GbStrings(ok: '확인', cancel: '취소');
}

/// MsgBox and InputBox. Both are modal (D28): until one is closed, nothing
/// else on the screen can be used. Tapping outside does not close them;
/// Escape counts as Cancel.
class GbDialogs {
  GbDialogs({this.strings = GbStrings.en});

  GbStrings strings;
  final _open = <(Route<void>, Completer<String?>)>[];

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

  /// Closes every open dialog as if it was cancelled (the program ended).
  void closeAll() {
    for (final (route, answer) in _open.reversed.toList()) {
      if (route.isActive) route.navigator?.removeRoute(route);
      if (!answer.isCompleted) answer.complete(null);
    }
    _open.clear();
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
    Navigator.of(context).push(route);
    return answer.future;
  }
}
