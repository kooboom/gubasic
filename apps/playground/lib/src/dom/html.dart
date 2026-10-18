import 'dart:js_interop';

import 'package:web/web.dart' as web;

/// Creates an element with an optional class and text.
web.HTMLElement el(String tag, {String? className, String? text}) {
  final e = web.document.createElement(tag) as web.HTMLElement;
  if (className != null) e.className = className;
  if (text != null) e.textContent = text;
  return e;
}

void onClick(web.EventTarget target, void Function() handler) =>
    target.addEventListener('click', ((web.Event _) => handler()).toJS);

T byId<T extends web.Element>(String id) =>
    web.document.getElementById(id)! as T;

/// localStorage that never throws (private windows, blocked storage).
String? loadSetting(String key) {
  try {
    return web.window.localStorage.getItem(key);
  } catch (_) {
    return null;
  }
}

/// localStorage for what a program keeps (SaveSetting): a failure, such
/// as a full storage, is the program's to report.
void saveOrThrow(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (e) {
    throw Exception('$e');
  }
}

void saveSetting(String key, String value) {
  try {
    web.window.localStorage.setItem(key, value);
  } catch (_) {
    // Storage is a convenience only.
  }
}
