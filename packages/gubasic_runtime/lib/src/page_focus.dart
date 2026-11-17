import 'package:flutter/foundation.dart';

import 'page_focus_io.dart' if (dart.library.js_interop) 'page_focus_web.dart';

/// Whether the page has the keyboard (D139): on the web a browser gives a
/// page the keys only once it is clicked, after it was opened from the
/// address bar, say; elsewhere always true. A running form that does not
/// have it says "Click to start" over itself.
final ValueNotifier<bool> gbPageFocus = createPageFocus();

/// Whether the page has had the user's click or key since it was opened
/// (the browser's sticky user activation, D138): then a sound engine may
/// start without waiting for the next one. Always true off the web. A
/// test may put another function here.
bool Function() gbPageWasActivated = pageWasActivated;
