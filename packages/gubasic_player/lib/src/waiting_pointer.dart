import 'package:flutter/material.dart';

import 'run_host.dart';

/// The run window's and the app's form while [host] waits for an HTTP
/// answer (docs/DESIGN.md D124 A).
const waitingPointerKey = ValueKey('run.waiting');

/// Shows the mouse pointer as waiting over [child] while a request of the
/// program's `Http` is under way (D124 A, D125); otherwise the pointer is
/// whatever the control under it asks for.
class WaitingPointer extends StatelessWidget {
  const WaitingPointer({super.key, required this.host, required this.child});

  final RunHost host;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<int>(
    valueListenable: host.busyRequests,
    builder: (context, busy, child) => MouseRegion(
      key: busy > 0 ? waitingPointerKey : null,
      cursor: busy > 0 ? SystemMouseCursors.wait : MouseCursor.defer,
      child: child,
    ),
    child: child,
  );
}
