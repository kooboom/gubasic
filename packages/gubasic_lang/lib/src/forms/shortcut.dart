/// A menu item's `Shortcut` (docs/DESIGN.md D106): the keys that choose it
/// without opening the menu, as words: `Ctrl+O`, `Ctrl+Shift+S`, `F5`.
///
/// The runtime reads the same words (gubasic_runtime's `gbShortcut`); on
/// macOS, Ctrl is the Command key.
library;

const _modifiers = ['ctrl', 'shift', 'alt'];
const _modifierNames = ['Ctrl', 'Shift', 'Alt'];

/// [text] as `Shortcut` keeps it: Ctrl, Shift and Alt, each at most once
/// and in that order, then one key, joined by `+`; "" for none. The key
/// is a letter A to Z or a digit 0 to 9, which needs Ctrl or Alt so that
/// typing it still types it; F1 to F12; or Delete or Insert. Words may be
/// in any case, with spaces around the `+`. Null when [text] is not a
/// shortcut.
String? normalShortcut(String text) {
  final words = [for (final w in text.split('+')) w.trim()];
  if (words.length == 1 && words.single.isEmpty) return '';
  if (words.any((w) => w.isEmpty)) return null;
  final named = <int>{};
  for (final w in words.take(words.length - 1)) {
    final i = _modifiers.indexOf(w.toLowerCase());
    if (i < 0 || !named.add(i)) return null;
  }
  final key = _key(words.last);
  if (key == null) return null;
  final typed = key.length == 1;
  if (typed && !named.contains(0) && !named.contains(2)) return null;
  return [
    for (var i = 0; i < _modifiers.length; i++)
      if (named.contains(i)) _modifierNames[i],
    key,
  ].join('+');
}

/// [word] as a shortcut's key is written, or null.
String? _key(String word) {
  final upper = word.toUpperCase();
  if (RegExp(r'^[A-Z0-9]$').hasMatch(upper)) return upper;
  final f = RegExp(r'^F([1-9]|1[0-2])$').firstMatch(upper);
  if (f != null) return 'F${f.group(1)}';
  return switch (upper) {
    'DELETE' || 'DEL' => 'Delete',
    'INSERT' || 'INS' => 'Insert',
    _ => null,
  };
}
