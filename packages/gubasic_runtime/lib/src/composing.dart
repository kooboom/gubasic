import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Whether this platform's input method may send Hangul without saying
/// which part is still being composed: the macOS desktop app. With macOS
/// 27's Korean input method and Flutter 3.47.7, every jamo arrives there
/// as committed text, the syllable before the caret replaced in place
/// (test/ime_logs/macos-app.json), while Chrome on the same Mac gets the
/// composing range (D37).
bool get mayLeaveOutComposing =>
    !kIsWeb && defaultTargetPlatform == TargetPlatform.macOS;

/// Follows a text field's values and tells which part is still being
/// composed: as the platform says, or, where it says nothing
/// ([mayLeaveOutComposing]), guessed from how the text changed. A Hangul
/// letter typed or changed just before the caret is taken as being
/// composed until the input method moves on: a new syllable starts, a key
/// that is not Hangul is typed, the caret moves, or [commit] is called
/// (Enter, a click, the field losing the focus). This is what the input
/// method does where the composing range is sent (LANGUAGE.md §11.1).
class ComposingTracker {
  ComposingTracker([this._last = TextEditingValue.empty]);

  TextEditingValue _last;
  TextRange _guess = TextRange.empty;

  /// Once the platform has sent a composing range, it is trusted.
  var _platformComposes = false;

  /// The last value, with the part being composed.
  TextEditingValue get value => _guess.isValid && !_guess.isCollapsed
      ? _last.copyWith(composing: _guess)
      : _last;

  /// Whether a part of [value] is being composed.
  bool get composing => value.composing.isValid && !value.composing.isCollapsed;

  /// Takes in the field's new value [raw]; gives it with the part being
  /// composed.
  TextEditingValue track(TextEditingValue raw) {
    final before = _last;
    final guessed = _guess;
    _last = raw;
    _guess = TextRange.empty;
    if (raw.composing.isValid && !raw.composing.isCollapsed) {
      _platformComposes = true;
      return raw;
    }
    if (_platformComposes || !mayLeaveOutComposing) return raw;
    _guess = _guessed(before, guessed, raw);
    return value;
  }

  /// Takes what is being composed as committed.
  void commit() => _guess = TextRange.empty;

  static TextRange _guessed(
    TextEditingValue before,
    TextRange guessed,
    TextEditingValue now,
  ) {
    final s = now.selection;
    // A field that never had the focus has no selection: the caret is
    // taken to be at its end.
    final b = before.selection.isValid
        ? before.selection
        : TextSelection.collapsed(offset: before.text.length);
    if (!s.isValid || !s.isCollapsed || !b.isCollapsed) {
      return TextRange.empty;
    }
    final c = s.baseOffset;
    final text = now.text;
    if (c < 1 || c > text.length || !_isHangul(text.codeUnitAt(c - 1))) {
      return TextRange.empty;
    }
    final at = TextRange(start: c - 1, end: c);
    // The syllable being composed changes in place: ㄱ, 가, 갈.
    if (guessed == at &&
        b.baseOffset == c &&
        text.length == before.text.length &&
        text.replaceRange(c - 1, c, '') ==
            before.text.replaceRange(c - 1, c, '')) {
      return at;
    }
    // A new syllable starts after the caret: 갈, then 갈가.
    if (b.baseOffset == c - 1 &&
        text.length == before.text.length + 1 &&
        text.replaceRange(c - 1, c, '') == before.text) {
      return at;
    }
    return TextRange.empty;
  }

  /// A Hangul syllable or jamo, as a 2-set input method composes them.
  static bool _isHangul(int unit) =>
      (unit >= 0xAC00 && unit <= 0xD7A3) ||
      (unit >= 0x3131 && unit <= 0x318E) ||
      (unit >= 0x1100 && unit <= 0x11FF);
}
