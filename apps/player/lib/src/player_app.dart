import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:gubasic_lang/gubasic_lang.dart';
import 'package:gubasic_player/gubasic_player.dart';

/// The font the IDE uses, so that an app lays its text out as the IDE
/// showed it (D30, KNOWN_ISSUES).
const playerFontFamily = 'Pretendard';

/// Whether this is a measuring build (`--dart-define=GUBASIC_BENCH=true`).
const _measuring = bool.fromEnvironment('GUBASIC_BENCH');

/// One GuBASIC project as an app of its own (D79): its startup form in the
/// run window, filling the window, run by the same interpreter as F5.
class PlayerApp extends StatelessWidget {
  const PlayerApp({
    super.key,
    required this.files,
    this.pictures = const {},
    required this.strings,
  });

  /// The project's files, file name → text.
  final Map<String, String> files;

  /// Its pictures, name → bytes.
  final Map<String, Uint8List> pictures;
  final PlayerStrings strings;

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: Project.read(files).name,
    debugShowCheckedModeBanner: false,
    theme: ThemeData(
      fontFamily: playerFontFamily,
      visualDensity: VisualDensity.compact,
    ),
    home: PlayerScreen(files: files, pictures: pictures, strings: strings),
  );
}

/// The run window with the project's program, or why it cannot start.
class PlayerScreen extends StatefulWidget {
  const PlayerScreen({
    super.key,
    required this.files,
    required this.pictures,
    required this.strings,
  });

  final Map<String, String> files;
  final Map<String, Uint8List> pictures;
  final PlayerStrings strings;

  @override
  State<PlayerScreen> createState() => _PlayerScreenState();
}

class _PlayerScreenState extends State<PlayerScreen> {
  late final Project _project = Project.read(widget.files);
  RunSession? _session;
  final _fit = ValueNotifier(true);
  var _ended = false;

  @override
  void initState() {
    super.initState();
    if (_project.canRun) {
      _session = RunSession(
        _project.startup!,
        strings: widget.strings,
        project: _project.name,
        pictures: pictureSource(widget.pictures),
      )..addListener(_changed);
    }
  }

  @override
  void dispose() {
    _session?.dispose();
    _fit.dispose();
    super.dispose();
  }

  /// The program ended: as with F5 (D81), an error is shown first; then
  /// the app closes, or on the web says the program has ended.
  Future<void> _changed() async {
    final session = _session!;
    final result = session.result;
    if (result == null || _ended) return;
    _ended = true;
    if (result case RunFailed(:final error)) {
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: Text(_project.name),
          content: Text(
            widget.strings.problem(session.startup.codeFile, error),
          ),
          actions: [
            FilledButton(
              autofocus: true,
              onPressed: () => Navigator.pop(context),
              child: Text(widget.strings.runtime.ok),
            ),
          ],
        ),
      );
    }
    // A measuring build stays open, so that its probe can still report
    // (STAGE2_PLAN §7).
    if (kIsWeb || _measuring) {
      if (mounted) setState(() {});
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = _session;
    if (session == null) {
      return Scaffold(
        body: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(widget.strings.cannotStart),
            const SizedBox(height: 8),
            for (final d in _project.diagnostics)
              if (d.diagnostic.isError)
                Text(widget.strings.problem(d.file, d.diagnostic)),
          ],
        ),
      );
    }
    if (_ended && (kIsWeb || _measuring)) {
      return Scaffold(body: Center(child: Text(widget.strings.programEnded)));
    }
    return Scaffold(
      body: RunWindow(session: session, fit: _fit),
    );
  }
}

/// The words for the device's language: Korean, or else English.
PlayerStrings playerStringsFor(String languageCode) =>
    languageCode == 'ko' ? PlayerStrings.ko : PlayerStrings.en;
