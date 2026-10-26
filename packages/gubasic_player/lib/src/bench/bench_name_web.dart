/// The benchmark to run: the page address's `?bench=` part.
String? benchName() => Uri.base.queryParameters['bench'];
