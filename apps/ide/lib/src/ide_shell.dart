import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'project/project.dart';
import 'project/project_controller.dart';
import 'run/run_session.dart';
import 'run/run_window.dart';
import 'strings.dart';
import 'theme.dart';

/// The IDE's main window: the project's files on the left, the selected
/// file or the running program in the middle, the output below. F5 runs
/// the project, Shift+F5 stops it.
///
/// While a program runs, the file list starts with its run window. The
/// user can look at a file and come back: the run window, with any open
/// MsgBox or InputBox, stays as it was. The files cannot be changed while
/// the program runs.
///
/// The File menu opens and saves projects on disk (D32); the menu at the
/// top right switches between the examples and the project on disk. Both
/// wait while a program runs.
class IdeShell extends StatefulWidget {
  const IdeShell({super.key, required this.controller, required this.strings});

  /// The open project, [ProjectController.current], and the commands
  /// that open and save projects.
  final ProjectController controller;
  final IdeStrings strings;

  @override
  State<IdeShell> createState() => _IdeShellState();
}

class _IdeShellState extends State<IdeShell> {
  Project get _project => widget.controller.current.project;

  late String _chosenFile = _firstFile;

  String get _firstFile => _project.files.keys.firstWhere(
    (f) => f.endsWith('.gbas'),
    orElse: () => _project.files.keys.first,
  );

  /// The file shown; the first code file when the chosen one is gone
  /// (Save As renames the .gbproj file).
  String get _file =>
      _project.files.containsKey(_chosenFile) ? _chosenFile : _firstFile;
  set _file(String file) => _chosenFile = file;
  RunSession? _session;

  /// Whether the middle shows the run window rather than [_file].
  var _showRun = false;

  /// Shown instead of a run when the project cannot start.
  var _problems = <String>[];

  bool get _running => _session?.isRunning ?? false;

  void _run() {
    if (_running) return;
    final project = _project;
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
    final folders = widget.controller.canUseFolders && !_running;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.f5): _run,
        const SingleActivator(LogicalKeyboardKey.f5, shift: true): _stop,
        if (folders) ...{
          _shortcut(LogicalKeyboardKey.keyO): _open,
          _shortcut(LogicalKeyboardKey.keyS): _save,
          _shortcut(LogicalKeyboardKey.keyS, shift: true): _saveAs,
        },
      },
      child: Focus(
        autofocus: true,
        child: ListenableBuilder(
          listenable: Listenable.merge([
            session ?? const _Never(),
            widget.controller,
            widget.controller.current,
          ]),
          builder: (context, _) => Scaffold(
            appBar: AppBar(
              // The File menu at the top left, where Visual Basic and most
              // desktop programs have it.
              leading: widget.controller.canUseFolders
                  ? _fileMenu(context)
                  : null,
              leadingWidth: 96,
              automaticallyImplyLeading: false,
              title: Text(
                widget.controller.current.isDirty
                    ? '${_project.name} — ${widget.strings.edited}'
                    : _project.name,
              ),
              actions: [
                if (widget.controller.menuEntries.length > 1)
                  DropdownButton<String>(
                    value: widget.controller.currentKey,
                    underline: const SizedBox(),
                    onChanged: _running
                        ? null
                        : (key) => widget.controller.choose(context, key!),
                    items: [
                      for (final (key, label) in widget.controller.menuEntries)
                        DropdownMenuItem(value: key, child: Text(label)),
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

  void _open() => widget.controller.open(context);
  void _save() => widget.controller.save(context);
  void _saveAs() => widget.controller.saveAs(context);

  Widget _fileMenu(BuildContext context) {
    final s = widget.strings;
    MenuItemButton item(
      String label,
      VoidCallback action,
      LogicalKeyboardKey key, {
      bool shift = false,
    }) => MenuItemButton(
      onPressed: _running ? null : action,
      shortcut: _shortcut(key, shift: shift),
      child: Text(label),
    );
    return MenuAnchor(
      menuChildren: [
        item(s.open, _open, LogicalKeyboardKey.keyO),
        item(s.save, _save, LogicalKeyboardKey.keyS),
        item(s.saveAs, _saveAs, LogicalKeyboardKey.keyS, shift: true),
      ],
      builder: (context, menu, _) => Padding(
        padding: const EdgeInsets.only(left: 8),
        child: TextButton(
          onPressed: () => menu.isOpen ? menu.close() : menu.open(),
          child: Text(s.fileMenu),
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
      for (final f in _project.files.keys)
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
      child: SelectableText(_project.files[_file]!, style: codeStyle),
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
              for (final l in lines) SelectableText(l, style: codeStyle),
            ],
          ),
        ),
      ],
    );
  }
}

/// ⌘ and [key] on Apple systems, Ctrl and [key] elsewhere.
SingleActivator _shortcut(LogicalKeyboardKey key, {bool shift = false}) {
  final apple = switch (defaultTargetPlatform) {
    TargetPlatform.macOS || TargetPlatform.iOS => true,
    _ => false,
  };
  return SingleActivator(key, meta: apple, control: !apple, shift: shift);
}

/// A listenable that never changes, for when nothing runs.
class _Never implements Listenable {
  const _Never();

  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}
}
