import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'project/project.dart';
import 'run/run_session.dart';
import 'run/run_window.dart';
import 'strings.dart';

/// The IDE's main window: the project's files on the left, the selected
/// file or the running program in the middle, the output below. F5 runs
/// the project, Shift+F5 stops it.
///
/// While a program runs, the file list starts with its run window. The
/// user can look at a file and come back: the run window, with any open
/// MsgBox or InputBox, stays as it was. The files cannot be changed while
/// the program runs.
class IdeShell extends StatefulWidget {
  const IdeShell({
    super.key,
    required this.project,
    required this.strings,
    this.projects = const [],
    this.openProject,
    this.onOpenProject,
  });

  final Project project;
  final IdeStrings strings;

  /// The projects the menu offers, the one that is open, and what to do
  /// when another one is chosen.
  final List<String> projects;
  final String? openProject;
  final ValueChanged<String>? onOpenProject;

  @override
  State<IdeShell> createState() => _IdeShellState();
}

class _IdeShellState extends State<IdeShell> {
  late String _file = widget.project.files.keys.firstWhere(
    (f) => f.endsWith('.gbas'),
    orElse: () => widget.project.files.keys.first,
  );
  RunSession? _session;

  /// Whether the middle shows the run window rather than [_file].
  var _showRun = false;

  /// Shown instead of a run when the project cannot start.
  var _problems = <String>[];

  bool get _running => _session?.isRunning ?? false;

  void _run() {
    if (_running) return;
    final project = widget.project;
    final s = widget.strings;
    _session?.dispose();
    _session = null;
    final startup = project.startup;
    if (!project.canRun || startup == null) {
      setState(
        () => _problems = [
          s.cannotStart,
          for (final d in project.diagnostics)
            if (d.diagnostic.isError) s.problem(d.file, d.diagnostic),
        ],
      );
      return;
    }
    setState(() {
      _problems = [];
      _session = RunSession(startup, strings: s);
      _showRun = true;
    });
  }

  void _stop() => _session?.stop();

  @override
  void dispose() {
    _session?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = widget.strings;
    final session = _session;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _run,
        const SingleActivator(LogicalKeyboardKey.f5, shift: true): _stop,
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: session ?? const _Never(),
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              title: Text(widget.project.name),
              actions: [
                if (widget.projects.length > 1)
                  DropdownButton<String>(
                    value: widget.openProject,
                    underline: const SizedBox(),
                    onChanged: _running
                        ? null
                        : (name) => widget.onOpenProject?.call(name!),
                    items: [
                      for (final p in widget.projects)
                        DropdownMenuItem(value: p, child: Text(p)),
                    ],
                  ),
                const SizedBox(width: 8),
                TextButton.icon(
                  onPressed: _running ? null : _run,
                  icon: const Icon(Icons.play_arrow),
                  label: Text('${s.run} (F5)'),
                ),
                TextButton.icon(
                  onPressed: _running ? _stop : null,
                  icon: const Icon(Icons.stop),
                  label: Text('${s.stop} (Shift+F5)'),
                ),
                const SizedBox(width: 8),
              ],
            ),
            body: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(width: 200, child: _fileList(context)),
                const VerticalDivider(width: 1),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _main(context)),
                      const Divider(height: 1),
                      SizedBox(height: 160, child: _output(context)),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _fileList(BuildContext context) => ListView(
    children: [
      if (_running)
        ListTile(
          dense: true,
          leading: const Icon(Icons.play_arrow),
          title: Text(widget.strings.runWindow),
          selected: _showRun,
          onTap: () => setState(() => _showRun = true),
        ),
      ListTile(dense: true, title: Text(widget.strings.files)),
      for (final f in widget.project.files.keys)
        ListTile(
          dense: true,
          title: Text(f),
          selected: f == _file && !(_running && _showRun),
          onTap: () => setState(() {
            _file = f;
            _showRun = false;
          }),
        ),
    ],
  );

  Widget _main(BuildContext context) {
    final session = _session;
    final code = SingleChildScrollView(
      padding: const EdgeInsets.all(12),
      child: SelectableText(
        widget.project.files[_file]!,
        style: const TextStyle(fontFamily: 'monospace'),
      ),
    );
    if (session == null || session.result != null) {
      return code;
    }
    // The run window stays built while a file is shown, so that its
    // dialogs are still there, unanswered, when the user comes back.
    return IndexedStack(
      index: _showRun ? 1 : 0,
      sizing: StackFit.expand,
      children: [
        code,
        ColoredBox(
          color: Theme.of(context).colorScheme.scrim.withValues(alpha: 0.2),
          child: RunWindow(key: ObjectKey(session), session: session),
        ),
      ],
    );
  }

  Widget _output(BuildContext context) {
    final session = _session;
    final lines = [..._problems, ...?session?.output, ?session?.endMessage];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
          child: Text(
            widget.strings.output,
            style: Theme.of(context).textTheme.labelMedium,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            children: [
              for (final l in lines)
                SelectableText(
                  l,
                  style: const TextStyle(fontFamily: 'monospace'),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A listenable that never changes, for when nothing runs.
class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
