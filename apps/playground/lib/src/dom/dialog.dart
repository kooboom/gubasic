import 'dart:async';
import 'dart:js_interop';

import 'package:web/web.dart' as web;

import '../model/i18n.dart';
import 'html.dart';

/// An open dialog: [answer] completes with the text typed (InputBox), ""
/// for OK (MsgBox), or null for Cancel; [cancel] closes it from outside
/// (the Stop button).
class DialogHandle {
  DialogHandle(this.answer, this.cancel);
  final Future<String?> answer;
  final void Function() cancel;
}

/// A dialog inside the page for MsgBox and InputBox (never the browser's
/// alert or prompt, which would block the page).
DialogHandle showDialog({
  required Locale locale,
  required String title,
  required String message,
  bool withInput = false,
  String defaultValue = '',
}) {
  final done = Completer<String?>();
  final backdrop = el('div', className: 'dialog-backdrop');
  final box = el('div', className: 'dialog')
    ..setAttribute('role', 'dialog')
    ..setAttribute('aria-modal', 'true');
  final heading = el('div', className: 'dialog-title', text: title);
  final text = el('p', className: 'dialog-message', text: message);
  final input = web.document.createElement('input') as web.HTMLInputElement
    ..type = 'text'
    ..value = defaultValue
    ..className = 'dialog-input';
  final ok = el('button', className: 'primary', text: locale[UiText.dialogOk])
    ..setAttribute('type', 'button');
  final cancel = el('button', text: locale[UiText.dialogCancel])
    ..setAttribute('type', 'button');

  void close(String? result) {
    if (done.isCompleted) return;
    backdrop.remove();
    done.complete(result);
  }

  onClick(ok, () => close(withInput ? input.value : ''));
  onClick(cancel, () => close(null));
  box.addEventListener(
      'keydown',
      ((web.KeyboardEvent e) {
        if (e.key == 'Enter') {
          e.preventDefault();
          close(withInput ? input.value : '');
        } else if (e.key == 'Escape') {
          e.preventDefault();
          close(withInput ? null : '');
        }
      }).toJS);

  final buttons = el('div', className: 'dialog-buttons')..append(ok);
  if (withInput) buttons.append(cancel);
  if (title.isNotEmpty) box.append(heading);
  box.append(text);
  if (withInput) box.append(input);
  box.append(buttons);
  backdrop.append(box);
  web.document.body!.append(backdrop);
  if (withInput) {
    input
      ..focus()
      ..select();
  } else {
    ok.focus();
  }
  return DialogHandle(done.future, () => close(null));
}
