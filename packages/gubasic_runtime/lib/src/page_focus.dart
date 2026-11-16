import 'package:flutter/foundation.dart';

import 'page_focus_io.dart' if (dart.library.js_interop) 'page_focus_web.dart';

/// Whether the page has the keyboard (D139): on the web a browser gives a
/// page the keys only once it is clicked, after it was opened from the
/// address bar, say; elsewhere always true. A running form that does not
/// have it says "Click to start" over itself.
final ValueNotifier<bool> gbPageFocus = createPageFocus();
