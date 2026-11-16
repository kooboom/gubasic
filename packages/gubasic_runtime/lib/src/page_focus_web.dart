import 'dart:js_interop';

import 'package:flutter/foundation.dart';
import 'package:web/web.dart' as web;

/// The document's focus, kept up to date by the window's focus and blur.
ValueNotifier<bool> createPageFocus() {
  final focus = ValueNotifier(web.document.hasFocus());
  void update(web.Event _) => focus.value = web.document.hasFocus();
  web.window.addEventListener('focus', update.toJS);
  web.window.addEventListener('blur', update.toJS);
  return focus;
}
