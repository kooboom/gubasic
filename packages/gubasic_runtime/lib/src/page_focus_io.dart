import 'package:flutter/foundation.dart';

/// Off the web, the window's own focus is the form's (D138).
ValueNotifier<bool> createPageFocus() => ValueNotifier(true);

/// Off the web nothing waits for the user to sound.
bool pageWasActivated() => true;
